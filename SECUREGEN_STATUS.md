# SecureGen — Status & Plan (current)

> This supersedes `STATUS_AND_PLAN.md` (which describes the old 6-LLM / 1,800-contract
> measurement study). The project has since (a) grown to **8 LLMs / 2,400 contracts**
> plus a 241-contract human baseline, and (b) **pivoted** from a pure measurement
> study to a **method contribution**: generation-time defenses (SecureGen).
> See `docs/SecureGen_S4_explainer.pdf` for a plain-language walkthrough.

## The thesis

The measurement study found LLM smart-contract vulnerabilities are **intrinsic** —
adversarial prompts don't move the needle (p≈0.997), and prompt-based mitigation
backfired. Motivation for SecureGen: *you can't fix this by asking nicely; you need
a verifier inside the generation loop.*

## SecureGen harness (`securegen/`)

Modular: every intervention is a pluggable `Strategy`, scored by ONE analyzer
(Slither) through one eval harness (the runner re-runs Slither on each strategy's
final code, so all strategies are judged by the identical verifier).

| Strategy | Idea | Status |
|----------|------|--------|
| S0 baseline | plain generation (control) | ✅ |
| S1 prompt prefix | security instruction prefix (paired) | ✅ |
| S2 / S2b repair loop | generate → Slither → repair (S2b repairs the exact S0 contract) | ✅ **large effect** |
| S3 checkpoint | skeleton-first, per-function | ✅ |
| **S4 inline probe** | **probe-steered decoding (the novel one)** | 🔬 **experimenting now** |

**S2b clean paired result (Gemini):** density 4.70 → 0.83 /100 LOC,
Cliff's δ = −0.75 (large). S4 novelty need not beat S2b — S4's value is the
*cost/effectiveness frontier* + the probe-decodability result.

## S4 — where we are (Jul 1 2026, RTX 3090)

**Open model:** `Qwen/Qwen2.5-Coder-7B-Instruct`, run white-box via HuggingFace
`transformers` (NOT Ollama — Ollama can't expose activations). ~15 GB cached.

### Done
1. **Bug fixes** (both flagged threats resolved):
   - `extract_activations.py`: line labels now parsed from `dedup_key` `#L<a>-L<b>`
     (old `v.get("line")` matched 0/2493 records). Offset-mapping token→line;
     one activation per line (line's final token); compiled Qwen contracts only;
     stores contract ids.
   - `train_probe.py`: **contract-level** 80/20 split (was token-shuffle → leak).
2. **Probe de-risk — GREEN LIGHT.** 237 compiled Qwen contracts → 10,287 line
   samples (13% positive). **Linear probe AUROC = 0.887 at layer 12.**
   → *Vulnerability is linearly decodable from Qwen's own representations.*
3. **Layer sweep** (`sweep_layers.py`): signal flat across depth (0.86–0.89).
   Chose **layer 12** (tied-best, lowest variance, mid-network = earlier signal).
4. **Steered decoder** (`steered_decoder.py`): rewrote with **KV-cache**
   (O(n²)→O(n)) + backtrack cache-truncation. **Verified correct**: cache-on ==
   cache-off (byte-identical greedy output).
5. **Paired A/B harness** (`ab_test.py`): same seed, steering OFF vs ON, Slither
   both → paired Δvulns.

### Result: does steering reduce vulns? (pilot, 15 prompts, threshold 0.5)
**Mixed — the signal works, naive steering does not (yet) reduce vulns.**

| Metric (OFF → ON) | Value |
|---|---|
| Compile rate | **40% → 60%** ✅ (rescued 3 non-compiling contracts) |
| Mean vulns (compiled only) | 0.83 → 1.89 ⚠️ |
| Density /100 LOC | 1.25 → 3.25 ⚠️ |
| High-sev total | 0 → 3 ⚠️ |
| **Paired Δvulns (n=6 both compiled)** | **+0.33** ❌ not reduced |
| Backtracks fired | 16 |

**Interpretation:** the probe (AUROC 0.89) clearly separates risk, and steering
*improves compilability* (the CEI nudge + re-decode helps the model finish valid
code). But on contracts that compiled both ways, vulns were flat except one
regression (id 139: 0→2); rescued contracts compile *with* vulns (id 182 bridge:
NC→9), inflating the mean. Naive comment-injection steering does not reduce
vulnerability density at threshold 0.5. Result file: `securegen/results/ab_steering.json`.

**Why (hypotheses) → next steps:** (1) train/inference **calibration mismatch**
(probe trained on finished contracts, sees partial generation at inference) →
self-generation rewrite; (2) the **steering intervention** (inject a comment,
re-decode) perturbs but doesn't truly steer toward safe patterns → try
logit-biasing / stronger nudges; (3) **threshold 0.5** may be wrong → sweep.

### Next
- **Self-generation rewrite** — Qwen generates its own contracts, Slither labels
  them, activations taken at generation-consistent positions (removes the mild
  train/inference mismatch of the quick-corpus path). This is the paper-grade
  AUROC number.
- **Scale A/B to 300 prompts** for significance (paired Wilcoxon + Cliff's δ).
- **Threshold sweep** — find the risk cutoff that best trades vulns vs compile rate.
- **Bigger open models** (DeepSeek-V2, CodeLlama-34B) — needs the 48 GB A6000.

## Key files
| File | Role |
|------|------|
| `securegen/probe/extract_activations.py` | build (activation, vuln-label) pairs |
| `securegen/probe/sweep_layers.py` | which layer best exposes vulnerability |
| `securegen/probe/train_probe.py` | train tiny probe, report AUROC |
| `securegen/probe/steered_decoder.py` | KV-cached probe-steered decoding |
| `securegen/probe/ab_test.py` | paired OFF-vs-ON evaluation |
| `securegen/eval/runner.py` | fair strategy scoring harness |
| `docs/SecureGen_S4_explainer.pdf` | plain-language walkthrough |

## Hardware
- **This server (`homeserveer3090`)**: RTX 3090 (24 GB) — runs the white-box probe/decoder.
- **A6000 box (`labubuntua6000`, 100.127.35.85)**: RTX A6000 (48 GB), Tailscale —
  reachable (ping + ssh:22) but key auth not yet set up. Enables bigger models +
  parallel 300-prompt runs.
