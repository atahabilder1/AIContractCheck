"""
S0 — Baseline. Plain single-shot generation, no intervention.

This is the control every other strategy is measured against. It reproduces the
exact protocol used to build the 2,400-contract corpus, so the paper's existing
data is directly comparable to a fresh S0 run.
"""

from __future__ import annotations

from ..backends import Backend, extract_solidity_code
from ..analyzers import Analyzer
from ..types import GenerationResult, Prompt
from .base import Strategy


class BaselineStrategy(Strategy):
    name = "s0_baseline"
    description = "Plain single-shot generation (control)."

    def generate(self, prompt: Prompt, backend: Backend,
                 analyzer: Analyzer) -> GenerationResult:
        res = self._blank_result(prompt, backend)
        text, usage = backend.generate(prompt.prompt)
        res.usage.add(usage)
        res.code = extract_solidity_code(text)
        res.iterations = 1
        return res
