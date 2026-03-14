"""
Statistical analysis for the research paper.
Uses non-parametric tests throughout (Kruskal-Wallis, Mann-Whitney U)
with Cliff's delta for effect sizes (appropriate for ordinal/non-normal data).
"""

import json
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats
from scipy.stats import chi2_contingency, mannwhitneyu, kruskal


def cliffs_delta(x, y):
    """
    Compute Cliff's delta effect size (non-parametric).

    Cliff's delta ranges from -1 to +1:
      |d| < 0.147 → negligible
      |d| < 0.33  → small
      |d| < 0.474 → medium
      |d| >= 0.474 → large

    Reference: Romano et al. (2006)
    """
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    nx, ny = len(x), len(y)
    if nx == 0 or ny == 0:
        return 0.0

    # Count dominance pairs
    more = 0
    less = 0
    for xi in x:
        more += np.sum(xi > y)
        less += np.sum(xi < y)

    delta = (more - less) / (nx * ny)
    return delta


def interpret_cliffs_delta(d):
    """Interpret Cliff's delta magnitude."""
    d = abs(d)
    if d < 0.147:
        return "negligible"
    elif d < 0.33:
        return "small"
    elif d < 0.474:
        return "medium"
    else:
        return "large"


def pairwise_mannwhitney(df, group_col, value_col, alpha=0.05):
    """
    Pairwise Mann-Whitney U tests with Bonferroni correction.

    Returns list of pairwise comparison results.
    """
    groups = sorted(df[group_col].unique())
    n_comparisons = len(groups) * (len(groups) - 1) // 2
    results = []

    for i in range(len(groups)):
        for j in range(i + 1, len(groups)):
            g1 = df[df[group_col] == groups[i]][value_col].values
            g2 = df[df[group_col] == groups[j]][value_col].values

            if len(g1) < 2 or len(g2) < 2:
                continue

            u_stat, p_value = mannwhitneyu(g1, g2, alternative='two-sided')
            delta = cliffs_delta(g1, g2)
            corrected_p = min(p_value * n_comparisons, 1.0)  # Bonferroni

            results.append({
                "group1": groups[i],
                "group2": groups[j],
                "u_statistic": float(u_stat),
                "p_value": float(p_value),
                "p_corrected": float(corrected_p),
                "significant": corrected_p < alpha,
                "cliffs_delta": float(delta),
                "effect_interpretation": interpret_cliffs_delta(delta),
                "group1_median": float(np.median(g1)),
                "group2_median": float(np.median(g2)),
            })

    return results


