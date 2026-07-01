"""
S2 — Closed-loop repair. Generate, run Slither, feed findings back, repair.
Repeat until clean or the iteration budget is exhausted.

This is the feasible, contract-level realization of "verify the model and force
correction." It is the strong baseline the inline-probe (S4) must beat on
cost/latency. It generates fresh and then repairs — the whole pipeline. For the
clean causal "does repair help on a FIXED contract?" question, use the paired
ablation s2b_repair_from_seed instead.

The loop keeps the BEST contract seen across iterations (fewest weighted vulns
among those that compile), not merely the last one — repair can regress.
"""

from __future__ import annotations

import time

from ..analyzers import Analyzer
from ..backends import Backend, DEFAULT_SYSTEM
from ..types import GenerationResult, Prompt
from .base import Strategy
from ._repair import run_repair


class RepairLoopStrategy(Strategy):
    name = "s2_repair_loop"
    description = "Generate -> Slither -> feed findings -> repair, up to K rounds."

    def __init__(self, max_iters: int = 3, stop_when_clean: bool = True):
        self.max_iters = max_iters
        self.stop_when_clean = stop_when_clean

    def generate(self, prompt: Prompt, backend: Backend,
                 analyzer: Analyzer) -> GenerationResult:
        res = self._blank_result(prompt, backend)
        t0 = time.time()
        messages = [
            {"role": "system", "content": DEFAULT_SYSTEM},
            {"role": "user", "content": prompt.prompt},
        ]
        run_repair(res, messages, backend, analyzer,
                   max_iters=self.max_iters, stop_when_clean=self.stop_when_clean)
        res.wall_time_s = time.time() - t0
        return res
