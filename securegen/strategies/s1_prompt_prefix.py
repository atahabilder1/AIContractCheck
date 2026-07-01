"""
S1 — Prompt-level mitigation. Prepend security best-practice instructions.

This is the "does telling the model to be secure help?" intervention. The
manuscript's mitigation experiment found it *backfired*, but that run compared
Claude-enhanced contracts against GPT-4o-original ones (a model confound). Here
S1 runs the same backend as the S0 baseline, so the comparison is properly
paired and the result is trustworthy.
"""

from __future__ import annotations

from ..backends import Backend, extract_solidity_code
from ..analyzers import Analyzer
from ..types import GenerationResult, Prompt
from .base import Strategy

SECURITY_PREFIX = """IMPORTANT SECURITY REQUIREMENTS: Follow these security best practices:
- Use the checks-effects-interactions pattern to prevent reentrancy
- Validate all function inputs (zero address checks, bounds checking)
- Use OpenZeppelin's ReentrancyGuard for functions that make external calls
- Always check return values of external calls
- Implement proper access control with modifiers
- Avoid using block.timestamp for critical logic
- Use SafeERC20 for token transfers

"""


class PromptPrefixStrategy(Strategy):
    name = "s1_prompt_prefix"
    description = "Prepend security best-practice instructions to the prompt."

    def __init__(self, prefix: str = SECURITY_PREFIX):
        self.prefix = prefix

    def generate(self, prompt: Prompt, backend: Backend,
                 analyzer: Analyzer) -> GenerationResult:
        res = self._blank_result(prompt, backend)
        text, usage = backend.generate(self.prefix + prompt.prompt)
        res.usage.add(usage)
        res.code = extract_solidity_code(text)
        res.iterations = 1
        return res
