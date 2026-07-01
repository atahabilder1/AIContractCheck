"""
Steered decoder: generate with the probe in the loop, backtrack on risk spikes.

Algorithm (statement-boundary granularity, NOT per token — keeps it cheap):
  1. Prefill the prompt, then decode token by token with a KV cache.
  2. Every `check_every` tokens, at a safe boundary (just emitted ';' or '}'),
     run the probe on the current layer-L hidden state -> risk in [0,1].
  3. If risk > threshold, backtrack to the last safe checkpoint and re-decode
     that span with a steering nudge (inject a CEI/validation reminder). Cap
     total backtracks.
  4. Stop at max_new_tokens or EOS.

KV cache: a causal model's past keys/values never change, so we cache them and
feed only the new token each step (O(n) not O(n^2)). On backtrack we crop the
cache to the checkpoint length so it stays in lockstep with the text — the one
subtle seam. `selftest()` checks cache-on == cache-off (greedy) to guard it.

Needs torch + transformers + a trained probe.pt (see securegen/probe/).
"""

from __future__ import annotations

from pathlib import Path


class SteeredDecoder:
    def __init__(self, model_id: str = "Qwen/Qwen2.5-Coder-7B-Instruct",
                 probe_path: str = "securegen/probe/probe_l12.pt",
                 risk_threshold: float = 0.6, check_every: int = 16,
                 max_backtracks: int = 8, max_new_tokens: int = 1500,
                 temperature: float = 0.7, layer: int | None = None):
        import torch
        import torch.nn as nn
        from transformers import AutoModelForCausalLM, AutoTokenizer

        self.torch = torch
        self.tok = AutoTokenizer.from_pretrained(model_id)
        self.model = AutoModelForCausalLM.from_pretrained(
            model_id, torch_dtype=torch.float16, device_map="auto",
            output_hidden_states=True)
        self.model.eval()

        if not Path(probe_path).exists():
            raise FileNotFoundError(
                f"Probe not found at {probe_path}. Train it first:\n"
                f"  python -m securegen.probe.extract_activations --layer 12 "
                f"--out securegen/probe/activations_l12.pt\n"
                f"  python -m securegen.probe.train_probe "
                f"--in securegen/probe/activations_l12.pt --arch linear "
                f"--out securegen/probe/probe_l12.pt")
        ckpt = torch.load(probe_path, map_location=self.model.device)
        hidden = ckpt["hidden"]
        if ckpt["arch"] == "linear":
            probe = nn.Sequential(nn.Linear(hidden, 1))
        else:
            probe = nn.Sequential(
                nn.Linear(hidden, 256), nn.ReLU(), nn.Dropout(0.1),
                nn.Linear(256, 1))
        probe.load_state_dict(ckpt["state_dict"])
        probe.to(self.model.device).eval()
        self.probe = probe
        self.layer = layer if layer is not None else (ckpt.get("layer") or 12)

        self.risk_threshold = risk_threshold
        self.check_every = check_every
        self.max_backtracks = max_backtracks
        self.max_new_tokens = max_new_tokens
        self.temperature = temperature

    def _risk(self, hidden_state) -> float:
        torch = self.torch
        with torch.no_grad():
            logit = self.probe(hidden_state.float().unsqueeze(0)).squeeze()
            return float(torch.sigmoid(logit))

    STEER_HINT = (
        "\n// SECURITY: apply checks-effects-interactions, validate inputs, "
        "check external call return values.\n")

    def _build_inputs(self, prompt: str):
        sys = ("You are a Solidity smart contract developer. Generate only "
               "Solidity code. Include SPDX and pragma.")
        msgs = [{"role": "system", "content": sys},
                {"role": "user", "content": prompt}]
        enc = self.tok.apply_chat_template(
            msgs, add_generation_prompt=True, return_tensors="pt",
            return_dict=True)
        return enc["input_ids"].to(self.model.device)

    def generate(self, prompt: str) -> tuple[str, dict]:
        torch = self.torch
        from transformers import DynamicCache

        input_ids = self._build_inputs(prompt)
        prompt_len = input_ids.shape[1]
        generated = input_ids

        # --- prefill ---
        past = DynamicCache()
        with torch.no_grad():
            out = self.model(input_ids, past_key_values=past, use_cache=True)
        past = out.past_key_values
        next_logits = out.logits[0, -1]

        n_new = 0
        backtracks = 0
        risk_triggers = 0
        max_risk = 0.0
        checkpoint = generated.shape[1]  # abs token index of last safe boundary

        while n_new < self.max_new_tokens:
            probs = torch.softmax(next_logits / self.temperature, dim=-1)
            next_id = torch.multinomial(probs, 1)  # [1]
            generated = torch.cat([generated, next_id.view(1, 1)], dim=1)
            n_new += 1

            if next_id.item() == self.tok.eos_token_id:
                break

            # feed ONLY the new token; cache supplies the rest (O(1) attn ctx)
            with torch.no_grad():
                out = self.model(next_id.view(1, 1), past_key_values=past,
                                 use_cache=True)
            past = out.past_key_values
            next_logits = out.logits[0, -1]

            piece = self.tok.decode(next_id)
            at_boundary = any(c in piece for c in (";", "}", "\n"))
            if at_boundary:
                checkpoint = generated.shape[1]

            if n_new % self.check_every == 0 and at_boundary:
                hs = out.hidden_states[self.layer][0, -1]  # new token's state
                risk = self._risk(hs)
                max_risk = max(max_risk, risk)
                if risk > self.risk_threshold and backtracks < self.max_backtracks:
                    risk_triggers += 1
                    backtracks += 1
                    # rewind text AND cache to the checkpoint, then nudge
                    generated = generated[:, :checkpoint]
                    past.crop(checkpoint)
                    hint_ids = self.tok(self.STEER_HINT, return_tensors="pt",
                                        add_special_tokens=False
                                        ).input_ids.to(self.model.device)
                    generated = torch.cat([generated, hint_ids], dim=1)
                    with torch.no_grad():
                        out = self.model(hint_ids, past_key_values=past,
                                         use_cache=True)
                    past = out.past_key_values
                    next_logits = out.logits[0, -1]
                    checkpoint = generated.shape[1]

        text = self.tok.decode(generated[0, prompt_len:], skip_special_tokens=True)
        text = text.replace(self.STEER_HINT, "\n")
        from ..backends import extract_solidity_code
        code = extract_solidity_code(text)
        return code, {"tokens": n_new, "backtracks": backtracks,
                      "risk_triggers": risk_triggers, "max_risk": max_risk}

    def _greedy(self, prompt: str, max_new: int, use_cache: bool) -> list[int]:
        """Deterministic greedy decode, for the cache-equivalence selftest."""
        torch = self.torch
        from transformers import DynamicCache
        input_ids = self._build_inputs(prompt)
        generated = input_ids
        past = DynamicCache() if use_cache else None
        cur = input_ids
        with torch.no_grad():
            out = self.model(cur, past_key_values=past, use_cache=use_cache)
        logits = out.logits[0, -1]
        past = out.past_key_values if use_cache else None
        emitted = []
        for _ in range(max_new):
            nid = int(torch.argmax(logits))
            emitted.append(nid)
            if nid == self.tok.eos_token_id:
                break
            generated = torch.cat(
                [generated, torch.tensor([[nid]], device=generated.device)], 1)
            cur = generated[:, -1:] if use_cache else generated
            with torch.no_grad():
                out = self.model(cur, past_key_values=past, use_cache=use_cache)
            logits = out.logits[0, -1]
            past = out.past_key_values if use_cache else None
        return emitted

    def selftest(self, prompt: str = "Write a minimal ERC20 token.",
                 max_new: int = 40) -> bool:
        """Cache-on must equal cache-off under greedy decoding."""
        a = self._greedy(prompt, max_new, use_cache=True)
        b = self._greedy(prompt, max_new, use_cache=False)
        ok = a == b
        print(f"selftest cache==no-cache: {ok} "
              f"({len(a)} vs {len(b)} tokens{'' if ok else '  MISMATCH'})")
        return ok
