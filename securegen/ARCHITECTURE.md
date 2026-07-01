# SecureGen architecture — where control lives

The whole design turns on one question: **where in the generation process can you
intervene?** There are three intervention points, and they define the strategy
space. "Control" = how deep into the model's process your defense can reach.

```
                         THE GENERATION TIMELINE
   prompt ──▶ [ token → token → token → … → token ] ──▶ full contract ──▶ deploy
      │                      │                              │
      ▼                      ▼                              ▼
  (1) BEFORE            (2) DURING                     (3) AFTER
  edit the prompt      pause / inspect / backtrack     analyze & re-ask
  s1_prompt_prefix     s4_inline_probe                 s0,s2,s2b,s3
```

## Two kinds of control

- **Outer-loop control** = intervene at *boundaries* (after a whole contract, or
  after a function). The model generates blindly; you check the output and loop.
  Points (1) and (3). **Works on ANY model — including closed APIs.**
- **Inner-loop control** = intervene *inside decoding*, token by token: read the
  hidden state, score risk, pause, backtrack, steer. Point (2). **Requires an
  open-weight model you run yourself.**

## API (black box) vs open weights (white box)

| capability | API (GPT/Claude/Gemini) | Ollama (qwen/codestral) | transformers (white-box) |
|---|---|---|---|
| edit prompt (point 1)        | ✅ | ✅ | ✅ |
| read final text (point 3)    | ✅ | ✅ | ✅ |
| multi-turn repair            | ✅ | ✅ | ✅ |
| token probabilities / logits | ❌ | ❌ | ✅ |
| hidden states (residual)     | ❌ | ❌ | ✅ |
| pause/backtrack mid-decode   | ❌ | ❌ | ✅ |

Key subtlety: **Ollama is only semi-open.** It serves text in/out like an API,
so s0–s3 run on it — but it does *not* expose hidden states. s4 therefore loads
the model through `transformers` (`probe/steered_decoder.py`), not the Ollama
backend. "Open box you can modify/pause" specifically means the transformers
path.

## Strategy → control-point → requirement

| strategy | intervention point | loop | needs |
|---|---|---|---|
| `s0_baseline`      | none (control)        | —     | API or open |
| `s1_prompt_prefix` | (1) before            | —     | API or open |
| `s2_repair_loop`   | (3) after contract    | outer | API or open |
| `s2b_repair_from_seed` | (3) after, paired | outer | API or open |
| `s3_checkpoint`    | (3) after each fn     | outer | API or open |
| `s4_inline_probe`  | (2) during decoding   | inner | **open white-box only** |

## Why this is the paper's contribution, not a limitation

The open-vs-API split is the **axis of the design space**, not an excuse:

- **Outer-loop (s2/s2b/s3):** maximum compatibility (even closed APIs), but the
  model has already committed to a vulnerable structure before you catch it —
  repair is reactive and can be costly or fail (e.g. it can't fix a contract the
  base model can't compile).
- **Inner-loop (s4):** open models only, but it prevents the vulnerability *as it
  is being written* — proactive, cheaper, and catches things repair can't.

The experiments measure the full frontier: effectiveness (Δvulns, compile rate)
vs cost (tokens, latency) from no control → outer-loop → inner-loop.

## Data flow (one strategy run)

```
Prompt ──▶ Strategy.generate(prompt, backend, analyzer)
                │  (strategy owns HOW it generates + self-corrects)
                ▼
           final code  ──▶  eval/runner.py  ──▶  Analyzer (Slither) re-scores
                                │                 (FAIRNESS: harness scores, not
                                ▼                  the strategy, so every strategy
                          GenerationResult         is judged identically)
                                │
                                ▼
                       eval/compare.py  ──▶  paired Δ vs baseline,
                                              Wilcoxon p, Cliff's δ
```

The teacher/student/verifier roles for s4:
- **Teacher** = Slither/Mythril on the 2,400-contract corpus → training labels.
- **Student** = probe on residual stream → cheap inline risk signal.
- **Verifier** = Slither on the final contract → evaluation (same as every other
  strategy).
