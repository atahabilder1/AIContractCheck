#!/usr/bin/env python3
"""
Compute manual validation results from filled-in review CSVs.

Reads the validation CSVs (after human reviewers have filled in verdicts)
and computes:
  - Overall precision: TP / (TP + FP)
  - Per-severity precision
  - Per-LLM precision
  - Cohen's kappa for inter-rater agreement (if two reviewers)
  - Adjusted vulnerability counts using the precision rate

Usage:
  python compute_results.py [--reviewer2 path/to/reviewer2.csv]

The script expects the reviewer_verdict_* columns to be filled with:
  TP = True Positive (real vulnerability)
  FP = False Positive (not a real vulnerability)
  UN = Uncertain (cannot determine)
"""

import argparse
import json
import os
import sys
from collections import defaultdict

import numpy as np
import pandas as pd


BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_LLM_CSV = os.path.join(BASE_DIR, "manual_validation/validation_sample.csv")
DEFAULT_HUMAN_CSV = os.path.join(BASE_DIR, "manual_validation/validation_sample_human.csv")
AGGREGATED_CSV = os.path.join(BASE_DIR, "analysis/results/aggregated_results.csv")
OUTPUT_JSON = os.path.join(BASE_DIR, "manual_validation/validation_results.json")


def load_verdicts(csv_path):
    """Load a filled-in validation CSV and extract verdicts."""
    df = pd.read_csv(csv_path)
    records = []
    for _, row in df.iterrows():
        for i in range(1, 4):
            verdict = str(row.get(f"reviewer_verdict_{i}", "")).strip().upper()
            severity = str(row.get(f"finding_{i}_severity", "")).strip()
            tool = str(row.get(f"finding_{i}_tool", "")).strip()
            detector = str(row.get(f"finding_{i}_detector", "")).strip()

            if not severity or severity == "nan" or not verdict or verdict == "nan" or verdict == "":
                continue

            records.append({
                "filepath": row.get("filepath", ""),
                "llm": row.get("llm", "human"),
                "category": row.get("category", ""),
                "severity": severity,
                "tool": tool,
                "detector": detector,
                "verdict": verdict,
            })

    return pd.DataFrame(records)


def compute_precision(verdicts_df, group_col=None):
    """Compute precision = TP / (TP + FP), optionally grouped."""
    if group_col:
        results = {}
        for group, gdf in verdicts_df.groupby(group_col):
            tp = (gdf["verdict"] == "TP").sum()
            fp = (gdf["verdict"] == "FP").sum()
            un = (gdf["verdict"] == "UN").sum()
            total = tp + fp
            precision = tp / total if total > 0 else None
            results[group] = {
                "TP": int(tp),
                "FP": int(fp),
                "UN": int(un),
                "total_classified": int(total),
                "precision": round(precision, 4) if precision is not None else None,
            }
        return results
    else:
        tp = (verdicts_df["verdict"] == "TP").sum()
        fp = (verdicts_df["verdict"] == "FP").sum()
        un = (verdicts_df["verdict"] == "UN").sum()
        total = tp + fp
        precision = tp / total if total > 0 else None
        return {
            "TP": int(tp),
            "FP": int(fp),
            "UN": int(un),
            "total_classified": int(total),
            "precision": round(precision, 4) if precision is not None else None,
        }


def compute_cohens_kappa(verdicts_r1, verdicts_r2):
    """
    Compute Cohen's kappa between two reviewers.

    Both inputs should be DataFrames with matching rows.
    We compute kappa over the TP/FP labels (excluding UN).
    """
    # Merge on finding identity
    r1 = verdicts_r1.copy()
    r2 = verdicts_r2.copy()

    # Create a unique key for each finding
    r1["key"] = r1["filepath"] + "|" + r1["severity"] + "|" + r1["detector"]
    r2["key"] = r2["filepath"] + "|" + r2["severity"] + "|" + r2["detector"]

    # Keep only findings reviewed by both
    common_keys = set(r1["key"]) & set(r2["key"])
    r1 = r1[r1["key"].isin(common_keys)].set_index("key")
    r2 = r2[r2["key"].isin(common_keys)].set_index("key")

    # Align indices
    common = r1.index.intersection(r2.index)
    if len(common) == 0:
        return {"kappa": None, "n": 0, "note": "No overlapping findings"}

    labels_1 = r1.loc[common, "verdict"].values
    labels_2 = r2.loc[common, "verdict"].values

    # Filter to only TP/FP (exclude UN for kappa computation)
    mask = np.array([(l1 in ("TP", "FP") and l2 in ("TP", "FP"))
                     for l1, l2 in zip(labels_1, labels_2)])

    if mask.sum() < 2:
        return {"kappa": None, "n": int(mask.sum()),
                "note": "Insufficient TP/FP overlap for kappa"}

    l1 = labels_1[mask]
    l2 = labels_2[mask]
    n = len(l1)

    # Observed agreement
    po = np.mean(l1 == l2)

    # Expected agreement
    categories = ["TP", "FP"]
    pe = 0.0
    for cat in categories:
        p1 = np.mean(l1 == cat)
        p2 = np.mean(l2 == cat)
        pe += p1 * p2

    kappa = (po - pe) / (1 - pe) if (1 - pe) != 0 else 1.0

    # Agreement matrix
    agreement_matrix = {}
    for c1 in categories:
        for c2 in categories:
            agreement_matrix[f"R1={c1}_R2={c2}"] = int(np.sum((l1 == c1) & (l2 == c2)))

    return {
        "kappa": round(float(kappa), 4),
        "observed_agreement": round(float(po), 4),
        "expected_agreement": round(float(pe), 4),
        "n": int(n),
        "agreement_matrix": agreement_matrix,
        "interpretation": interpret_kappa(kappa),
    }


