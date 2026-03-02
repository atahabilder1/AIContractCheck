"""
Aggregate analysis results from multiple tools into a unified dataset.
"""

import json
from pathlib import Path

import pandas as pd

from .categorize import calculate_vulnerability_score, CWE_MAPPING


def load_slither_results(filepath: str = "analysis/slither_results.json") -> list:
    """Load Slither analysis results."""
    try:
        with open(filepath) as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Warning: {filepath} not found")
        return []


def load_mythril_results(filepath: str = "analysis/mythril_results.json") -> list:
    """Load Mythril analysis results."""
    try:
        with open(filepath) as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Warning: {filepath} not found")
        return []


def load_metadata(filepath: str = "dataset/metadata.json") -> dict:
    """Load dataset generation metadata."""
    try:
        with open(filepath) as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Warning: {filepath} not found")
        return {"results": []}


def aggregate_results(
    slither_file: str = "analysis/slither_results.json",
    mythril_file: str = "analysis/mythril_results.json",
    metadata_file: str = "dataset/metadata.json",
    output_csv: str = "analysis/aggregated_results.csv"
):
    """
    Aggregate all analysis results into a single dataframe.

    Args:
        slither_file: Path to Slither results
        mythril_file: Path to Mythril results
        metadata_file: Path to dataset metadata
        output_csv: Path to save aggregated CSV
    """
    # Load all data
    slither = load_slither_results(slither_file)
    mythril = load_mythril_results(mythril_file)
    metadata = load_metadata(metadata_file)

    # Create lookup dictionaries
    slither_by_file = {r["file"]: r for r in slither}
    mythril_by_file = {r["file"]: r for r in mythril}

    rows = []

    for meta in metadata.get("results", []):
        filepath = meta.get("filepath", "")
        if not filepath:
            continue

        llm = meta.get("llm", "unknown")
        category = meta.get("category", "unknown")
        prompt_type = meta.get("type", "unknown")
        complexity = meta.get("complexity", "")
        trigger = meta.get("trigger", "")

        # Get Slither findings
        slither_data = slither_by_file.get(filepath, {})
        slither_findings = slither_data.get("findings", {})
        slither_detectors = slither_findings.get("results", {}).get("detectors", [])

        # Get Mythril findings
        mythril_data = mythril_by_file.get(filepath, {})
        mythril_findings = mythril_data.get("findings", {})
        mythril_issues = mythril_findings.get("issues", [])

        # Count vulnerabilities by severity
        slither_high = len([d for d in slither_detectors if d.get("impact") == "High"])
        slither_medium = len([d for d in slither_detectors if d.get("impact") == "Medium"])
        slither_low = len([d for d in slither_detectors if d.get("impact") == "Low"])
        slither_info = len([d for d in slither_detectors if d.get("impact") == "Informational"])

        mythril_high = len([i for i in mythril_issues if i.get("severity") == "High"])
        mythril_medium = len([i for i in mythril_issues if i.get("severity") == "Medium"])
        mythril_low = len([i for i in mythril_issues if i.get("severity") == "Low"])

        # Calculate scores
        slither_score = calculate_vulnerability_score(slither_detectors)

        rows.append({
            "filepath": filepath,
            "llm": llm,
            "category": category,
            "prompt_type": prompt_type,
            "complexity": complexity,
            "trigger": trigger,
            # Slither counts
            "slither_high": slither_high,
            "slither_medium": slither_medium,
            "slither_low": slither_low,
            "slither_info": slither_info,
            "slither_total": len(slither_detectors),
            "slither_score": slither_score["total_score"],
            # Mythril counts
            "mythril_high": mythril_high,
            "mythril_medium": mythril_medium,
            "mythril_low": mythril_low,
            "mythril_total": len(mythril_issues),
            # Combined
            "total_high": slither_high + mythril_high,
            "total_vulns": len(slither_detectors) + len(mythril_issues),
            "has_critical": (slither_high + mythril_high) > 0
        })

    # Create dataframe
    df = pd.DataFrame(rows)

    # Save to CSV
    output_path = Path(output_csv)
    output_path.parent.mkdir(exist_ok=True)
    df.to_csv(output_path, index=False)

    # Print summary
    print("\n" + "=" * 60)
    print("AGGREGATED RESULTS SUMMARY")
    print("=" * 60)

    print(f"\nTotal contracts analyzed: {len(df)}")

    print("\nVulnerabilities by LLM:")
    print(df.groupby("llm")[["slither_total", "mythril_total", "total_vulns"]].agg(["mean", "sum"]))

    print("\nVulnerabilities by Prompt Type:")
    print(df.groupby("prompt_type")[["total_vulns", "total_high"]].agg(["mean", "sum"]))

    print("\nContracts with Critical Vulnerabilities by LLM:")
    print(df.groupby("llm")["has_critical"].sum())

    print(f"\nResults saved to: {output_path}")

    return df


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Aggregate analysis results")
    parser.add_argument("--slither", type=str, default="analysis/slither_results.json")
    parser.add_argument("--mythril", type=str, default="analysis/mythril_results.json")
    parser.add_argument("--metadata", type=str, default="dataset/metadata.json")
    parser.add_argument("--output", type=str, default="analysis/aggregated_results.csv")

    args = parser.parse_args()

    aggregate_results(
        slither_file=args.slither,
        mythril_file=args.mythril,
        metadata_file=args.metadata,
        output_csv=args.output
    )
