"""
Generate paper-ready figures for the research.
Column names match aggregate_results.py output.
"""

import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')  # Non-interactive backend for server

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns

# IEEE-style publication settings
plt.style.use('seaborn-v0_8-whitegrid')
plt.rcParams.update({
    'figure.figsize': (10, 6),
    'font.size': 11,
    'font.family': 'serif',
    'axes.labelsize': 13,
    'axes.titlesize': 14,
    'legend.fontsize': 10,
    'xtick.labelsize': 10,
    'ytick.labelsize': 10,
    'figure.dpi': 150,
})

# Consistent color palette for LLMs
LLM_COLORS = {
    'claude': '#6B4C9A',
    'gpt4o': '#2E86AB',
    'gemini': '#E8702A',
    'codellama': '#A23B72',
    'deepseek': '#2CA58D',
    'qwen': '#C17817',
}


def get_color(llm):
    return LLM_COLORS.get(llm, '#666666')


def load_data(csv_path: str = "analysis/results/aggregated_results.csv") -> pd.DataFrame:
    """Load aggregated results."""
    return pd.read_csv(csv_path)


def fig1_vulnerabilities_by_llm(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """Figure 1: Violin + strip plot of vulnerabilities by LLM."""
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))

    llm_order = df.groupby('llm')['total_vulns'].median().sort_values(ascending=False).index.tolist()
    colors = [get_color(llm) for llm in llm_order]

    # Left: Total vulnerabilities (violin)
    ax1 = axes[0]
    sns.violinplot(data=df, x='llm', y='total_vulns', order=llm_order,
                   palette=colors, inner='quartile', ax=ax1, cut=0)
    sns.stripplot(data=df, x='llm', y='total_vulns', order=llm_order,
                  color='black', alpha=0.15, size=2, jitter=True, ax=ax1)
    ax1.set_xlabel('LLM')
    ax1.set_ylabel('Total Vulnerabilities per Contract')
    ax1.set_title('(a) Vulnerability Distribution by LLM')
    ax1.tick_params(axis='x', rotation=45)

    # Right: High severity rate (bar)
    ax2 = axes[1]
    high_rate = df.groupby('llm')['has_high'].mean().reindex(llm_order) * 100
    bars = ax2.bar(llm_order, high_rate.values, color=colors, edgecolor='black', linewidth=0.5)
    ax2.set_xlabel('LLM')
    ax2.set_ylabel('% Contracts with High-Severity Vuln')
    ax2.set_title('(b) High-Severity Vulnerability Rate')
    ax2.tick_params(axis='x', rotation=45)
    for bar, val in zip(bars, high_rate.values):
        ax2.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 1,
                 f'{val:.1f}%', ha='center', va='bottom', fontsize=9)

    plt.tight_layout()
    _save(fig, output_dir, "fig1_vulnerabilities_by_llm")


