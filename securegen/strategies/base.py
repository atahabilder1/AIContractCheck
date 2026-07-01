"""
Strategy interface. Every intervention is a subclass that turns a Prompt into a
GenerationResult, using a Backend (the LLM) and an Analyzer (the verifier).

Design rule: a strategy owns *how* it generates and self-corrects; the eval
harness owns *timing, persistence, and the final analysis pass*. To keep the
comparison fair, the harness re-runs the analyzer on every strategy's final code
itself — a strategy's internal analyses are only breadcrumbs in `trace`.
"""

from __future__ import annotations

from abc import ABC, abstractmethod

from ..analyzers import Analyzer
from ..backends import Backend
from ..types import GenerationResult, Prompt


class Strategy(ABC):
    #: short id used on the CLI and in result files, e.g. "s2_repair_loop"
    name: str = "abstract"
    #: one-line human description shown in comparison tables
    description: str = ""

    @abstractmethod
    def generate(self, prompt: Prompt, backend: Backend,
                 analyzer: Analyzer) -> GenerationResult:
        """Produce the final contract for `prompt`. Must set .code and .usage."""

    # convenience for building a partially-filled result
    def _blank_result(self, prompt: Prompt, backend: Backend) -> GenerationResult:
        return GenerationResult(
            prompt_id=prompt.id,
            category=prompt.category,
            complexity=prompt.complexity,
            strategy=self.name,
            backend=backend.name,
            code="",
        )
