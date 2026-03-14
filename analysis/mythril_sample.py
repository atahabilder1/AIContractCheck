"""
Phase 3: Select a stratified sample of 500 compiled contracts for Mythril analysis.
Stratified by LLM (proportional to compiled count).
"""

import pandas as pd
from pathlib import Path


def create_mythril_sample(
    csv_file: str = "analysis/results/aggregated_results.csv",
    output_file: str = "analysis/results/mythril_sample.txt",
    n_total: int = 500,
    seed: int = 42,
):
    df = pd.read_csv(csv_file)

    if "compiled" not in df.columns:
        raise ValueError("Run add_compilation_status.py first")

    compiled = df[df["compiled"]].copy()
    print(f"Compiled contracts: {len(compiled)}")

    # Stratified sample proportional to each LLM's compiled count
    samples = []
    for llm in sorted(compiled["llm"].unique()):
        llm_df = compiled[compiled["llm"] == llm]
        proportion = len(llm_df) / len(compiled)
        n_sample = max(1, round(n_total * proportion))
        n_sample = min(n_sample, len(llm_df))
        sampled = llm_df.sample(n=n_sample, random_state=seed)
        samples.append(sampled)
        print(f"  {llm:12s}: {n_sample}/{len(llm_df)} selected ({proportion*100:.1f}%)")

    sample_df = pd.concat(samples)
    # Trim to exact target if rounding caused overshoot
    if len(sample_df) > n_total:
        sample_df = sample_df.sample(n=n_total, random_state=seed)

    # Write file paths
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        for fp in sorted(sample_df["filepath"]):
            f.write(fp + "\n")

    print(f"\nTotal sample: {len(sample_df)} contracts")
    print(f"Saved to: {output_path}")
    return sample_df


if __name__ == "__main__":
    create_mythril_sample()
