#!/usr/bin/env python3
"""
Sample contracts for manual validation of automated vulnerability findings.

Samples 120 contracts (15 per LLM) stratified by severity:
  - 5 with high-severity findings
  - 5 with medium-severity (but no high) findings
  - 5 with low/no findings

For each sampled contract, extracts the top 3 vulnerability findings
with descriptions from the all_vulnerabilities.json file.

Also samples 30 human baseline contracts with findings.
"""

import json
import os
import random
import sys

import pandas as pd

# Reproducible sampling
SEED = 42
random.seed(SEED)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AGGREGATED_CSV = os.path.join(BASE_DIR, "analysis/results/aggregated_results.csv")
ALL_VULNS_JSON = os.path.join(BASE_DIR, "analysis/results/all_vulnerabilities.json")
HUMAN_SLITHER = os.path.join(BASE_DIR, "analysis/human_baseline_results/slither_results.json")
OUTPUT_CSV = os.path.join(BASE_DIR, "manual_validation/validation_sample.csv")
OUTPUT_HUMAN_CSV = os.path.join(BASE_DIR, "manual_validation/validation_sample_human.csv")

# Sampling parameters
CONTRACTS_PER_LLM = 15
HIGH_PER_LLM = 5
MEDIUM_PER_LLM = 5
LOW_NONE_PER_LLM = 5
HUMAN_SAMPLE_SIZE = 30


def classify_severity(row):
    """Classify a contract by its highest severity finding."""
    if row["high"] > 0:
        return "high"
    elif row["medium"] > 0:
        return "medium"
    else:
        return "low_none"


def safe_sample(df, n, seed=SEED):
    """Sample n rows from df, or all rows if fewer than n available."""
    if len(df) <= n:
        return df
    return df.sample(n=n, random_state=seed)


def build_vuln_lookup(vulns_data):
    """Build a dict mapping filepath -> list of vulnerability records, sorted by severity."""
    severity_order = {"High": 0, "Medium": 1, "Low": 2, "Informational": 3}
    lookup = {}
    for v in vulns_data:
        fp = v["filepath"]
        if fp not in lookup:
            lookup[fp] = []
        lookup[fp].append(v)

    # Sort each list by severity
    for fp in lookup:
        lookup[fp].sort(key=lambda x: severity_order.get(x.get("severity", "Informational"), 4))

    return lookup


def sample_llm_contracts(df):
    """Sample 15 contracts per LLM, stratified by severity."""
    df = df.copy()
    df["severity_class"] = df.apply(classify_severity, axis=1)

    sampled = []
    for llm in sorted(df["llm"].unique()):
        llm_df = df[df["llm"] == llm]

        high_df = llm_df[llm_df["severity_class"] == "high"]
        med_df = llm_df[llm_df["severity_class"] == "medium"]
        low_df = llm_df[llm_df["severity_class"] == "low_none"]

        # Sample from each stratum; if insufficient, redistribute
        h_sample = safe_sample(high_df, HIGH_PER_LLM)
        m_sample = safe_sample(med_df, MEDIUM_PER_LLM)
        l_sample = safe_sample(low_df, LOW_NONE_PER_LLM)

        # If any stratum was short, try to fill from others
        total = len(h_sample) + len(m_sample) + len(l_sample)
        shortfall = CONTRACTS_PER_LLM - total
        if shortfall > 0:
            already_sampled = set(
                h_sample["filepath"].tolist()
                + m_sample["filepath"].tolist()
                + l_sample["filepath"].tolist()
            )
            remaining = llm_df[~llm_df["filepath"].isin(already_sampled)]
            extra = safe_sample(remaining, shortfall)
            sampled.extend([h_sample, m_sample, l_sample, extra])
        else:
            sampled.extend([h_sample, m_sample, l_sample])

        count = min(CONTRACTS_PER_LLM, total + (shortfall if shortfall > 0 else 0))
        print(f"  {llm}: sampled {count} "
              f"(high={len(h_sample)}, med={len(m_sample)}, low/none={len(l_sample)}"
              f"{f', extra={len(extra)}' if shortfall > 0 else ''})")

    return pd.concat(sampled, ignore_index=True)


