"""
Generate paper-ready figures for the research.
"""

import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns

# Set style for publication
plt.style.use('seaborn-v0_8-whitegrid')
plt.rcParams['figure.figsize'] = (10, 6)
plt.rcParams['font.size'] = 12
plt.rcParams['axes.labelsize'] = 14
plt.rcParams['axes.titlesize'] = 16
plt.rcParams['legend.fontsize'] = 11


def load_data(csv_path: str = "analysis/aggregated_results.csv") -> pd.DataFrame:
    """Load aggregated results."""
    return pd.read_csv(csv_path)


def fig1_vulnerabilities_by_llm(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """
    Figure 1: Bar chart of vulnerabilities by LLM.
    """
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))

    # Left: Total vulnerabilities
    llm_totals = df.groupby('llm')['total_vulns'].mean().sort_values(ascending=False)

    ax1 = axes[0]
    bars = ax1.bar(llm_totals.index, llm_totals.values, color='steelblue', edgecolor='black')
    ax1.set_xlabel('LLM')
    ax1.set_ylabel('Average Vulnerabilities per Contract')
    ax1.set_title('(a) Average Vulnerabilities by LLM')
    ax1.tick_params(axis='x', rotation=45)

    # Add value labels
    for bar, val in zip(bars, llm_totals.values):
        ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.1,
                f'{val:.1f}', ha='center', va='bottom', fontsize=10)

    # Right: High severity only
    llm_high = df.groupby('llm')['total_high'].mean().sort_values(ascending=False)

    ax2 = axes[1]
    bars = ax2.bar(llm_high.index, llm_high.values, color='firebrick', edgecolor='black')
    ax2.set_xlabel('LLM')
    ax2.set_ylabel('Average High-Severity Vulnerabilities')
    ax2.set_title('(b) Average High-Severity Vulnerabilities by LLM')
    ax2.tick_params(axis='x', rotation=45)

    for bar, val in zip(bars, llm_high.values):
        ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.05,
                f'{val:.2f}', ha='center', va='bottom', fontsize=10)

    plt.tight_layout()

    output_path = Path(output_dir) / "fig1_vulnerabilities_by_llm.pdf"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    plt.savefig(output_path.with_suffix('.png'), dpi=300, bbox_inches='tight')
    plt.close()

    print(f"Saved: {output_path}")


def fig2_standard_vs_adversarial(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """
    Figure 2: Comparison of standard vs adversarial prompts.
    """
    fig, ax = plt.subplots(figsize=(10, 6))

    # Prepare data
    prompt_llm = df.groupby(['llm', 'prompt_type'])['total_vulns'].mean().unstack()

    x = np.arange(len(prompt_llm.index))
    width = 0.35

    bars1 = ax.bar(x - width/2, prompt_llm['standard'], width, label='Standard Prompts',
                   color='steelblue', edgecolor='black')
    bars2 = ax.bar(x + width/2, prompt_llm['adversarial'], width, label='Adversarial Prompts',
                   color='firebrick', edgecolor='black')

    ax.set_xlabel('LLM')
    ax.set_ylabel('Average Vulnerabilities per Contract')
    ax.set_title('Standard vs Adversarial Prompts by LLM')
    ax.set_xticks(x)
    ax.set_xticklabels(prompt_llm.index, rotation=45)
    ax.legend()

    # Add value labels
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2, height + 0.1,
                   f'{height:.1f}', ha='center', va='bottom', fontsize=9)

    plt.tight_layout()

    output_path = Path(output_dir) / "fig2_standard_vs_adversarial.pdf"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    plt.savefig(output_path.with_suffix('.png'), dpi=300, bbox_inches='tight')
    plt.close()

    print(f"Saved: {output_path}")


