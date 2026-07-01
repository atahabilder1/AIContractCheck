"""
Compare strategies head-to-head. This is the file that answers the user's
question: "which works, and what's most novel?"

Produces, per strategy:
  * compile rate
  * mean vulns / mean high-sev (compiled only)
  * mean density per 100 LOC
  * mean token cost and wall time  (the price of the intervention)
  * PAIRED delta vs the baseline on shared prompt ids, with Wilcoxon signed-rank
    p-value and Cliff's delta effect size (same stats the paper already uses).

Run:
    python -m securegen.eval.compare \
        securegen/results/s0_baseline__gpt4o.json \
        securegen/results/s2_repair_loop__gpt4o.json
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import mean


def _load(path: str) -> dict[int, dict]:
    return {r["prompt_id"]: r for r in json.loads(Path(path).read_text())}


def _summ(records: list[dict]) -> dict:
    comp = [r for r in records if r.get("compiled")]
    def avg(key, src=comp):
        vals = [r[key] for r in src if r.get(key) is not None]
        return mean(vals) if vals else None
    return {
        "n": len(records),
        "compile_rate": (len(comp) / len(records)) if records else 0,
        "mean_vulns": avg("total_vulns"),
        "mean_high": avg("high"),
        "mean_density": avg("density_per_100loc"),
        "mean_out_tokens": mean([r["usage"]["output_tokens"] for r in records]) if records else 0,
        "mean_iters": mean([r["iterations"] for r in records]) if records else 0,
        "mean_wall_s": mean([r.get("wall_time_s", 0) for r in records]) if records else 0,
    }


def cliffs_delta(a: list[float], b: list[float]) -> float:
    """Non-parametric effect size in [-1,1]. >0 means a > b."""
    if not a or not b:
        return float("nan")
    gt = lt = 0
    for x in a:
        for y in b:
            if x > y:
                gt += 1
            elif x < y:
                lt += 1
    return (gt - lt) / (len(a) * len(b))


def wilcoxon_p(diffs: list[float]) -> float:
    """Two-sided Wilcoxon signed-rank p-value; falls back to nan if scipy absent."""
    nz = [d for d in diffs if d != 0]
    if len(nz) < 6:
        return float("nan")
    try:
        from scipy.stats import wilcoxon
        return float(wilcoxon(nz).pvalue)
    except Exception:
        return float("nan")


def compare(baseline_path: str, *other_paths: str) -> dict:
    base = _load(baseline_path)
    report = {"baseline": Path(baseline_path).stem, "strategies": {}}
    report["strategies"][Path(baseline_path).stem] = _summ(list(base.values()))

    for path in other_paths:
        other = _load(path)
        report["strategies"][Path(path).stem] = _summ(list(other.values()))

        # paired analysis on shared compiled prompts
        shared = [pid for pid in base if pid in other]
        base_v, other_v, diffs = [], [], []
        for pid in shared:
            b, o = base[pid], other[pid]
            if b.get("compiled") and o.get("compiled"):
                bv = b["total_vulns"] or 0
                ov = o["total_vulns"] or 0
                base_v.append(bv)
                other_v.append(ov)
                diffs.append(ov - bv)
        report["strategies"][Path(path).stem]["paired_vs_baseline"] = {
            "n_pairs": len(diffs),
            "mean_vuln_delta": mean(diffs) if diffs else None,
            "wilcoxon_p": wilcoxon_p(diffs),
            "cliffs_delta": cliffs_delta(other_v, base_v),
        }
    return report


def print_report(report: dict) -> None:
    print(f"\nBaseline: {report['baseline']}")
    hdr = f"{'strategy':<34}{'comp%':>7}{'vulns':>7}{'high':>6}{'dens':>7}{'tok':>8}{'iters':>6}{'sec':>7}"
    print(hdr)
    print("-" * len(hdr))
    for name, s in report["strategies"].items():
        print(f"{name:<34}{s['compile_rate']*100:>6.1f}%"
              f"{_f(s['mean_vulns']):>7}{_f(s['mean_high']):>6}"
              f"{_f(s['mean_density']):>7}{s['mean_out_tokens']:>8.0f}"
              f"{s['mean_iters']:>6.1f}{s['mean_wall_s']:>7.1f}")
        pv = s.get("paired_vs_baseline")
        if pv:
            print(f"    vs baseline: Δvulns={_f(pv['mean_vuln_delta'])} "
                  f"p={_f(pv['wilcoxon_p'])} δ={_f(pv['cliffs_delta'])} "
                  f"(n={pv['n_pairs']})")


def _f(x):
    return f"{x:.2f}" if isinstance(x, float) else ("—" if x is None else str(x))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("baseline")
    ap.add_argument("others", nargs="*")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    rep = compare(args.baseline, *args.others)
    if args.json:
        print(json.dumps(rep, indent=2))
    else:
        print_report(rep)
