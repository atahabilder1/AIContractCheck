"""
S3 — Checkpoint generation. Generate an interface/skeleton first, then fill in
function bodies, analyzing at each compilable checkpoint and repairing before
moving on. This is the function-granularity middle ground between contract-level
repair (S2) and true inline steering (S4): the model "pauses" at structural
boundaries rather than after the whole contract is written.

Why a skeleton-first approach instead of raw token streaming: partial Solidity
doesn't compile, so Slither can't run on it. By asking the model to emit a
compilable skeleton (interfaces + stubbed function bodies that revert) we always
have something analyzable, then we harden one function at a time.

This is intentionally the most experimental of the API-only strategies — it
tests whether *localized* feedback ("this function is vulnerable") outperforms
*global* feedback ("the contract has these issues"). Keep it modular so its
win/loss vs S2 is a clean datapoint.
"""

from __future__ import annotations

import time

from ..analyzers import Analyzer, findings_as_feedback
from ..backends import Backend, DEFAULT_SYSTEM, extract_solidity_code
from ..types import GenerationResult, Prompt, count_loc
from .base import Strategy

SKELETON_INSTR = (
    "First, design ONLY the contract skeleton for this request: SPDX + pragma, "
    "imports, state variables, events, and every function SIGNATURE with an empty "
    "or `revert(\"todo\")` body. It must compile. Do not implement logic yet.\n\n"
    "Request: {req}"
)

FILL_INSTR = (
    "Here is the current contract:\n```solidity\n{code}\n```\n\n"
    "Now implement the body of `{fn}` securely (checks-effects-interactions, input "
    "validation, access control, checked external calls). Return the COMPLETE "
    "updated contract, keeping every other function as-is. Only Solidity code."
)


class CheckpointStrategy(Strategy):
    name = "s3_checkpoint"
    description = "Skeleton-first; implement & verify one function at a time."

    def __init__(self, max_functions: int = 8, repair_each: bool = True):
        self.max_functions = max_functions
        self.repair_each = repair_each

    def _function_names(self, code: str) -> list[str]:
        names = []
        for line in code.splitlines():
            s = line.strip()
            if s.startswith("function "):
                head = s[len("function "):]
                name = head.split("(")[0].strip()
                if name and name not in names:
                    names.append(name)
        return names[: self.max_functions]

    def generate(self, prompt: Prompt, backend: Backend,
                 analyzer: Analyzer) -> GenerationResult:
        res = self._blank_result(prompt, backend)
        t0 = time.time()
        iters = 0

        # 1) skeleton
        text, usage = backend.generate(
            SKELETON_INSTR.format(req=prompt.prompt), system=DEFAULT_SYSTEM)
        res.usage.add(usage)
        code = extract_solidity_code(text)
        iters += 1
        res.trace.append({"step": "skeleton", "loc": count_loc(code)})

        # 2) fill each function, optionally re-analyzing as a checkpoint
        for fn in self._function_names(code):
            msg = FILL_INSTR.format(code=code, fn=fn)
            text, usage = backend.generate(msg, system=DEFAULT_SYSTEM)
            res.usage.add(usage)
            new_code = extract_solidity_code(text)
            iters += 1

            if self.repair_each:
                analysis = analyzer.analyze(new_code)
                res.trace.append({
                    "step": f"fill:{fn}", "compiled": analysis.compiled,
                    "total": analysis.total, "high": analysis.high,
                })
                # only accept the new code if it still compiles
                if analysis.compiled:
                    code = new_code
                # if a checkpoint introduced a high-sev issue, ask for a local fix
                if analysis.compiled and analysis.high > 0:
                    fb = (f"`{fn}` introduced high-severity issues:\n"
                          f"{findings_as_feedback(analysis)}\n\nFix and return the "
                          f"complete contract. Only Solidity code.")
                    text, usage = backend.generate(fb, system=DEFAULT_SYSTEM)
                    res.usage.add(usage)
                    fixed = extract_solidity_code(text)
                    iters += 1
                    if analyzer.analyze(fixed).compiled:
                        code = fixed
            else:
                code = new_code
                res.trace.append({"step": f"fill:{fn}", "loc": count_loc(new_code)})

        res.code = code
        res.iterations = iters
        res.loc = count_loc(code)
        res.wall_time_s = time.time() - t0
        return res