def fig3_vulnerabilities_by_category(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """
    Figure 3: Heatmap of vulnerabilities by category and LLM.
    """
    fig, ax = plt.subplots(figsize=(14, 10))

    # Pivot for heatmap
    pivot = df.groupby(['category', 'llm'])['total_vulns'].mean().unstack()

    sns.heatmap(pivot, annot=True, fmt='.1f', cmap='YlOrRd', ax=ax,
                linewidths=0.5, cbar_kws={'label': 'Avg. Vulnerabilities'})

    ax.set_xlabel('LLM')
    ax.set_ylabel('Contract Category')
    ax.set_title('Vulnerability Density by Contract Category and LLM')

    plt.tight_layout()

    output_path = Path(output_dir) / "fig3_vulnerabilities_by_category.pdf"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    plt.savefig(output_path.with_suffix('.png'), dpi=300, bbox_inches='tight')
    plt.close()

    print(f"Saved: {output_path}")


def fig4_severity_distribution(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """
    Figure 4: Stacked bar chart of severity distribution.
    """
    fig, ax = plt.subplots(figsize=(12, 6))

    # Aggregate by LLM
    severity_data = df.groupby('llm').agg({
        'slither_high': 'sum',
        'slither_medium': 'sum',
        'slither_low': 'sum',
        'slither_info': 'sum'
    })

    severity_data.columns = ['High', 'Medium', 'Low', 'Informational']

    # Normalize to percentages
    severity_pct = severity_data.div(severity_data.sum(axis=1), axis=0) * 100

    # Stacked bar
    severity_pct.plot(kind='bar', stacked=True, ax=ax,
                      color=['firebrick', 'darkorange', 'gold', 'steelblue'],
                      edgecolor='black')

    ax.set_xlabel('LLM')
    ax.set_ylabel('Percentage of Vulnerabilities')
    ax.set_title('Vulnerability Severity Distribution by LLM')
    ax.legend(title='Severity', bbox_to_anchor=(1.02, 1), loc='upper left')
    ax.set_xticklabels(ax.get_xticklabels(), rotation=45)

    plt.tight_layout()

    output_path = Path(output_dir) / "fig4_severity_distribution.pdf"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    plt.savefig(output_path.with_suffix('.png'), dpi=300, bbox_inches='tight')
    plt.close()

    print(f"Saved: {output_path}")


def fig5_adversarial_trigger_effectiveness(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """
    Figure 5: Box plot of vulnerability counts by adversarial trigger type.
    """
    # Filter adversarial only
    adv_df = df[df['prompt_type'] == 'adversarial'].copy()

    if adv_df.empty or 'trigger' not in adv_df.columns:
        print("No adversarial data with triggers available")
        return

    fig, ax = plt.subplots(figsize=(14, 6))

    # Order by mean vulnerability count
    trigger_order = adv_df.groupby('trigger')['total_vulns'].mean().sort_values(ascending=False).index

    sns.boxplot(data=adv_df, x='trigger', y='total_vulns', order=trigger_order, ax=ax,
                palette='YlOrRd')

    ax.set_xlabel('Adversarial Trigger')
    ax.set_ylabel('Total Vulnerabilities')
    ax.set_title('Vulnerability Induction by Adversarial Trigger Type')
    ax.tick_params(axis='x', rotation=90)

    plt.tight_layout()

    output_path = Path(output_dir) / "fig5_adversarial_triggers.pdf"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    plt.savefig(output_path.with_suffix('.png'), dpi=300, bbox_inches='tight')
    plt.close()

    print(f"Saved: {output_path}")


def generate_all_figures(csv_path: str = "analysis/aggregated_results.csv",
                         output_dir: str = "visualization/figures"):
    """Generate all figures for the paper."""
    print("=" * 60)
    print("GENERATING PAPER FIGURES")
    print("=" * 60)

    df = load_data(csv_path)
    print(f"Loaded {len(df)} records")

    fig1_vulnerabilities_by_llm(df, output_dir)
    fig2_standard_vs_adversarial(df, output_dir)
    fig3_vulnerabilities_by_category(df, output_dir)
    fig4_severity_distribution(df, output_dir)
    fig5_adversarial_trigger_effectiveness(df, output_dir)

    print(f"\nAll figures saved to: {output_dir}/")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Generate paper figures")
    parser.add_argument("--input", type=str, default="analysis/aggregated_results.csv")
    parser.add_argument("--output", type=str, default="visualization/figures")

    args = parser.parse_args()
    generate_all_figures(args.input, args.output)
