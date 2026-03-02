"""
Statistical analysis for the research paper.
Provides tests for significance and effect sizes.
"""

import json
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats
from scipy.stats import chi2_contingency, mannwhitneyu, kruskal


def run_statistical_tests(df: pd.DataFrame) -> dict:
    """
    Run all statistical tests for the paper.

    Args:
        df: Aggregated results dataframe

    Returns:
        Dictionary of test results
    """
    results = {}

    # 1. Chi-square test: Is vulnerability rate independent of LLM?
    print("\n1. Chi-Square Test: Vulnerability rate vs LLM")
    contingency = pd.crosstab(df['llm'], df['has_critical'])
    chi2, p_value, dof, expected = chi2_contingency(contingency)
    results['chi_square_llm'] = {
        'statistic': chi2,
        'p_value': p_value,
        'degrees_of_freedom': dof,
        'significant': p_value < 0.05
    }
    print(f"   Chi2 = {chi2:.4f}, p = {p_value:.6f}, significant = {p_value < 0.05}")

    # 2. Kruskal-Wallis: Do vulnerability counts differ across LLMs?
    print("\n2. Kruskal-Wallis Test: Vulnerability counts across LLMs")
    groups = [group['total_vulns'].values for name, group in df.groupby('llm')]
    if len(groups) >= 2:
        h_stat, p_value = kruskal(*groups)
        results['kruskal_wallis'] = {
            'statistic': h_stat,
            'p_value': p_value,
            'significant': p_value < 0.05
        }
        print(f"   H = {h_stat:.4f}, p = {p_value:.6f}, significant = {p_value < 0.05}")

    # 3. Mann-Whitney U: Standard vs Adversarial prompts
    print("\n3. Mann-Whitney U Test: Standard vs Adversarial prompts")
    standard = df[df['prompt_type'] == 'standard']['total_vulns']
    adversarial = df[df['prompt_type'] == 'adversarial']['total_vulns']

    if len(standard) > 0 and len(adversarial) > 0:
        u_stat, p_value = mannwhitneyu(standard, adversarial, alternative='less')

        # Effect size (Cohen's d approximation)
        pooled_std = np.sqrt((standard.std()**2 + adversarial.std()**2) / 2)
        effect_size = (adversarial.mean() - standard.mean()) / pooled_std if pooled_std > 0 else 0

        results['adversarial_effect'] = {
            'statistic': u_stat,
            'p_value': p_value,
            'significant': p_value < 0.05,
            'effect_size': effect_size,
            'standard_mean': standard.mean(),
            'adversarial_mean': adversarial.mean()
        }
        print(f"   U = {u_stat:.4f}, p = {p_value:.6f}")
        print(f"   Standard mean: {standard.mean():.2f}, Adversarial mean: {adversarial.mean():.2f}")
        print(f"   Effect size (Cohen's d): {effect_size:.3f}")

    # 4. Confidence intervals for each LLM
    print("\n4. 95% Confidence Intervals by LLM:")
    for llm in df['llm'].unique():
        llm_data = df[df['llm'] == llm]['total_vulns']
        if len(llm_data) > 1:
            mean = llm_data.mean()
            std_err = stats.sem(llm_data)
            ci = stats.t.interval(0.95, len(llm_data)-1, loc=mean, scale=std_err)

            results[f'ci_{llm}'] = {
                'mean': mean,
                'std': llm_data.std(),
                'ci_lower': ci[0],
                'ci_upper': ci[1],
                'n': len(llm_data)
            }
            print(f"   {llm}: {mean:.2f} [{ci[0]:.2f}, {ci[1]:.2f}]")

    return results


def compare_with_human_baseline(llm_df: pd.DataFrame, human_df: pd.DataFrame) -> dict:
    """
    Compare LLM-generated vs human-written contracts.

    Args:
        llm_df: DataFrame with LLM contract vulnerabilities
        human_df: DataFrame with human contract vulnerabilities

    Returns:
        Dictionary of comparison results
    """
    print("\n5. LLM vs Human Baseline Comparison")

    # Mann-Whitney U test
    u_stat, p_value = mannwhitneyu(
        llm_df['total_vulns'],
        human_df['total_vulns']
    )

    # Effect size (Cohen's d)
    pooled_std = np.sqrt(
        (llm_df['total_vulns'].std()**2 + human_df['total_vulns'].std()**2) / 2
    )
    effect_size = (llm_df['total_vulns'].mean() - human_df['total_vulns'].mean()) / pooled_std

    result = {
        'llm_mean': llm_df['total_vulns'].mean(),
        'llm_std': llm_df['total_vulns'].std(),
        'human_mean': human_df['total_vulns'].mean(),
        'human_std': human_df['total_vulns'].std(),
        'u_statistic': u_stat,
        'p_value': p_value,
        'cohens_d': effect_size,
        'significant': p_value < 0.05
    }

    print(f"   LLM mean: {result['llm_mean']:.2f} (std: {result['llm_std']:.2f})")
    print(f"   Human mean: {result['human_mean']:.2f} (std: {result['human_std']:.2f})")
    print(f"   U = {u_stat:.4f}, p = {p_value:.6f}")
    print(f"   Cohen's d = {effect_size:.3f}")

    return result


def generate_paper_statistics(csv_file: str = "analysis/aggregated_results.csv"):
    """
    Generate all statistics needed for the paper.

    Args:
        csv_file: Path to aggregated results CSV
    """
    print("=" * 60)
    print("STATISTICAL ANALYSIS FOR PAPER")
    print("=" * 60)

    df = pd.read_csv(csv_file)
    print(f"\nDataset size: {len(df)} contracts")

    # Run all tests
    results = run_statistical_tests(df)

    # Save results
    output_path = Path("analysis/statistical_results.json")
    with open(output_path, "w") as f:
        # Convert numpy types to Python types
        def convert(obj):
            if isinstance(obj, np.integer):
                return int(obj)
            elif isinstance(obj, np.floating):
                return float(obj)
            elif isinstance(obj, np.ndarray):
                return obj.tolist()
            return obj

        clean_results = json.loads(
            json.dumps(results, default=convert)
        )
        json.dump(clean_results, f, indent=2)

    print(f"\nStatistical results saved to: {output_path}")

    return results


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Run statistical analysis")
    parser.add_argument("--input", type=str, default="analysis/aggregated_results.csv")

    args = parser.parse_args()
    generate_paper_statistics(args.input)