def create_validation_row(idx, row, vuln_lookup):
    """Create a single validation CSV row with top 3 findings."""
    filepath = row["filepath"]
    vulns = vuln_lookup.get(filepath, [])

    out = {
        "id": idx,
        "filepath": filepath,
        "llm": row["llm"],
        "category": row["category"],
        "prompt_type": row.get("prompt_type", ""),
        "compiled": row.get("compiled", ""),
        "total_vulns": row["total_vulns"],
    }

    for i in range(3):
        suffix = f"_{i+1}"
        if i < len(vulns):
            v = vulns[i]
            out[f"finding{suffix}_tool"] = v.get("tool", "")
            out[f"finding{suffix}_detector"] = v.get("detector", "")
            out[f"finding{suffix}_severity"] = v.get("severity", "")
            out[f"finding{suffix}_description"] = v.get("description", "")[:500]
        else:
            out[f"finding{suffix}_tool"] = ""
            out[f"finding{suffix}_detector"] = ""
            out[f"finding{suffix}_severity"] = ""
            out[f"finding{suffix}_description"] = ""
        out[f"reviewer_verdict{suffix}"] = ""

    out["reviewer_notes"] = ""
    return out


def sample_human_baseline():
    """Sample 30 compiled human baseline contracts with findings."""
    print("\n--- Sampling human baseline contracts ---")
    with open(HUMAN_SLITHER) as f:
        human_data = json.load(f)

    # Filter to compiled contracts with findings
    candidates = [d for d in human_data if d.get("compiled") and d.get("vuln_count", 0) > 0]
    print(f"  Compiled with findings: {len(candidates)}")

    random.shuffle(candidates)
    sampled = candidates[:HUMAN_SAMPLE_SIZE]
    print(f"  Sampled: {len(sampled)}")

    rows = []
    for idx, contract in enumerate(sampled, start=1):
        findings = contract.get("findings", [])
        severity_order = {"High": 0, "Medium": 1, "Low": 2}
        findings.sort(key=lambda x: severity_order.get(x.get("severity", "Low"), 3))

        row = {
            "id": idx,
            "filepath": contract["file"],
            "category": contract.get("category", ""),
            "compiled": contract.get("compiled", ""),
            "total_vulns": contract.get("vuln_count", 0),
        }

        for i in range(3):
            suffix = f"_{i+1}"
            if i < len(findings):
                f_data = findings[i]
                row[f"finding{suffix}_tool"] = f_data.get("tool", "slither")
                row[f"finding{suffix}_detector"] = f_data.get("detector", "")
                row[f"finding{suffix}_severity"] = f_data.get("severity", "")
                row[f"finding{suffix}_description"] = f_data.get("description", "")[:500]
            else:
                row[f"finding{suffix}_tool"] = ""
                row[f"finding{suffix}_detector"] = ""
                row[f"finding{suffix}_severity"] = ""
                row[f"finding{suffix}_description"] = ""
            row[f"reviewer_verdict{suffix}"] = ""

        row["reviewer_notes"] = ""
        rows.append(row)

    return pd.DataFrame(rows)


def main():
    print("=== Manual Validation Sampling ===\n")

    # Load data
    print("Loading aggregated results...")
    df = pd.read_csv(AGGREGATED_CSV)
    print(f"  Total contracts: {len(df)}")
    print(f"  LLMs: {sorted(df['llm'].unique())}")

    print("\nLoading vulnerability details...")
    with open(ALL_VULNS_JSON) as f:
        vulns_data = json.load(f)
    print(f"  Total vulnerability records: {len(vulns_data)}")
    vuln_lookup = build_vuln_lookup(vulns_data)

    # Sample LLM contracts
    print(f"\n--- Sampling {CONTRACTS_PER_LLM} contracts per LLM ---")
    sampled_df = sample_llm_contracts(df)
    print(f"\nTotal sampled: {len(sampled_df)}")

    # Build validation CSV rows
    rows = []
    for idx, (_, row) in enumerate(sampled_df.iterrows(), start=1):
        rows.append(create_validation_row(idx, row, vuln_lookup))

    output_df = pd.DataFrame(rows)
    output_df.to_csv(OUTPUT_CSV, index=False)
    print(f"\nLLM validation sample saved to: {OUTPUT_CSV}")
    print(f"  Rows: {len(output_df)}")
    print(f"  Columns: {list(output_df.columns)}")

    # Sample human baseline
    human_df = sample_human_baseline()
    human_df.to_csv(OUTPUT_HUMAN_CSV, index=False)
    print(f"\nHuman baseline sample saved to: {OUTPUT_HUMAN_CSV}")
    print(f"  Rows: {len(human_df)}")

    # Summary statistics
    print("\n=== Summary ===")
    print(f"LLM contracts to review: {len(output_df)}")
    print(f"Human baseline contracts to review: {len(human_df)}")
    print(f"Total contracts: {len(output_df) + len(human_df)}")
    findings_to_review = 0
    for _, row in output_df.iterrows():
        for i in range(1, 4):
            if row.get(f"finding_{i}_severity", ""):
                findings_to_review += 1
    print(f"Total individual findings to review (LLM): {findings_to_review}")


if __name__ == "__main__":
    main()