def fig2_standard_vs_adversarial(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """Figure 2: Grouped bar chart — standard vs adversarial by LLM."""
    fig, ax = plt.subplots(figsize=(10, 6))

    prompt_llm = df.groupby(['llm', 'prompt_type'])['total_vulns'].median().unstack()
    llm_order = prompt_llm.mean(axis=1).sort_values(ascending=False).index

    x = np.arange(len(llm_order))
    width = 0.35

    std_vals = prompt_llm.loc[llm_order, 'standard'] if 'standard' in prompt_llm.columns else []
    adv_vals = prompt_llm.loc[llm_order, 'adversarial'] if 'adversarial' in prompt_llm.columns else []

    bars1 = ax.bar(x - width / 2, std_vals, width, label='Standard Prompts',
                   color='steelblue', edgecolor='black', linewidth=0.5)
    bars2 = ax.bar(x + width / 2, adv_vals, width, label='Adversarial Prompts',
                   color='firebrick', edgecolor='black', linewidth=0.5)

    ax.set_xlabel('LLM')
    ax.set_ylabel('Median Vulnerabilities per Contract')
    ax.set_title('Standard vs Adversarial Prompt Effects')
    ax.set_xticks(x)
    ax.set_xticklabels(llm_order, rotation=45)
    ax.legend()

    for bars in [bars1, bars2]:
        for bar in bars:
            h = bar.get_height()
            if h > 0:
                ax.text(bar.get_x() + bar.get_width() / 2, h + 0.05,
                        f'{h:.1f}', ha='center', va='bottom', fontsize=9)

    plt.tight_layout()
    _save(fig, output_dir, "fig2_standard_vs_adversarial")


def fig3_vulnerabilities_by_category(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """Figure 3: Heatmap of vulnerabilities by category and LLM."""
    fig, ax = plt.subplots(figsize=(14, 10))

    pivot = df.groupby(['category', 'llm'])['total_vulns'].median().unstack()

    # Sort rows by overall median
    row_order = pivot.median(axis=1).sort_values(ascending=False).index
    pivot = pivot.loc[row_order]

    sns.heatmap(pivot, annot=True, fmt='.1f', cmap='YlOrRd', ax=ax,
                linewidths=0.5, cbar_kws={'label': 'Median Vulnerabilities'})

    ax.set_xlabel('LLM')
    ax.set_ylabel('Contract Category')
    ax.set_title('Vulnerability Density by Contract Category and LLM')

    plt.tight_layout()
    _save(fig, output_dir, "fig3_vulnerabilities_by_category")


def fig4_severity_distribution(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """Figure 4: Stacked bar chart of severity distribution by LLM."""
    fig, ax = plt.subplots(figsize=(12, 6))

    severity_data = df.groupby('llm').agg({
        'high': 'sum',
        'medium': 'sum',
        'low': 'sum',
        'informational': 'sum',
    })

    # Normalize to percentages
    totals = severity_data.sum(axis=1)
    severity_pct = severity_data.div(totals, axis=0) * 100
    # Handle divisions by zero
    severity_pct = severity_pct.fillna(0)

    # Sort by high-severity percentage
    severity_pct = severity_pct.sort_values('high', ascending=False)

    severity_pct.plot(kind='bar', stacked=True, ax=ax,
                      color=['firebrick', 'darkorange', 'gold', 'steelblue'],
                      edgecolor='black', linewidth=0.5)

    ax.set_xlabel('LLM')
    ax.set_ylabel('Percentage of Vulnerabilities')
    ax.set_title('Vulnerability Severity Distribution by LLM')
    ax.legend(title='Severity', labels=['High', 'Medium', 'Low', 'Informational'],
              bbox_to_anchor=(1.02, 1), loc='upper left')
    ax.set_xticklabels(ax.get_xticklabels(), rotation=45)

    plt.tight_layout()
    _save(fig, output_dir, "fig4_severity_distribution")


def fig5_adversarial_trigger_effectiveness(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """Figure 5: Box plot of vuln counts by adversarial category."""
    adv_df = df[df['prompt_type'] == 'adversarial'].copy()

    if adv_df.empty or 'adversarial_category' not in adv_df.columns:
        print("No adversarial data available for fig5")
        return

    # Drop empty/unknown categories
    adv_df = adv_df[adv_df['adversarial_category'].notna() & (adv_df['adversarial_category'] != '')]

    if adv_df.empty:
        print("No adversarial categories found for fig5")
        return

    fig, ax = plt.subplots(figsize=(14, 6))

    cat_order = (adv_df.groupby('adversarial_category')['total_vulns']
                 .median().sort_values(ascending=False).index)

    sns.boxplot(data=adv_df, x='adversarial_category', y='total_vulns',
                order=cat_order, ax=ax, palette='YlOrRd_r', fliersize=3)

    ax.set_xlabel('Adversarial Trigger Category')
    ax.set_ylabel('Total Vulnerabilities')
    ax.set_title('Vulnerability Induction by Adversarial Trigger Category')
    ax.tick_params(axis='x', rotation=45)

    plt.tight_layout()
    _save(fig, output_dir, "fig5_adversarial_triggers")


def fig6_cwe_distribution(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """Figure 6: CWE type breakdown across all LLMs."""
    cwe_cols = [c for c in df.columns if c.startswith('cwe_')]
    if not cwe_cols:
        print("No CWE columns found for fig6")
        return

    fig, ax = plt.subplots(figsize=(12, 6))

    # Sum across all contracts
    cwe_totals = df[cwe_cols].sum().sort_values(ascending=True)
    # Clean labels: cwe_841_reentrancy → CWE-841 (Reentrancy)
    labels = []
    for col in cwe_totals.index:
        parts = col.split('_')
        cwe_num = parts[1] if len(parts) > 1 else '?'
        desc = ' '.join(parts[2:]).title() if len(parts) > 2 else ''
        labels.append(f"CWE-{cwe_num} ({desc})")

    ax.barh(labels, cwe_totals.values, color='steelblue', edgecolor='black', linewidth=0.5)
    ax.set_xlabel('Total Occurrences')
    ax.set_title('CWE Vulnerability Type Distribution')

    for i, v in enumerate(cwe_totals.values):
        if v > 0:
            ax.text(v + 0.5, i, str(int(v)), va='center', fontsize=9)

    plt.tight_layout()
    _save(fig, output_dir, "fig6_cwe_distribution")


def fig7_tool_agreement(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """Figure 7: Scatter matrix of tool findings agreement."""
    tool_cols = ['slither_count', 'mythril_count', 'semgrep_count']
    if not all(c in df.columns for c in tool_cols):
        print("Tool count columns not available for fig7")
        return

    fig, axes = plt.subplots(1, 3, figsize=(15, 4.5))
    pairs = [
        ('slither_count', 'mythril_count', 'Slither', 'Mythril'),
        ('slither_count', 'semgrep_count', 'Slither', 'Semgrep'),
        ('mythril_count', 'semgrep_count', 'Mythril', 'Semgrep'),
    ]

    for ax, (col1, col2, name1, name2) in zip(axes, pairs):
        ax.scatter(df[col1], df[col2], alpha=0.3, s=15, color='steelblue')
        ax.set_xlabel(f'{name1} Findings')
        ax.set_ylabel(f'{name2} Findings')
        # Spearman correlation
        from scipy.stats import spearmanr
        rho, p = spearmanr(df[col1], df[col2])
        ax.set_title(f'{name1} vs {name2}\n(rho={rho:.3f}, p={p:.2e})')

    plt.tight_layout()
    _save(fig, output_dir, "fig7_tool_agreement")


def fig8_loc_normalized_violin(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """Figure 8: LOC-normalized vulnerability rate (compiled only)."""
    if "compiled" not in df.columns or "vulns_per_100_loc" not in df.columns:
        print("Skipping fig8: need compiled + vulns_per_100_loc columns")
        return

    cdf = df[df["compiled"]].copy()
    fig, ax = plt.subplots(figsize=(10, 6))

    llm_order = (cdf.groupby("llm")["vulns_per_100_loc"]
                 .median().sort_values(ascending=False).index.tolist())
    colors = [get_color(llm) for llm in llm_order]

    sns.violinplot(data=cdf, x="llm", y="vulns_per_100_loc", order=llm_order,
                   palette=colors, inner="quartile", ax=ax, cut=0)
    sns.stripplot(data=cdf, x="llm", y="vulns_per_100_loc", order=llm_order,
                  color="black", alpha=0.15, size=2, jitter=True, ax=ax)

    ax.set_xlabel("LLM")
    ax.set_ylabel("Vulnerabilities per 100 LOC")
    ax.set_title("LOC-Normalized Vulnerability Rate (Compiled Contracts Only)")
    ax.tick_params(axis="x", rotation=45)

    plt.tight_layout()
    _save(fig, output_dir, "fig8_loc_normalized_violin")


def fig9_loc_vs_vulns_scatter(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """Figure 9: LOC vs total vulnerabilities scatter with per-LLM regression."""
    if "compiled" not in df.columns or "loc" not in df.columns:
        print("Skipping fig9: need compiled + loc columns")
        return

    cdf = df[df["compiled"]].copy()
    fig, ax = plt.subplots(figsize=(10, 7))

    for llm in sorted(cdf["llm"].unique()):
        ldf = cdf[cdf["llm"] == llm]
        ax.scatter(ldf["loc"], ldf["total_vulns"], alpha=0.4, s=20,
                   color=get_color(llm), label=llm)
        # Regression line
        if len(ldf) > 2:
            z = np.polyfit(ldf["loc"], ldf["total_vulns"], 1)
            p = np.poly1d(z)
            x_range = np.linspace(ldf["loc"].min(), ldf["loc"].max(), 50)
            ax.plot(x_range, p(x_range), color=get_color(llm), linewidth=1.5, alpha=0.7)

    ax.set_xlabel("Lines of Code (LOC)")
    ax.set_ylabel("Total Vulnerabilities")
    ax.set_title("Contract Size vs Vulnerability Count")
    ax.legend(title="LLM", bbox_to_anchor=(1.02, 1), loc="upper left")

    plt.tight_layout()
    _save(fig, output_dir, "fig9_loc_vs_vulns_scatter")


def fig10_compilation_rates(df: pd.DataFrame, output_dir: str = "visualization/figures"):
    """Figure 10: Compilation rate bar chart by LLM."""
    if "compiled" not in df.columns:
        print("Skipping fig10: need compiled column")
        return

    fig, ax = plt.subplots(figsize=(10, 6))

    rates = df.groupby("llm")["compiled"].mean().sort_values(ascending=False) * 100
    colors = [get_color(llm) for llm in rates.index]

    bars = ax.bar(rates.index, rates.values, color=colors, edgecolor="black", linewidth=0.5)
    ax.set_xlabel("LLM")
    ax.set_ylabel("Compilation Rate (%)")
    ax.set_title("Smart Contract Compilation Success Rate by LLM")
    ax.set_ylim(0, 105)
    ax.tick_params(axis="x", rotation=45)

    for bar, val in zip(bars, rates.values):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 1.5,
                f"{val:.1f}%", ha="center", va="bottom", fontsize=10, fontweight="bold")

    plt.tight_layout()
    _save(fig, output_dir, "fig10_compilation_rates")


def _save(fig, output_dir, name):
    """Save figure as both PDF and PNG."""
    output_path = Path(output_dir) / f"{name}.pdf"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=300, bbox_inches='tight')
    fig.savefig(output_path.with_suffix('.png'), dpi=300, bbox_inches='tight')
    plt.close(fig)
    print(f"Saved: {output_path}")


def generate_all_figures(
    csv_path: str = "analysis/results/aggregated_results.csv",
    output_dir: str = "visualization/figures",
):
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
    fig6_cwe_distribution(df, output_dir)
    fig7_tool_agreement(df, output_dir)
    fig8_loc_normalized_violin(df, output_dir)
    fig9_loc_vs_vulns_scatter(df, output_dir)
    fig10_compilation_rates(df, output_dir)

    print(f"\nAll figures saved to: {output_dir}/")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Generate paper figures")
    parser.add_argument("--input", type=str, default="analysis/results/aggregated_results.csv")
    parser.add_argument("--output", type=str, default="visualization/figures")
    args = parser.parse_args()

    generate_all_figures(args.input, args.output)