def run_compiled_only_tests(df: pd.DataFrame) -> dict:
    """Run key tests on compiled-only subset with LOC normalization."""
    if "compiled" not in df.columns:
        print("WARNING: 'compiled' column not found. Run add_compilation_status.py first.")
        return {}

    cdf = df[df["compiled"]].copy()
    results = {}

    print(f"\n{'='*60}")
    print(f"COMPILED-ONLY ANALYSIS ({len(cdf)} contracts)")
    print(f"{'='*60}")

    # Compilation rates per LLM
    comp_rates = {}
    for llm in sorted(df["llm"].unique()):
        total = len(df[df["llm"] == llm])
        compiled = len(cdf[cdf["llm"] == llm])
        rate = compiled / total if total > 0 else 0
        comp_rates[llm] = {"compiled": compiled, "total": total, "rate": round(rate, 4)}
        print(f"  {llm:12s}: {compiled}/{total} ({rate*100:.1f}%)")
    results["compilation_rates"] = comp_rates

    # Kruskal-Wallis on compiled-only total_vulns
    groups = [g["total_vulns"].values for _, g in cdf.groupby("llm")]
    if len(groups) >= 2:
        h, p = kruskal(*groups)
        results["kruskal_wallis_compiled"] = {
            "statistic": float(h), "p_value": float(p), "significant": p < 0.05,
            "n": len(cdf),
        }
        print(f"\nKruskal-Wallis (compiled, total_vulns): H={h:.2f}, p={p:.2e}")

    # LOC-normalized: Kruskal-Wallis on vulns_per_100_loc
    if "vulns_per_100_loc" in cdf.columns:
        loc_groups = [g["vulns_per_100_loc"].values for _, g in cdf.groupby("llm")]
        if len(loc_groups) >= 2:
            h, p = kruskal(*loc_groups)
            results["kruskal_wallis_loc_normalized"] = {
                "statistic": float(h), "p_value": float(p), "significant": p < 0.05,
            }
            print(f"Kruskal-Wallis (compiled, vulns/100LOC): H={h:.2f}, p={p:.2e}")

        # Per-LLM LOC-normalized stats
        print("\nPer-LLM LOC-normalized (compiled only):")
        loc_stats = {}
        for llm in sorted(cdf["llm"].unique()):
            vals = cdf[cdf["llm"] == llm]["vulns_per_100_loc"]
            loc_stats[llm] = {
                "mean": round(float(vals.mean()), 3),
                "median": round(float(vals.median()), 3),
                "std": round(float(vals.std()), 3),
                "n": len(vals),
            }
            print(f"  {llm:12s}: mean={vals.mean():.2f}, median={vals.median():.2f}")
        results["loc_normalized_per_llm"] = loc_stats

    # Spearman: LOC vs total_vulns
    if "loc" in cdf.columns:
        from scipy.stats import spearmanr
        rho, p = spearmanr(cdf["loc"], cdf["total_vulns"])
        results["spearman_loc_vs_vulns"] = {
            "rho": round(float(rho), 4), "p_value": float(p), "significant": p < 0.05,
        }
        print(f"\nSpearman LOC vs vulns: rho={rho:.3f}, p={p:.2e}")

    # Pairwise on compiled-only
    pairwise = pairwise_mannwhitney(cdf, "llm", "total_vulns")
    results["pairwise_compiled"] = pairwise

    # Adversarial on compiled-only
    std = cdf[cdf["prompt_type"] == "standard"]["total_vulns"]
    adv = cdf[cdf["prompt_type"] == "adversarial"]["total_vulns"]
    if len(std) > 0 and len(adv) > 0:
        u, p = mannwhitneyu(std, adv, alternative="less")
        d = cliffs_delta(adv.values, std.values)
        results["adversarial_compiled"] = {
            "u_statistic": float(u), "p_value": float(p), "significant": p < 0.05,
            "cliffs_delta": float(d), "effect_interpretation": interpret_cliffs_delta(d),
            "standard_mean": float(std.mean()), "adversarial_mean": float(adv.mean()),
        }
        print(f"\nAdversarial (compiled): U={u:.1f}, p={p:.4f}, d={d:.3f}")

    return results


