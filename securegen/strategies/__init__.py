"""Strategy registry. Add a new intervention = add one line here."""

from __future__ import annotations

from .base import Strategy
from .s0_baseline import BaselineStrategy
from .s1_prompt_prefix import PromptPrefixStrategy
from .s2_repair_loop import RepairLoopStrategy
from .s2b_repair_from_seed import RepairFromSeedStrategy
from .s3_checkpoint import CheckpointStrategy

# S4 is import-guarded: it pulls torch/transformers only when instantiated.
_FACTORIES = {
    "s0_baseline": BaselineStrategy,
    "s1_prompt_prefix": PromptPrefixStrategy,
    "s2_repair_loop": RepairLoopStrategy,
    "s2b_repair_from_seed": RepairFromSeedStrategy,
    "s3_checkpoint": CheckpointStrategy,
}


def get_strategy(name: str, **kwargs) -> Strategy:
    """Construct a strategy by id. `kwargs` (e.g. seeds=...) are forwarded to the
    strategy constructor when it accepts them."""
    if name.startswith("s4"):
        from .s4_inline_probe import InlineProbeStrategy
        return InlineProbeStrategy()
    if name not in _FACTORIES:
        raise ValueError(f"Unknown strategy '{name}'. Options: "
                         f"{list(_FACTORIES) + ['s4_inline_probe']}")
    if name == "s2b_repair_from_seed":
        return RepairFromSeedStrategy(seeds=kwargs.get("seeds") or {})
    return _FACTORIES[name]()


def list_strategies() -> list[str]:
    return list(_FACTORIES) + ["s4_inline_probe"]
