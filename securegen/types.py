"""
Core data types shared by every strategy, backend, and analyzer.

The whole point of SecureGen is that every intervention strategy produces the
*same* record (`GenerationResult`) so they can be compared apples-to-apples.
If you add a new strategy, it must return one of these — nothing else changes.
"""

from __future__ import annotations

from dataclasses import dataclass, field, asdict
from typing import Any, Optional


@dataclass
class Prompt:
    """A single generation task (from prompts/all_prompts.json)."""
    id: int
    category: str
    prompt: str
    type: str = "standard"
    complexity: str = ""

    @classmethod
    def from_dict(cls, d: dict) -> "Prompt":
        return cls(
            id=d["id"],
            category=d.get("category", ""),
            prompt=d["prompt"],
            type=d.get("type", "standard"),
            complexity=d.get("complexity", ""),
        )


@dataclass
class Finding:
    """One vulnerability finding from an analyzer, normalized across tools."""
    check: str            # detector / rule name, e.g. "reentrancy-eth"
    impact: str           # "High" | "Medium" | "Low" | "Informational"
    confidence: str = ""  # tool-reported confidence if any
    line: int = 0
    description: str = ""
    source: str = "slither"  # which analyzer produced it


@dataclass
class AnalysisResult:
    """Output of running an analyzer on one contract."""
    compiled: bool
    findings: list[Finding] = field(default_factory=list)
    error: str = ""

    @property
    def total(self) -> int:
        return len(self.findings)

    @property
    def high(self) -> int:
        return sum(1 for f in self.findings if f.impact == "High")

    @property
    def medium(self) -> int:
        return sum(1 for f in self.findings if f.impact == "Medium")

    @property
    def low(self) -> int:
        return sum(1 for f in self.findings if f.impact == "Low")


@dataclass
class TokenUsage:
    """Token accounting so we can report the *cost* of each strategy."""
    input_tokens: int = 0
    output_tokens: int = 0
    llm_calls: int = 0

    def add(self, other: "TokenUsage") -> None:
        self.input_tokens += other.input_tokens
        self.output_tokens += other.output_tokens
        self.llm_calls += other.llm_calls

    @property
    def total(self) -> int:
        return self.input_tokens + self.output_tokens


@dataclass
class GenerationResult:
    """
    The uniform record every strategy emits. This is what the eval harness
    aggregates and what compare.py runs statistics over.
    """
    prompt_id: int
    category: str
    complexity: str
    strategy: str
    backend: str

    code: str                       # final contract text
    analysis: Optional[AnalysisResult] = None

    iterations: int = 1             # how many generate/repair rounds it took
    usage: TokenUsage = field(default_factory=TokenUsage)
    wall_time_s: float = 0.0
    loc: int = 0                    # non-blank lines of the final contract

    # Strategy-specific breadcrumbs (intermediate analyses, probe triggers, etc.)
    trace: list[dict] = field(default_factory=list)
    error: str = ""

    # --- convenience metrics (None when the contract never compiled) ---
    @property
    def compiled(self) -> bool:
        return bool(self.analysis and self.analysis.compiled)

    @property
    def total_vulns(self) -> Optional[int]:
        return self.analysis.total if self.compiled else None

    @property
    def high(self) -> Optional[int]:
        return self.analysis.high if self.compiled else None

    @property
    def density_per_100loc(self) -> Optional[float]:
        if not self.compiled or self.loc == 0:
            return None
        return 100.0 * self.analysis.total / self.loc

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        # flatten a few derived metrics for easy CSV/JSON consumption
        d["compiled"] = self.compiled
        d["total_vulns"] = self.total_vulns
        d["high"] = self.high
        d["density_per_100loc"] = self.density_per_100loc
        return d


def count_loc(code: str) -> int:
    """Non-blank, non-comment-only line count (rough, matches paper convention)."""
    n = 0
    for line in code.splitlines():
        s = line.strip()
        if not s or s.startswith("//"):
            continue
        n += 1
    return n