def run_statistical_tests(df: pd.DataFrame) -> dict:
    """
    Run all statistical tests for the paper.

    Args:
        df: Aggregated results dataframe (from aggregate_results.py)

    Returns:
        Dictionary of test results
    """
    results = {}

    # ── RQ1: Do vulnerability rates differ across LLMs? ──────────────────

    # 1a. Chi-square: Is high-severity vulnerability rate independent of LLM?
    print("\n1a. Chi-Square Test: High-severity rate vs LLM")
    contingency = pd.crosstab(df['llm'], df['has_high'])
    chi2, p_value, dof, expected = chi2_contingency(contingency)
    results['chi_square_high_severity'] = {
        'statistic': float(chi2),
        'p_value': float(p_value),
        'degrees_of_freedom': int(dof),
        'significant': p_value < 0.05,
    }
    print(f"   Chi2 = {chi2:.4f}, p = {p_value:.6f}, sig = {p_value < 0.05}")

    # 1b. Kruskal-Wallis: Do vuln counts differ across LLMs?
    print("\n1b. Kruskal-Wallis Test: Vulnerability counts across LLMs")
    groups = [group['total_vulns'].values for _, group in df.groupby('llm')]
    if len(groups) >= 2:
        h_stat, p_value = kruskal(*groups)
        # Effect size: epsilon-squared = H / (n-1)
        n = len(df)
        epsilon_sq = float(h_stat) / (n - 1) if n > 1 else 0
        results['kruskal_wallis_llm'] = {
            'statistic': float(h_stat),
            'p_value': float(p_value),
            'significant': p_value < 0.05,
            'epsilon_squared': epsilon_sq,
            'n_groups': len(groups),
        }
        print(f"   H = {h_stat:.4f}, p = {p_value:.6f}, epsilon^2 = {epsilon_sq:.4f}")

    # 1c. Pairwise Mann-Whitney with Bonferroni correction
    print("\n1c. Pairwise Mann-Whitney U (Bonferroni corrected):")
    pairwise = pairwise_mannwhitney(df, 'llm', 'total_vulns')
    results['pairwise_llm'] = pairwise
    for pw in pairwise:
        sig_marker = "*" if pw['significant'] else ""
        print(f"   {pw['group1']:12s} vs {pw['group2']:12s}: "
              f"p_corr={pw['p_corrected']:.4f}{sig_marker}, "
              f"Cliff's d={pw['cliffs_delta']:.3f} ({pw['effect_interpretation']})")

    # ── RQ2: Do adversarial prompts increase vulnerabilities? ─────────────

    print("\n2. Mann-Whitney U Test: Standard vs Adversarial prompts")
    standard = df[df['prompt_type'] == 'standard']['total_vulns']
    adversarial = df[df['prompt_type'] == 'adversarial']['total_vulns']

    if len(standard) > 0 and len(adversarial) > 0:
        u_stat, p_value = mannwhitneyu(standard, adversarial, alternative='less')
        delta = cliffs_delta(adversarial.values, standard.values)

        results['adversarial_effect'] = {
            'u_statistic': float(u_stat),
            'p_value': float(p_value),
            'significant': p_value < 0.05,
            'cliffs_delta': float(delta),
            'effect_interpretation': interpret_cliffs_delta(delta),
            'standard_median': float(standard.median()),
            'standard_mean': float(standard.mean()),
            'adversarial_median': float(adversarial.median()),
            'adversarial_mean': float(adversarial.mean()),
        }
        print(f"   U = {u_stat:.4f}, p = {p_value:.6f}")
        print(f"   Standard:    median={standard.median():.1f}, mean={standard.mean():.2f}")
        print(f"   Adversarial: median={adversarial.median():.1f}, mean={adversarial.mean():.2f}")
        print(f"   Cliff's delta = {delta:.3f} ({interpret_cliffs_delta(delta)})")

    # 2b. Per-LLM adversarial effect
    print("\n2b. Adversarial effect per LLM:")
    per_llm_adv = {}
    for llm in sorted(df['llm'].unique()):
        llm_df = df[df['llm'] == llm]
        std = llm_df[llm_df['prompt_type'] == 'standard']['total_vulns']
        adv = llm_df[llm_df['prompt_type'] == 'adversarial']['total_vulns']
        if len(std) > 0 and len(adv) > 0:
            u, p = mannwhitneyu(std, adv, alternative='less')
            d = cliffs_delta(adv.values, std.values)
            per_llm_adv[llm] = {
                'u_statistic': float(u),
                'p_value': float(p),
                'significant': p < 0.05,
                'cliffs_delta': float(d),
                'effect_interpretation': interpret_cliffs_delta(d),
            }
            sig = "*" if p < 0.05 else ""
            print(f"   {llm:12s}: p={p:.4f}{sig}, d={d:.3f} ({interpret_cliffs_delta(d)})")
    results['adversarial_per_llm'] = per_llm_adv

    # ── RQ3: Which vulnerability categories are most common? ──────────────

    print("\n3. Kruskal-Wallis: Vulnerability counts across categories")
    cat_groups = [group['total_vulns'].values for _, group in df.groupby('category')]
    if len(cat_groups) >= 2:
        h_stat, p_value = kruskal(*cat_groups)
        results['kruskal_wallis_category'] = {
            'statistic': float(h_stat),
            'p_value': float(p_value),
            'significant': p_value < 0.05,
        }
        print(f"   H = {h_stat:.4f}, p = {p_value:.6f}")

    # ── RQ4: Adversarial trigger effectiveness ────────────────────────────

    adv_df = df[df['prompt_type'] == 'adversarial']
    if 'adversarial_category' in adv_df.columns and not adv_df.empty:
        print("\n4. Kruskal-Wallis: Adversarial trigger category effectiveness")
        adv_cats = adv_df['adversarial_category'].dropna()
        if adv_cats.nunique() >= 2:
            trigger_groups = [
                group['total_vulns'].values
                for _, group in adv_df.groupby('adversarial_category')
            ]
            h_stat, p_value = kruskal(*trigger_groups)
            results['kruskal_wallis_trigger'] = {
                'statistic': float(h_stat),
                'p_value': float(p_value),
                'significant': p_value < 0.05,
            }
            print(f"   H = {h_stat:.4f}, p = {p_value:.6f}")

            # Trigger category rankings
            trigger_stats = adv_df.groupby('adversarial_category')['total_vulns'].agg(
                ['median', 'mean', 'std', 'count']
            ).sort_values('median', ascending=False)
            results['trigger_rankings'] = trigger_stats.to_dict('index')
            print("\n   Trigger category rankings (by median):")
            for cat, row in trigger_stats.iterrows():
                print(f"   {cat:30s}: median={row['median']:.1f}, "
                      f"mean={row['mean']:.2f}, n={int(row['count'])}")

    # ── Confidence intervals (bootstrap) ──────────────────────────────────

    print("\n5. 95% Confidence Intervals by LLM (bootstrap):")
    ci_results = {}
    for llm in sorted(df['llm'].unique()):
        llm_data = df[df['llm'] == llm]['total_vulns'].values
        if len(llm_data) > 1:
            # Bootstrap CI for median
            n_boot = 10000
            rng = np.random.default_rng(42)
            boot_medians = [
                np.median(rng.choice(llm_data, size=len(llm_data), replace=True))
                for _ in range(n_boot)
            ]
            ci_lower = float(np.percentile(boot_medians, 2.5))
            ci_upper = float(np.percentile(boot_medians, 97.5))

            ci_results[llm] = {
                'median': float(np.median(llm_data)),
                'mean': float(np.mean(llm_data)),
                'std': float(np.std(llm_data)),
                'ci_lower': ci_lower,
                'ci_upper': ci_upper,
                'n': len(llm_data),
            }
            print(f"   {llm:12s}: median={np.median(llm_data):.1f} "
                  f"[{ci_lower:.2f}, {ci_upper:.2f}], n={len(llm_data)}")
    results['confidence_intervals'] = ci_results

    # ── Tool agreement analysis ───────────────────────────────────────────

    print("\n6. Cross-tool agreement:")
    if all(c in df.columns for c in ['slither_count', 'mythril_count', 'semgrep_count']):
        tool_cols = ['slither_count', 'mythril_count', 'semgrep_count']
        tool_corr = df[tool_cols].corr(method='spearman')
        results['tool_correlation_spearman'] = tool_corr.to_dict()
        print(f"   Spearman correlations:")
        print(f"   Slither-Mythril: {tool_corr.loc['slither_count', 'mythril_count']:.3f}")
        print(f"   Slither-Semgrep: {tool_corr.loc['slither_count', 'semgrep_count']:.3f}")
        print(f"   Mythril-Semgrep: {tool_corr.loc['mythril_count', 'semgrep_count']:.3f}")

    return results


