"""
Shared repair-loop core, used by both:
  * s2_repair_loop      — generate fresh, then repair (end-to-end strategy)
  * s2b_repair_from_seed — repair a GIVEN baseline contract (paired ablation)

Keeping the loop in one place guarantees the two strategies differ ONLY in their
starting point, so the ablation cleanly isolates the repair effect from
generation variance.
"""

from __future__ import annotations

from ..analyzers import Analyzer, findings_as_feedback
from ..backends import Backend, extract_solidity_code
from ..types import AnalysisResult, GenerationResult, count_loc


def score(a: AnalysisResult) -> tuple[int, int]:
    """Lower is better: (weighted severity, total). Non-compiling sorts worst."""
    if not a.compiled:
        return (10**9, 10**9)
    return (5 * a.high + 2 * a.medium + a.low, a.total)


def _feedback(analysis: AnalysisResult) -> str:
    if not analysis.compiled:
        return (f"The contract did not compile. Compiler error:\n{analysis.error}\n\n"
                f"Fix it and return the COMPLETE corrected contract. Only Solidity code.")
    return (f"A static analyzer found these issues in your contract:\n"
            f"{findings_as_feedback(analysis)}\n\n"
            f"Fix every issue and return the COMPLETE corrected contract. Keep all "
            f"original functionality. Return only Solidity code.")


def _trace(res: GenerationResult, it: int, analysis: AnalysisResult,
           kind: str) -> None:
    res.trace.append({
        "iter": it, "kind": kind, "compiled": analysis.compiled,
        "total": analysis.total if analysis.compiled else None,
        "high": analysis.high if analysis.compiled else None,
        "medium": analysis.medium if analysis.compiled else None,
        "low": analysis.low if analysis.compiled else None,
        "error": analysis.error[:200] if analysis.error else "",
    })


def run_repair(res: GenerationResult, messages: list[dict], backend: Backend,
               analyzer: Analyzer, max_iters: int, stop_when_clean: bool = True,
               seed_code: str | None = None,
               seed_analysis: AnalysisResult | None = None) -> None:
    """Drive the repair loop, mutating `res` in place.

    If `seed_code` is given it counts as iteration 1 (no LLM call — the
    generation cost was already paid by the baseline), and `messages` must
    already contain the assistant turn carrying that seed. Otherwise iteration 1
    is a fresh generation from `messages`.
    """
    best_code, best_analysis = "", None
    it = 0

    if seed_code is not None:
        it = 1
        analysis = seed_analysis or analyzer.analyze(seed_code)
        _trace(res, it, analysis, "seed")
        best_code, best_analysis = seed_code, analysis
        res.iterations = it
        if stop_when_clean and analysis.compiled and analysis.total == 0:
            res.code, res.loc = best_code, count_loc(best_code)
            return
        if it >= max_iters:
            res.code, res.loc = best_code, count_loc(best_code)
            return
        messages.append({"role": "user", "content": _feedback(analysis)})

    while it < max_iters:
        it += 1
        text, usage = backend.chat(messages)
        res.usage.add(usage)
        code = extract_solidity_code(text)
        analysis = analyzer.analyze(code)
        _trace(res, it, analysis, "repair" if seed_code is not None or it > 1
               else "generate")

        if best_analysis is None or score(analysis) < score(best_analysis):
            best_code, best_analysis = code, analysis
        res.iterations = it

        if stop_when_clean and analysis.compiled and analysis.total == 0:
            break
        if it >= max_iters:
            break
        messages.append({"role": "assistant", "content": text})
        messages.append({"role": "user", "content": _feedback(analysis)})

    res.code = best_code
    res.loc = count_loc(best_code)