def interpret_kappa(kappa):
    """Interpret kappa value using Landis & Koch scale."""
    if kappa is None:
        return "N/A"
    if kappa < 0:
        return "Poor (less than chance)"
    elif kappa < 0.21:
        return "Slight"
    elif kappa < 0.41:
        return "Fair"
    elif kappa < 0.61:
        return "Moderate"
    elif kappa < 0.81:
        return "Substantial"
    else:
        return "Almost perfect"


def compute_adjusted_counts(overall_precision, aggregated_csv):
    """
    Apply the manual validation precision rate to adjust total vulnerability counts.

    adjusted_vulns = raw_vulns * precision_rate
    """
    if overall_precision is None:
        return None

    df = pd.read_csv(aggregated_csv)
    precision = overall_precision

    results = {}
    for llm in sorted(df["llm"].unique()):
        llm_df = df[df["llm"] == llm]
        raw_total = llm_df["total_vulns"].sum()
        adjusted_total = round(raw_total * precision)
        raw_mean = llm_df["total_vulns"].mean()
        adjusted_mean = round(raw_mean * precision, 2)

        results[llm] = {
            "raw_total_vulns": int(raw_total),
            "adjusted_total_vulns": int(adjusted_total),
            "raw_mean_vulns": round(float(raw_mean), 2),
            "adjusted_mean_vulns": float(adjusted_mean),
            "precision_applied": round(precision, 4),
        }

    # Overall
    raw_total = df["total_vulns"].sum()
    results["_overall"] = {
        "raw_total_vulns": int(raw_total),
        "adjusted_total_vulns": int(round(raw_total * precision)),
        "raw_mean_vulns": round(float(df["total_vulns"].mean()), 2),
        "adjusted_mean_vulns": round(float(df["total_vulns"].mean() * precision), 2),
        "precision_applied": round(precision, 4),
    }

    return results


def compute_per_tool_precision(verdicts_df):
    """Compute precision broken down by analysis tool."""
    return compute_precision(verdicts_df, group_col="tool")


def compute_per_detector_precision(verdicts_df):
    """Compute precision broken down by detector, for detectors with 3+ findings."""
    results = compute_precision(verdicts_df, group_col="detector")
    # Filter to detectors with at least 3 reviewed findings
    return {k: v for k, v in results.items()
            if v["total_classified"] >= 3}


