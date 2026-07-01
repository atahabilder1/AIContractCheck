"""
Eval harness. Runs ONE strategy over a set of prompts and writes a results file.

Fairness guarantees enforced here (not in strategies):
  * The harness re-runs the analyzer on each strategy's FINAL code itself, so
    every strategy is scored by the identical verifier under identical settings.
  * Timing wraps the whole strategy call.
  * Results are written incrementally (resume-friendly) keyed by prompt id.
"""

from __future__ import annotations

import json
import time
from pathlib import Path

from ..analyzers import Analyzer, SlitherAnalyzer
from ..backends import Backend, get_backend
from ..strategies import get_strategy
from ..types import Prompt, count_loc

PROMPTS_FILE = Path("prompts/all_prompts.json")
RESULTS_DIR = Path("securegen/results")


def load_prompts(ids: list[int] | None = None,
                 limit: int | None = None) -> list[Prompt]:
    data = json.loads(PROMPTS_FILE.read_text())
    prompts = [Prompt.from_dict(d) for d in data]
    if ids is not None:
        idset = set(ids)
        prompts = [p for p in prompts if p.id in idset]
    if limit is not None:
        prompts = prompts[:limit]
    return prompts


def _load_seeds(seeds_from: str) -> dict[int, str]:
    """Build {prompt_id: code} from a baseline results JSON (e.g. S0 output)."""
    seeds = {}
    for r in json.loads(Path(seeds_from).read_text()):
        code = r.get("code")
        if code:
            seeds[r["prompt_id"]] = code
    return seeds


def run(strategy_name: str, backend_name: str, prompts: list[Prompt],
        analyzer: Analyzer | None = None, out_path: Path | None = None,
        resume: bool = True, seeds_from: str | None = None) -> Path:
    analyzer = analyzer or SlitherAnalyzer()
    skw = {}
    if seeds_from:
        skw["seeds"] = _load_seeds(seeds_from)
        print(f"Loaded {len(skw['seeds'])} baseline seeds from {seeds_from}")
    strategy = get_strategy(strategy_name, **skw)
    backend = get_backend(backend_name) if not strategy_name.startswith("s4") \
        else _NullBackend(backend_name)

    out_path = out_path or (
        RESULTS_DIR / f"{strategy_name}__{backend_name}.json")
    out_path.parent.mkdir(parents=True, exist_ok=True)

    done: dict[int, dict] = {}
    if resume and out_path.exists():
        for r in json.loads(out_path.read_text()):
            done[r["prompt_id"]] = r
        print(f"Resuming: {len(done)} already done")

    results = list(done.values())
    for i, p in enumerate(prompts):
        if p.id in done:
            continue
        print(f"[{i+1}/{len(prompts)}] id={p.id} {p.category} | {strategy_name}")
        t0 = time.time()
        try:
            res = strategy.generate(p, backend, analyzer)
        except Exception as e:
            print(f"   strategy error: {e}")
            res = strategy._blank_result(p, backend)
            res.error = str(e)

        # FAIRNESS: harness scores the final code with its own analyzer.
        if res.code and not res.error:
            res.analysis = analyzer.analyze(res.code)
            if not res.loc:
                res.loc = count_loc(res.code)
        if not res.wall_time_s:
            res.wall_time_s = time.time() - t0

        rec = res.to_dict()
        results.append(rec)
        # write incrementally
        out_path.write_text(json.dumps(results, indent=2, default=_json_default))
        c = rec.get("compiled")
        v = rec.get("total_vulns")
        print(f"   compiled={c} vulns={v} iters={rec['iterations']} "
              f"tok={rec['usage']['output_tokens']} {res.wall_time_s:.1f}s")

    print(f"\nSaved -> {out_path}")
    return out_path


def _json_default(o):
    # dataclasses already converted via to_dict(); AnalysisResult nested -> dict
    from dataclasses import asdict, is_dataclass
    if is_dataclass(o):
        return asdict(o)
    return str(o)


class _NullBackend(Backend):
    """Placeholder passed to S4 (which drives its own white-box model)."""
    def __init__(self, name): self.name = name
    def chat(self, *a, **k):
        raise RuntimeError("S4 uses its own white-box engine, not chat()")


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--strategy", required=True)
    ap.add_argument("--backend", default="gpt4o")
    ap.add_argument("--ids", type=int, nargs="*")
    ap.add_argument("--limit", type=int, default=20)
    ap.add_argument("--seeds-from", default=None,
                    help="baseline results JSON to repair from (for s2b)")
    args = ap.parse_args()
    run(args.strategy, args.backend,
        load_prompts(ids=args.ids, limit=args.limit),
        seeds_from=args.seeds_from)
