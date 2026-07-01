"""
SecureGen — a modular harness for generation-time defenses against vulnerable
LLM-generated smart contracts.

Every intervention is a `Strategy` (securegen/strategies/) evaluated by an
identical `Analyzer` through one `eval` harness, so "which works / which is
novel" is a direct, paired comparison.

Strategies:
  s0_baseline      plain generation (control)
  s1_prompt_prefix "be secure" instructions (paired, fixes the paper's confound)
  s2_repair_loop   generate -> Slither -> repair, iterate
  s3_checkpoint    skeleton-first, verify each function
  s4_inline_probe  white-box probe-steered decoding (the novel contribution)
"""

__all__ = ["__version__"]
__version__ = "0.1.0"