def main():
    parser = argparse.ArgumentParser(description="Compute manual validation results")
    parser.add_argument("--llm-csv", default=DEFAULT_LLM_CSV,
                        help="Path to filled-in LLM validation CSV")
    parser.add_argument("--human-csv", default=DEFAULT_HUMAN_CSV,
                        help="Path to filled-in human baseline validation CSV")
    parser.add_argument("--reviewer2", default=None,
                        help="Path to second reviewer's CSV (for Cohen's kappa)")
    parser.add_argument("--output", default=OUTPUT_JSON,
                        help="Output JSON path")
    args = parser.parse_args()

    results = {}

    # --- LLM Validation ---
    print("=== LLM Contract Validation Results ===\n")

    if not os.path.exists(args.llm_csv):
        print(f"ERROR: {args.llm_csv} not found. Fill in verdicts first.")
        sys.exit(1)

    verdicts = load_verdicts(args.llm_csv)

    if len(verdicts) == 0:
        print("No verdicts found. Please fill in reviewer_verdict_* columns with TP/FP/UN.")
        sys.exit(1)

    # Overall precision
    overall = compute_precision(verdicts)
    print(f"Overall precision: {overall['precision']}")
    print(f"  TP={overall['TP']}, FP={overall['FP']}, UN={overall['UN']}")
    results["llm_overall"] = overall

    # Per-severity precision
    per_severity = compute_precision(verdicts, group_col="severity")
    print(f"\nPer-severity precision:")
    for sev, vals in sorted(per_severity.items()):
        print(f"  {sev}: precision={vals['precision']} "
              f"(TP={vals['TP']}, FP={vals['FP']}, UN={vals['UN']})")
    results["llm_per_severity"] = per_severity

    # Per-LLM precision
    per_llm = compute_precision(verdicts, group_col="llm")
    print(f"\nPer-LLM precision:")
    for llm, vals in sorted(per_llm.items()):
        print(f"  {llm}: precision={vals['precision']} "
              f"(TP={vals['TP']}, FP={vals['FP']}, UN={vals['UN']})")
    results["llm_per_llm"] = per_llm

    # Per-tool precision
    per_tool = compute_per_tool_precision(verdicts)
    print(f"\nPer-tool precision:")
    for tool, vals in sorted(per_tool.items()):
        print(f"  {tool}: precision={vals['precision']} "
              f"(TP={vals['TP']}, FP={vals['FP']}, UN={vals['UN']})")
    results["llm_per_tool"] = per_tool

    # Per-detector precision (top detectors)
    per_detector = compute_per_detector_precision(verdicts)
    if per_detector:
        print(f"\nPer-detector precision (detectors with 3+ findings):")
        for det, vals in sorted(per_detector.items(), key=lambda x: x[1].get("precision", 0) or 0):
            print(f"  {det}: precision={vals['precision']} (n={vals['total_classified']})")
    results["llm_per_detector"] = per_detector

    # --- Human Baseline Validation ---
    if os.path.exists(args.human_csv):
        print("\n\n=== Human Baseline Validation Results ===\n")
        human_verdicts = load_verdicts(args.human_csv)
        if len(human_verdicts) > 0:
            human_overall = compute_precision(human_verdicts)
            print(f"Overall precision: {human_overall['precision']}")
            print(f"  TP={human_overall['TP']}, FP={human_overall['FP']}, UN={human_overall['UN']}")
            results["human_overall"] = human_overall

            human_per_severity = compute_precision(human_verdicts, group_col="severity")
            print(f"\nPer-severity precision:")
            for sev, vals in sorted(human_per_severity.items()):
                print(f"  {sev}: precision={vals['precision']} "
                      f"(TP={vals['TP']}, FP={vals['FP']}, UN={vals['UN']})")
            results["human_per_severity"] = human_per_severity
        else:
            print("No human baseline verdicts found yet.")

    # --- Cohen's Kappa ---
    if args.reviewer2:
        print("\n\n=== Inter-Rater Agreement (Cohen's Kappa) ===\n")
        if not os.path.exists(args.reviewer2):
            print(f"ERROR: Reviewer 2 CSV not found: {args.reviewer2}")
        else:
            verdicts_r2 = load_verdicts(args.reviewer2)
            kappa_result = compute_cohens_kappa(verdicts, verdicts_r2)
            print(f"Cohen's kappa: {kappa_result['kappa']}")
            print(f"Interpretation: {kappa_result['interpretation']}")
            print(f"Observed agreement: {kappa_result.get('observed_agreement', 'N/A')}")
            print(f"N findings compared: {kappa_result['n']}")
            if "agreement_matrix" in kappa_result:
                print(f"Agreement matrix: {kappa_result['agreement_matrix']}")
            results["inter_rater_agreement"] = kappa_result

    # --- Adjusted Vulnerability Counts ---
    print("\n\n=== Adjusted Vulnerability Counts ===\n")
    precision_rate = overall.get("precision")
    if precision_rate is not None and os.path.exists(AGGREGATED_CSV):
        adjusted = compute_adjusted_counts(precision_rate, AGGREGATED_CSV)
        results["adjusted_counts"] = adjusted

        print(f"Applying precision rate: {precision_rate}")
        print(f"\n{'LLM':<15} {'Raw Total':>10} {'Adjusted':>10} {'Raw Mean':>10} {'Adj Mean':>10}")
        print("-" * 60)
        for llm in sorted(adjusted.keys()):
            if llm.startswith("_"):
                continue
            v = adjusted[llm]
            print(f"{llm:<15} {v['raw_total_vulns']:>10} {v['adjusted_total_vulns']:>10} "
                  f"{v['raw_mean_vulns']:>10.2f} {v['adjusted_mean_vulns']:>10.2f}")
        ov = adjusted["_overall"]
        print("-" * 60)
        print(f"{'OVERALL':<15} {ov['raw_total_vulns']:>10} {ov['adjusted_total_vulns']:>10} "
              f"{ov['raw_mean_vulns']:>10.2f} {ov['adjusted_mean_vulns']:>10.2f}")
    else:
        print("Cannot compute adjusted counts (no precision rate or missing aggregated data).")

    # --- Save Results ---
    with open(args.output, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\n\nResults saved to: {args.output}")


if __name__ == "__main__":
    main()
