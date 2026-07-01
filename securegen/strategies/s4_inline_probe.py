"""
S4 — Inline security-steered decoding (the novel one).

Idea: Slither/Mythril can't run mid-generation (they need compilable code and
are slow). So we train a tiny neural *probe* on an open model's hidden states to
predict "is the code being written drifting toward a vulnerability Slither would
flag?". The probe is cheap enough to run every few tokens. When it crosses a
risk threshold at a statement boundary, we BACKTRACK to the last safe checkpoint
and re-decode with a steering nudge (e.g. resample / inject a CEI reminder /
penalize the risky continuation).

Teacher–student framing (this is the contribution):
  * TEACHER  = Slither/Mythril on the 2,400-contract corpus -> ground-truth labels
  * STUDENT  = linear/MLP probe on residual-stream activations -> inline signal
  * VERIFIER = Slither/Mythril again, on the final contract -> evaluation only

This module is white-box: it needs `transformers` + a GPU + a trained probe
(see securegen/probe/). It is import-safe — heavy deps load lazily so the
API-only strategies (S0–S3) never pull in torch.
"""

from __future__ import annotations

import time

from ..analyzers import Analyzer
from ..backends import Backend
from ..types import GenerationResult, Prompt, count_loc
from .base import Strategy


class InlineProbeStrategy(Strategy):
    name = "s4_inline_probe"
    description = "Probe-steered decoding: backtrack when vuln risk spikes."

    def __init__(self, model_id: str = "Qwen/Qwen2.5-Coder-7B-Instruct",
                 probe_path: str = "securegen/probe/probe.pt",
                 risk_threshold: float = 0.6,
                 check_every: int = 16,
                 max_backtracks: int = 8,
                 max_new_tokens: int = 1500):
        self.model_id = model_id
        self.probe_path = probe_path
        self.risk_threshold = risk_threshold
        self.check_every = check_every
        self.max_backtracks = max_backtracks
        self.max_new_tokens = max_new_tokens
        self._engine = None  # lazily built

    def _ensure_engine(self):
        if self._engine is None:
            # imported here so torch/transformers are only required for S4
            from ..probe.steered_decoder import SteeredDecoder
            self._engine = SteeredDecoder(
                model_id=self.model_id,
                probe_path=self.probe_path,
                risk_threshold=self.risk_threshold,
                check_every=self.check_every,
                max_backtracks=self.max_backtracks,
                max_new_tokens=self.max_new_tokens,
            )
        return self._engine

    def generate(self, prompt: Prompt, backend: Backend,
                 analyzer: Analyzer) -> GenerationResult:
        # NB: S4 ignores `backend` — it drives its own white-box model. We accept
        # the arg to keep the Strategy interface uniform.
        res = self._blank_result(prompt, backend)
        res.backend = f"whitebox:{self.model_id}"
        t0 = time.time()

        engine = self._ensure_engine()
        code, info = engine.generate(prompt.prompt)

        res.code = code
        res.usage.output_tokens = info.get("tokens", 0)
        res.usage.llm_calls = 1
        res.iterations = 1
        res.loc = count_loc(code)
        res.trace.append({
            "backtracks": info.get("backtracks", 0),
            "risk_triggers": info.get("risk_triggers", 0),
            "max_risk": info.get("max_risk", 0.0),
        })
        res.wall_time_s = time.time() - t0
        return res