def generate_paper_statistics(
    csv_file: str = "analysis/results/aggregated_results.csv",
    output_file: str = "analysis/results/statistical_results.json",
):
    """Generate all statistics needed for the paper."""
    print("=" * 60)
    print("STATISTICAL ANALYSIS FOR PAPER")
    print("=" * 60)

    df = pd.read_csv(csv_file)
    print(f"\nDataset size: {len(df)} contracts")
    print(f"LLMs: {sorted(df['llm'].unique())}")
    print(f"Prompt types: {sorted(df['prompt_type'].unique())}")

    results = run_statistical_tests(df)

    # Compiled-only analysis (Phase 1)
    compiled_results = run_compiled_only_tests(df)
    if compiled_results:
        results["compiled_only"] = compiled_results

    # Save results
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    def convert(obj):
        if isinstance(obj, (np.integer, np.int64)):
            return int(obj)
        elif isinstance(obj, (np.floating, np.float64)):
            return float(obj)
        elif isinstance(obj, np.ndarray):
            return obj.tolist()
        elif isinstance(obj, np.bool_):
            return bool(obj)
        return obj

    clean = json.loads(json.dumps(results, default=convert))
    with open(output_path, "w") as f:
        json.dump(clean, f, indent=2)

    print(f"\nStatistical results saved to: {output_path}")
    return results


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Run statistical analysis")
    parser.add_argument("--input", type=str, default="analysis/results/aggregated_results.csv")
    parser.add_argument("--output", type=str, default="analysis/results/statistical_results.json")
    args = parser.parse_args()

    generate_paper_statistics(args.input, args.output)
