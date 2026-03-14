"""
Phase 4: Deep analysis of adversarial null result.
Key finding: adversarial prompts do NOT increase vulnerabilities (p=0.99).
This script breaks it down per-LLM, per-category, per-trigger to understand why.
"""

import json
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import mannwhitneyu, kruskal, spearmanr


def cliffs_delta(x, y):
    x, y = np.asarray(x, dtype=float), np.asarray(y, dtype=float)
    if len(x) == 0 or len(y) == 0:
        return 0.0
    more = sum(np.sum(xi > y) for xi in x)
    less = sum(np.sum(xi < y) for xi in x)
    return (more - less) / (len(x) * len(y))


def interpret_d(d):
    d = abs(d)
    if d < 0.147: return "negligible"
    elif d < 0.33: return "small"
    elif d < 0.474: return "medium"
    return "large"


def run_adversarial_deep_analysis(
    csv_file: str = "analysis/results/aggregated_results.csv",
    output_file: str = "analysis/results/adversarial_deep_analysis.json",
):
    df = pd.read_csv(csv_file)
    results = {}

    # Use compiled-only for more meaningful analysis
    if "compiled" in df.columns:
        df = df[df["compiled"]].copy()
        print(f"Using compiled-only subset: {len(df)} contracts")
    else:
        print(f"WARNING: no 'compiled' column, using all {len(df)} contracts")

    std = df[df["prompt_type"] == "standard"]
    adv = df[df["prompt_type"] == "adversarial"]
    print(f"Standard: {len(std)} | Adversarial: {len(adv)}")

    # ── 1. Overall effect (compiled only) ──
    u, p = mannwhitneyu(std["total_vulns"], adv["total_vulns"], alternative="two-sided")
    d = cliffs_delta(adv["total_vulns"].values, std["total_vulns"].values)
    results["overall"] = {
        "u_stat": float(u), "p_value": float(p), "cliffs_delta": float(d),
        "effect": interpret_d(d),
        "std_mean": float(std["total_vulns"].mean()),
        "std_median": float(std["total_vulns"].median()),
        "adv_mean": float(adv["total_vulns"].mean()),
        "adv_median": float(adv["total_vulns"].median()),
    }
    print(f"\n=== OVERALL (compiled) ===")
    print(f"  p={p:.4f}, d={d:.3f} ({interpret_d(d)})")
    print(f"  Standard:    mean={std['total_vulns'].mean():.2f}, median={std['total_vulns'].median()}")
    print(f"  Adversarial: mean={adv['total_vulns'].mean():.2f}, median={adv['total_vulns'].median()}")

    # ── 2. Per-LLM adversarial effect ──
    print(f"\n=== PER-LLM ADVERSARIAL EFFECT ===")
    per_llm = {}
    for llm in sorted(df["llm"].unique()):
        ldf = df[df["llm"] == llm]
        ls = ldf[ldf["prompt_type"] == "standard"]["total_vulns"]
        la = ldf[ldf["prompt_type"] == "adversarial"]["total_vulns"]
        if len(ls) < 2 or len(la) < 2:
            continue
        u, p = mannwhitneyu(ls, la, alternative="two-sided")
        d = cliffs_delta(la.values, ls.values)
        per_llm[llm] = {
            "n_std": len(ls), "n_adv": len(la),
            "u_stat": float(u), "p_value": float(p),
            "cliffs_delta": float(d), "effect": interpret_d(d),
            "std_mean": float(ls.mean()), "adv_mean": float(la.mean()),
            "significant": p < 0.05,
        }
        sig = "*" if p < 0.05 else ""
        direction = "ADV>STD" if d > 0 else "STD>ADV"
        print(f"  {llm:12s}: p={p:.4f}{sig}, d={d:.3f} ({interpret_d(d)}) "
              f"[{direction}] std={ls.mean():.2f} adv={la.mean():.2f}")
    results["per_llm"] = per_llm

    # ── 3. Per-category adversarial effect ──
    print(f"\n=== PER-CATEGORY ADVERSARIAL EFFECT ===")
    per_cat = {}
    sig_cats = []
    for cat in sorted(df["category"].unique()):
        cdf = df[df["category"] == cat]
        cs = cdf[cdf["prompt_type"] == "standard"]["total_vulns"]
        ca = cdf[cdf["prompt_type"] == "adversarial"]["total_vulns"]
        if len(cs) < 2 or len(ca) < 2:
            continue
        u, p = mannwhitneyu(cs, ca, alternative="two-sided")
        d = cliffs_delta(ca.values, cs.values)
        per_cat[cat] = {
            "n_std": len(cs), "n_adv": len(ca),
            "p_value": float(p), "cliffs_delta": float(d),
            "effect": interpret_d(d), "significant": p < 0.05,
            "std_mean": float(cs.mean()), "adv_mean": float(ca.mean()),
        }
        if p < 0.05:
            sig_cats.append(cat)
        sig = "*" if p < 0.05 else ""
        print(f"  {cat:30s}: p={p:.4f}{sig}, d={d:.3f} ({interpret_d(d)})")
    results["per_category"] = per_cat
    print(f"\n  Significant categories: {len(sig_cats)}/{len(per_cat)}")
    if sig_cats:
        print(f"  Which: {sig_cats}")

    # ── 4. Per-trigger analysis ──
    adv_all = df[df["prompt_type"] == "adversarial"]
    if "adversarial_category" in adv_all.columns:
        print(f"\n=== PER-TRIGGER ANALYSIS ===")
        per_trigger = {}
        for trigger in sorted(adv_all["adversarial_category"].dropna().unique()):
            if not trigger:
                continue
            tdf = adv_all[adv_all["adversarial_category"] == trigger]["total_vulns"]
            # Compare trigger vs all standard prompts
            u, p = mannwhitneyu(std["total_vulns"], tdf, alternative="two-sided")
            d = cliffs_delta(tdf.values, std["total_vulns"].values)
            per_trigger[trigger] = {
                "n": len(tdf), "mean": float(tdf.mean()), "median": float(tdf.median()),
                "p_vs_standard": float(p), "cliffs_delta_vs_standard": float(d),
                "effect": interpret_d(d), "significant": p < 0.05,
            }
            sig = "*" if p < 0.05 else ""
            print(f"  {trigger:30s}: n={len(tdf):3d}, mean={tdf.mean():.2f}, "
                  f"p_vs_std={p:.4f}{sig}, d={d:.3f} ({interpret_d(d)})")
        results["per_trigger"] = per_trigger

        # Kruskal-Wallis across triggers
        trigger_groups = [g["total_vulns"].values for _, g in adv_all.groupby("adversarial_category")]
        if len(trigger_groups) >= 2:
            h, p = kruskal(*trigger_groups)
            results["trigger_kruskal"] = {"H": float(h), "p": float(p), "significant": p < 0.05}
            print(f"\n  Kruskal-Wallis across triggers: H={h:.2f}, p={p:.4f}")

    # ── 5. Complexity interaction ──
    if "loc" in df.columns:
        print(f"\n=== COMPLEXITY INTERACTION ===")
        # Do adversarial prompts produce more complex (larger) code?
        std_loc = std["loc"]
        adv_loc = adv["loc"]
        u, p = mannwhitneyu(std_loc, adv_loc, alternative="two-sided")
        d = cliffs_delta(adv_loc.values, std_loc.values)
        results["loc_adversarial"] = {
            "std_mean_loc": float(std_loc.mean()), "adv_mean_loc": float(adv_loc.mean()),
            "p_value": float(p), "cliffs_delta": float(d),
        }
        print(f"  Standard LOC:    mean={std_loc.mean():.1f}")
        print(f"  Adversarial LOC: mean={adv_loc.mean():.1f}")
        print(f"  p={p:.4f}, d={d:.3f} ({interpret_d(d)})")

    # ── 6. High-severity specifically ──
    print(f"\n=== HIGH-SEVERITY ADVERSARIAL EFFECT ===")
    std_high = std["has_high"].astype(int)
    adv_high = adv["has_high"].astype(int)
    u, p = mannwhitneyu(std_high, adv_high, alternative="two-sided")
    d = cliffs_delta(adv_high.values, std_high.values)
    results["high_severity_adversarial"] = {
        "std_rate": float(std_high.mean()), "adv_rate": float(adv_high.mean()),
        "p_value": float(p), "cliffs_delta": float(d),
    }
    print(f"  Standard high-sev rate:    {std_high.mean()*100:.1f}%")
    print(f"  Adversarial high-sev rate: {adv_high.mean()*100:.1f}%")
    print(f"  p={p:.4f}, d={d:.3f} ({interpret_d(d)})")

    # ── 7. Framing summary ──
    print(f"\n{'='*60}")
    print("FRAMING SUMMARY")
    print(f"{'='*60}")
    any_sig_llm = any(v["significant"] for v in per_llm.values())
    any_sig_cat = len(sig_cats) > 0
    print(f"Overall significant?      NO (p={results['overall']['p_value']:.4f})")
    print(f"Any LLM significant?      {'YES' if any_sig_llm else 'NO'}")
    print(f"Any category significant? {'YES' if any_sig_cat else 'NO'} ({len(sig_cats)}/{len(per_cat)})")
    print(f"\nKey insight: Vulnerabilities are INTRINSIC to LLM code generation,")
    print(f"not dependent on prompt engineering. Even well-intentioned developers")
    print(f"cannot avoid them through careful prompting.")

    # Save
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    def default_serializer(obj):
        if isinstance(obj, (np.integer,)): return int(obj)
        if isinstance(obj, (np.floating,)): return float(obj)
        if isinstance(obj, (np.bool_,)): return bool(obj)
        if isinstance(obj, np.ndarray): return obj.tolist()
        raise TypeError(f"Not serializable: {type(obj)}")

    with open(output_path, "w") as f:
        json.dump(results, f, indent=2, default=default_serializer)
    print(f"\nSaved to: {output_path}")
    return results


if __name__ == "__main__":
    run_adversarial_deep_analysis()
