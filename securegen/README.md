# SecureGen — generation-time defenses for LLM smart contracts

A modular harness to implement **every** intervention idea as a pluggable
strategy, run them all on the same prompts through the same verifier, and let the
data show **which works and which is most novel**.

## The thesis (paper hook)

The empirical study (`manuscript/`) showed vulnerabilities are *intrinsic* to LLM
generation (RQ4: adversarial prompts had no effect, p=0.965) and that prompt-level
mitigation *backfired*. SecureGen tests the natural next claim: **you can't fix
this by asking nicely — you need a verifier in the generation loop.** We build
that loop at three granularities and measure the effectiveness/cost frontier.

## Strategies (one file each, `strategies/`)

| id | what it does | granularity | needs |
|----|--------------|-------------|-------|
| `s0_baseline`      | plain single-shot (control) | — | any backend |
| `s1_prompt_prefix` | "be secure" instructions, **same model** (fixes paper's confound) | — | any backend |
| `s2_repair_loop`   | generate → Slither → feed findings → repair, ≤K rounds | contract | any backend |
| `s3_checkpoint`    | skeleton-first; implement & verify one function at a time | function | any backend |
| `s4_inline_probe`  | **novel:** probe-steered decoding, backtrack on risk spikes | sub-statement | white-box (torch + GPU + trained probe) |

Add a new idea = add a `Strategy` subclass + one line in `strategies/__init__.py`.

## The novel contribution (S4)

Slither/Mythril can't run mid-generation (need compilable code, too slow). So:

- **Teacher** = Slither/Mythril labels on the existing 2,400-contract corpus.
- **Student** = a tiny probe on the open model's residual stream → inline risk.
- **Verifier** = Slither/Mythril on the final contract → evaluation only.

`probe/train_probe.py` reports AUROC of the probe vs Slither — itself a result
("vulnerability is linearly decodable from layer L at AUROC X"). The steered
decoder backtracks to the last safe boundary and re-decodes with a nudge when
risk crosses threshold.

## Run it

```bash
# one strategy over 20 prompts (uses your API/Ollama keys from .env)
python -m securegen.eval.runner --strategy s0_baseline   --backend gpt4o --limit 20
python -m securegen.eval.runner --strategy s2_repair_loop --backend gpt4o --limit 20

# compare any set against the baseline (paired Wilcoxon + Cliff's delta)
python -m securegen.eval.compare \
  securegen/results/s0_baseline__gpt4o.json \
  securegen/results/s1_prompt_prefix__gpt4o.json \
  securegen/results/s2_repair_loop__gpt4o.json

# S4 probe pipeline (white-box, on the 3090/A6000)
python -m securegen.probe.extract_activations --model Qwen/Qwen2.5-Coder-7B-Instruct --limit 400
python -m securegen.probe.train_probe
python -m securegen.eval.runner --strategy s4_inline_probe --backend qwen --limit 20
```

## What the comparison table tells you

`compare.py` prints, per strategy: compile rate, mean vulns / high-sev, density
per 100 LOC, **mean output tokens + wall-clock (the cost of the intervention)**,
and the **paired delta vs baseline** with significance. The paper's money figure
is the effectiveness-vs-cost frontier across s0→s4.

## Fairness guarantees (enforced in `eval/runner.py`, not in strategies)

- The harness re-runs the analyzer on every strategy's **final** code itself.
- Same analyzer, same noisy-detector exclusion list as the manuscript corpus.
- Results written incrementally and keyed by prompt id (resume-friendly).
- `s1`/`s2`/`s3` use the **same backend** as `s0` → properly paired.
