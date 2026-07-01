"""
S2b — Repair-from-seed (paired ablation).

Instead of generating a fresh contract, this repairs the EXACT contract the
baseline (S0) produced for the same prompt. Because S0 and S2b now share an
identical starting point, the only difference between them is the repair loop —
so the paired delta is a clean causal estimate of "what does repair buy you?",
free of generation variance.

Token/latency here is the MARGINAL cost of repair (the baseline generation was
already paid for and is not re-counted).

Wiring: the runner loads the baseline results JSON and passes a
`{prompt_id: code}` dict as `seeds`. Prompts with no seed (baseline missing /
empty) are returned with an error and skipped by the harness.
"""

from __future__ import annotations

import time

from ..analyzers import Analyzer
from ..backends import Backend, DEFAULT_SYSTEM
from ..types import GenerationResult, Prompt
from .base import Strategy
from ._repair import run_repair


class RepairFromSeedStrategy(Strategy):
    name = "s2b_repair_from_seed"
    description = "Repair the baseline's own contract (paired ablation)."

    def __init__(self, seeds: dict[int, str] | None = None, max_iters: int = 3,
                 stop_when_clean: bool = True):
        self.seeds = seeds or {}
        self.max_iters = max_iters
        self.stop_when_clean = stop_when_clean

    def generate(self, prompt: Prompt, backend: Backend,
                 analyzer: Analyzer) -> GenerationResult:
        res = self._blank_result(prompt, backend)
        seed = self.seeds.get(prompt.id)
        if not seed:
            res.error = "no baseline seed for this prompt"
            return res

        t0 = time.time()
        # Reconstruct the conversation so the model sees what it "wrote", then
        # the repair feedback gets appended by run_repair().
        messages = [
            {"role": "system", "content": DEFAULT_SYSTEM},
            {"role": "user", "content": prompt.prompt},
            {"role": "assistant", "content": f"```solidity\n{seed}\n```"},
        ]
        run_repair(res, messages, backend, analyzer,
                   max_iters=self.max_iters, stop_when_clean=self.stop_when_clean,
                   seed_code=seed)
        res.wall_time_s = time.time() - t0
        return res
