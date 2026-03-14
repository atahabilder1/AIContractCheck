"""
Phase 0: Add compilation status, LOC, and function count to aggregated results.
Fixes the critical data integrity issue where non-compiling contracts show 0 vulns.
"""

import json
import re
from pathlib import Path

import pandas as pd


def count_loc(filepath: str) -> int:
    """Count non-empty, non-comment lines of Solidity code."""
    try:
        with open(filepath) as f:
            lines = f.readlines()
    except FileNotFoundError:
        return 0

    loc = 0
    in_block_comment = False
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        if in_block_comment:
            if "*/" in stripped:
                in_block_comment = False
            continue
        if stripped.startswith("//"):
            continue
        if stripped.startswith("/*"):
            if "*/" not in stripped:
                in_block_comment = True
            continue
        loc += 1
    return loc


def count_functions(filepath: str) -> int:
    """Count function definitions in a Solidity file."""
    try:
        with open(filepath) as f:
            content = f.read()
    except FileNotFoundError:
        return 0
    return len(re.findall(r'\bfunction\s+\w+', content))


def get_compilation_status(slither_file: str) -> dict:
    """Parse slither results to determine which contracts compiled."""
    with open(slither_file) as f:
        data = json.load(f)

    status = {}
    for entry in data:
        filepath = entry["file"]
        has_error = bool(entry.get("findings", {}).get("error"))
        status[filepath] = not has_error
    return status


def add_compilation_status(
    csv_file: str = "analysis/results/aggregated_results.csv",
    slither_file: str = "analysis/results/slither_results.json",
    output_file: str = "analysis/results/aggregated_results.csv",
):
    """Add compiled, loc, function_count, vulns_per_100_loc columns."""
    df = pd.read_csv(csv_file)
    compilation = get_compilation_status(slither_file)

    # Add compilation status
    df["compiled"] = df["filepath"].map(compilation).fillna(False).astype(bool)

    # Add LOC and function count
    df["loc"] = df["filepath"].apply(count_loc)
    df["function_count"] = df["filepath"].apply(count_functions)

    # Add LOC-normalized vulnerability rate
    df["vulns_per_100_loc"] = df.apply(
        lambda r: (r["total_vulns"] / r["loc"] * 100) if r["loc"] > 0 else 0, axis=1
    )

    df.to_csv(output_file, index=False)

    # Print summary
    print(f"{'='*60}")
    print("PHASE 0: COMPILATION STATUS ADDED")
    print(f"{'='*60}")
    print(f"Total contracts: {len(df)}")
    print(f"Compiled: {df['compiled'].sum()} ({df['compiled'].mean()*100:.1f}%)")
    print(f"Failed: {(~df['compiled']).sum()} ({(~df['compiled']).mean()*100:.1f}%)")

    compiled_df = df[df["compiled"]]
    print(f"\n--- Compiled-only stats ({len(compiled_df)} contracts) ---")
    print(f"Contracts with vulns: {(compiled_df['total_vulns'] > 0).sum()} "
          f"({(compiled_df['total_vulns'] > 0).mean()*100:.1f}%)")
    print(f"Contracts with high-sev: {compiled_df['has_high'].sum()} "
          f"({compiled_df['has_high'].mean()*100:.1f}%)")
    print(f"Mean vulns/contract: {compiled_df['total_vulns'].mean():.2f}")
    print(f"Mean LOC: {compiled_df['loc'].mean():.1f}")
    print(f"Mean vulns/100 LOC: {compiled_df['vulns_per_100_loc'].mean():.2f}")

    print(f"\n--- Per-LLM (compiled only) ---")
    for llm in sorted(compiled_df["llm"].unique()):
        llm_df = compiled_df[compiled_df["llm"] == llm]
        print(f"  {llm:12s}: n={len(llm_df):3d}, "
              f"mean_vulns={llm_df['total_vulns'].mean():.2f}, "
              f"mean_loc={llm_df['loc'].mean():.0f}, "
              f"vulns/100loc={llm_df['vulns_per_100_loc'].mean():.2f}, "
              f"high_sev={llm_df['has_high'].mean()*100:.1f}%")

    print(f"\nSaved to: {output_file}")
    return df


if __name__ == "__main__":
    add_compilation_status()
