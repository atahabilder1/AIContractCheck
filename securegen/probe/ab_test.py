"""
Does the idea WORK? Paired A/B: same white-box decoder, steering OFF vs ON.

For each prompt we seed the RNG identically, then generate twice:
  OFF  = risk_threshold huge -> probe never fires -> pure baseline Qwen decode
  ON   = layer-12 probe steers, backtracking on risk spikes
Because the seed matches, the two runs are token-identical until the first
intervention, so any difference in the final Slither verdict is attributable to
steering alone. The harness's own SlitherAnalyzer scores both (same verifier).

Run:
    python -m securegen.probe.ab_test --ids 0 16 32 48 64 75 91 107 123 139 \
        --threshold 0.5 --out securegen/results/ab_steering.json
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from ..analyzers import SlitherAnalyzer
from ..eval.runner import load_prompts
from ..types import count_loc
from .steered_decoder import SteeredDecoder


def _severity(f) -> str:
    return str(getattr(f, "impact", "") or "").lower()


def _score(code: str, analyzer) -> dict:
    a = analyzer.analyze(code)
    n = len(a.findings)
    high = sum(1 for f in a.findings if _severity(f) in ("high",))
    loc = count_loc(code)
    return {"compiled": a.compiled, "vulns": n if a.compiled else None,
            "high": high if a.compiled else None, "loc": loc,
            "density": (100.0 * n / loc) if (a.compiled and loc) else None}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", type=int, nargs="*",
                    default=[0, 16, 32, 48, 64, 75, 91, 107, 123, 139])
    ap.add_argument("--model", default="Qwen/Qwen2.5-Coder-7B-Instruct")
    ap.add_argument("--probe", default="securegen/probe/probe_l12.pt")
    ap.add_argument("--threshold", type=float, default=0.5)
    ap.add_argument("--check-every", type=int, default=16)
    ap.add_argument("--max-backtracks", type=int, default=8)
    ap.add_argument("--max-new-tokens", type=int, default=1200)
    ap.add_argument("--out", default="securegen/results/ab_steering.json")
    args = ap.parse_args()

    import torch

    dec = SteeredDecoder(
        model_id=args.model, probe_path=args.probe,
        risk_threshold=args.threshold, check_every=args.check_every,
        max_backtracks=args.max_backtracks, max_new_tokens=args.max_new_tokens)
    analyzer = SlitherAnalyzer()
    prompts = load_prompts(ids=args.ids)

    rows = []
    print(f"{'id':>4} {'cmp':>7} {'vulns':>11} {'density/100':>13} {'bt':>3}")
    for p in prompts:
        # OFF: identical seed, probe disabled (threshold > 1 never fires)
        torch.manual_seed(1000 + p.id)
        dec.risk_threshold = 2.0
        off_code, off_info = dec.generate(p.prompt)
        off = _score(off_code, analyzer)

        # ON: same seed, probe active
        torch.manual_seed(1000 + p.id)
        dec.risk_threshold = args.threshold
        on_code, on_info = dec.generate(p.prompt)
        on = _score(on_code, analyzer)

        rows.append({"id": p.id, "category": p.category, "prompt": p.prompt,
                     "off": off, "on": on,
                     "on_backtracks": on_info["backtracks"],
                     "on_risk_triggers": on_info["risk_triggers"],
                     "on_max_risk": on_info["max_risk"],
                     "off_code": off_code, "on_code": on_code})

        def fmt(s):
            return (f"{str(s['compiled'])[0]} v={s['vulns']} "
                    f"d={s['density']:.2f}" if s["compiled"]
                    else "NC        ")
        print(f"{p.id:>4}  OFF {fmt(off)}")
        print(f"{p.id:>4}  ON  {fmt(on)}  bt={on_info['backtracks']} "
              f"maxrisk={on_info['max_risk']:.2f}")

    Path(args.out).write_text(json.dumps(rows, indent=2))
    _summary(rows)
    print(f"\nSaved -> {args.out}")


def _summary(rows):
    def agg(side):
        comp = [r for r in rows if r[side]["compiled"]]
        cr = len(comp) / len(rows) if rows else 0
        vs = [r[side]["vulns"] for r in comp]
        ds = [r[side]["density"] for r in comp]
        hs = [r[side]["high"] for r in comp]
        mean = lambda x: sum(x) / len(x) if x else float("nan")
        return cr, mean(vs), mean(ds), sum(hs)
    ocr, ov, od, oh = agg("off")
    ncr, nv, nd, nh = agg("on")
    # paired: prompts where BOTH compiled
    both = [r for r in rows if r["off"]["compiled"] and r["on"]["compiled"]]
    dv = [r["on"]["vulns"] - r["off"]["vulns"] for r in both]
    print("\n=== SUMMARY (steering OFF -> ON) ===")
    print(f" compile rate : {ocr:.0%} -> {ncr:.0%}")
    print(f" mean vulns   : {ov:.2f} -> {nv:.2f}   (compiled only)")
    print(f" density/100  : {od:.2f} -> {nd:.2f}")
    print(f" high-sev tot : {oh} -> {nh}")
    print(f" paired (both compiled) n={len(both)}: "
          f"mean Δvulns = {(sum(dv)/len(dv)) if dv else float('nan'):+.2f}")
    tb = sum(r["on_backtracks"] for r in rows)
    print(f" total backtracks fired: {tb}")


if __name__ == "__main__":
    main()
