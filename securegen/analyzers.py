"""
Vulnerability analyzers behind one interface.

SlitherAnalyzer is the workhorse (fast, compiles + 90 detectors). The same
interface admits Semgrep and Mythril later. The noisy-detector exclusion list
matches the manuscript's filtering (timestamp, reentrancy-benign,
reentrancy-events) so SecureGen numbers are comparable to the paper's corpus.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from abc import ABC, abstractmethod

from .types import AnalysisResult, Finding

# Matches manuscript detector filtering so results line up with the 2,400 corpus.
NOISY_DETECTORS = {
    "timestamp",
    "reentrancy-benign",
    "reentrancy-events",
    "block-timestamp-dependence",
}


class Analyzer(ABC):
    name: str = "abstract"

    @abstractmethod
    def analyze(self, code: str) -> AnalysisResult:
        ...


class SlitherAnalyzer(Analyzer):
    name = "slither"

    def __init__(self, timeout: int = 120, exclude_noisy: bool = True,
                 config_file: str = "slither.config.json"):
        self.timeout = timeout
        self.exclude_noisy = exclude_noisy
        # config_file carries the OpenZeppelin solc_remaps so OZ-importing
        # contracts compile, matching the manuscript corpus pipeline.
        self.config_file = config_file if os.path.exists(config_file) else None

    def analyze(self, code: str) -> AnalysisResult:
        with tempfile.NamedTemporaryFile(
            "w", suffix=".sol", delete=False, dir=os.getcwd()
        ) as fh:
            fh.write(code)
            path = fh.name
        try:
            return self._run(path)
        finally:
            try:
                os.unlink(path)
            except OSError:
                pass

    def _run(self, path: str) -> AnalysisResult:
        cmd = ["slither", path, "--json", "-",
               "--exclude-informational", "--exclude-optimization"]
        if self.config_file:
            cmd += ["--config-file", self.config_file]
        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=self.timeout,
            )
        except subprocess.TimeoutExpired:
            return AnalysisResult(compiled=False, error="timeout")
        except FileNotFoundError:
            return AnalysisResult(compiled=False, error="slither not installed")

        if not result.stdout.strip():
            # `--json -` suppresses the solc error, so re-run plainly to capture
            # the human-readable compile error for repair feedback.
            err = self._compile_error(path) or (result.stderr or "no output")[:500]
            return AnalysisResult(compiled=False, error=err)

        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError:
            return AnalysisResult(compiled=False, error="bad json from slither")

        detectors = data.get("results", {}).get("detectors", [])
        findings: list[Finding] = []
        for d in detectors:
            check = d.get("check", "")
            if self.exclude_noisy and check in NOISY_DETECTORS:
                continue
            findings.append(Finding(
                check=check,
                impact=d.get("impact", ""),
                confidence=d.get("confidence", ""),
                description=(d.get("description", "") or "")[:300],
                source="slither",
            ))
        # slither's success flag can be true even with detectors; compiled == got results
        compiled = bool(data.get("success", True)) or len(detectors) > 0
        return AnalysisResult(compiled=compiled, findings=findings)

    def _compile_error(self, path: str) -> str:
        """Re-run slither without --json to capture the solc compile error."""
        cmd = ["slither", path, "--config-file", self.config_file] \
            if self.config_file else ["slither", path]
        try:
            r = subprocess.run(cmd, capture_output=True, text=True,
                               timeout=self.timeout)
        except Exception:
            return ""
        # keep solc error lines, drop the python traceback noise
        noise = (".py", "raise ", "decoder", "crytic_compile", "Traceback",
                 "InvalidCompilation(")
        lines = []
        for ln in (r.stderr or "").splitlines():
            if any(n in ln for n in noise):
                continue
            if "Error:" in ln or "-->" in ln or "Compilation warnings" in ln \
                    or "Invalid solc" in ln:
                lines.append(ln.strip())
        return "\n".join(lines[:8])[:600]


def findings_as_feedback(result: AnalysisResult, max_items: int = 20) -> str:
    """Render findings into a compact bullet list to feed back to the LLM."""
    if not result.findings:
        return "No vulnerabilities were detected by the static analyzer."
    lines = []
    for f in result.findings[:max_items]:
        loc = f" (line {f.line})" if f.line else ""
        lines.append(f"- [{f.impact}] {f.check}{loc}: {f.description}".rstrip())
    extra = len(result.findings) - max_items
    if extra > 0:
        lines.append(f"- ...and {extra} more findings")
    return "\n".join(lines)
