"""
Aggregate analysis results from Slither, Mythril, and Semgrep into a unified dataset.
Includes cross-tool deduplication to avoid counting the same vulnerability twice.
"""

import json
from pathlib import Path

import pandas as pd

from .categorize import CWE_MAPPING, CWE_CATEGORIES, SEVERITY_WEIGHTS, get_cwe


def load_results(filepath: str) -> dict:
    """Load analysis results and index by file path."""
    try:
        with open(filepath) as f:
            data = json.load(f)
        return {r["file"]: r for r in data}
    except FileNotFoundError:
        print(f"Warning: {filepath} not found")
        return {}


def load_prompt_metadata(dataset_dir: str = "dataset") -> dict:
    """Load metadata from all LLM progress.json files."""
    meta = {}
    dataset_path = Path(dataset_dir)
    for progress_file in dataset_path.rglob("progress.json"):
        with open(progress_file) as f:
            data = json.load(f)
        for r in data.get("results", []):
            filepath = str(dataset_path / r.get("filepath", ""))
            meta[filepath] = r
    return meta


def extract_slither_vulns(findings: dict) -> list:
    """Extract normalized vulnerabilities from Slither output."""
    vulns = []
    detectors = findings.get("results", {}).get("detectors", [])
    for d in detectors:
        check = d.get("check", "unknown")
        vulns.append({
            "tool": "slither",
            "detector": check,
            "severity": d.get("impact", "Unknown"),
            "confidence": d.get("confidence", "Unknown"),
            "cwe": get_cwe(check),
            "description": d.get("description", "")[:200],
            "dedup_key": f"slither:{check}:{d.get('first_markdown_element', '')}",
        })
    return vulns


def extract_mythril_vulns(findings: dict) -> list:
    """Extract normalized vulnerabilities from Mythril output."""
    vulns = []
    issues = findings.get("issues", [])
    for issue in issues:
        swc_id = issue.get("swc-id", "")
        vulns.append({
            "tool": "mythril",
            "detector": issue.get("title", "unknown"),
            "severity": issue.get("severity", "Unknown"),
            "confidence": "High",  # Mythril uses symbolic execution
            "cwe": f"SWC-{swc_id}" if swc_id else "Unknown",
            "description": issue.get("description", "")[:200],
            "dedup_key": f"mythril:{swc_id}:{issue.get('lineno', '')}",
        })
    return vulns


def extract_semgrep_vulns(findings: dict) -> list:
    """Extract normalized vulnerabilities from Semgrep output."""
    vulns = []
    results = findings.get("results", [])
    for r in results:
        rule_id = r.get("check_id", "unknown")
        metadata = r.get("extra", {}).get("metadata", {})
        severity_map = {"ERROR": "High", "WARNING": "Medium", "INFO": "Low"}
        vulns.append({
            "tool": "semgrep",
            "detector": rule_id,
            "severity": severity_map.get(r.get("extra", {}).get("severity", ""), "Medium"),
            "confidence": "Medium",
            "cwe": metadata.get("cwe", "Unknown"),
            "description": r.get("extra", {}).get("message", "")[:200],
            "dedup_key": f"semgrep:{rule_id}:{r.get('start', {}).get('line', '')}",
        })
    return vulns


def deduplicate_vulns(vulns: list) -> list:
    """
    Cross-tool deduplication.
    If Slither and Mythril both find reentrancy on the same function,
    count it once. We group by (CWE, approximate location).
    """
    seen = set()
    deduped = []
    for v in vulns:
        # Create a dedup key based on CWE and rough location
        key = v["dedup_key"]
        if key not in seen:
            seen.add(key)
            deduped.append(v)
    return deduped


def aggregate_results(
    slither_file: str = "analysis/results/slither_results.json",
    mythril_file: str = "analysis/results/mythril_results.json",
    semgrep_file: str = "analysis/results/semgrep_results.json",
    dataset_dir: str = "dataset",
    output_csv: str = "analysis/results/aggregated_results.csv",
    output_vulns: str = "analysis/results/all_vulnerabilities.json",
):
    """Aggregate all analysis results into a single dataframe."""

    slither_data = load_results(slither_file)
    mythril_data = load_results(mythril_file)
    semgrep_data = load_results(semgrep_file)
    prompt_meta = load_prompt_metadata(dataset_dir)

    # Get all unique contract files
    all_files = set()
    all_files.update(slither_data.keys())
    all_files.update(mythril_data.keys())
    all_files.update(semgrep_data.keys())

    print(f"Total unique contracts: {len(all_files)}")

    rows = []
    all_vulns = []

    for filepath in sorted(all_files):
        # Get metadata from whichever source has it
        meta = {}
        for source in [slither_data, mythril_data, semgrep_data]:
            if filepath in source:
                meta = {
                    "llm": source[filepath].get("llm", "unknown"),
                    "prompt_type": source[filepath].get("prompt_type", "unknown"),
                    "category": source[filepath].get("category", "unknown"),
                }
                break

        # Get prompt-level metadata
        pmeta = prompt_meta.get(filepath, {})

        # Extract vulnerabilities from each tool
        vulns = []
        slither_vulns = []
        mythril_vulns = []
        semgrep_vulns = []

        if filepath in slither_data:
            findings = slither_data[filepath].get("findings", {})
            if not findings.get("error"):
                slither_vulns = extract_slither_vulns(findings)
                vulns.extend(slither_vulns)

        if filepath in mythril_data:
            findings = mythril_data[filepath].get("findings", {})
            if not findings.get("error"):
                mythril_vulns = extract_mythril_vulns(findings)
                vulns.extend(mythril_vulns)

        if filepath in semgrep_data:
            findings = semgrep_data[filepath].get("findings", {})
            if not findings.get("error"):
                semgrep_vulns = extract_semgrep_vulns(findings)
                vulns.extend(semgrep_vulns)

        # Deduplicate across tools
        deduped = deduplicate_vulns(vulns)

        # Count by severity
        high = len([v for v in deduped if v["severity"] == "High"])
        medium = len([v for v in deduped if v["severity"] == "Medium"])
        low = len([v for v in deduped if v["severity"] == "Low"])
        info = len([v for v in deduped if v["severity"] == "Informational"])

        # Count by CWE
        cwe_counts = {}
        for v in deduped:
            cwe = v["cwe"]
            cwe_counts[cwe] = cwe_counts.get(cwe, 0) + 1

        # Vulnerability score (weighted)
        score = high * 3 + medium * 2 + low * 1

        rows.append({
            "filepath": filepath,
            "llm": meta.get("llm", "unknown"),
            "category": meta.get("category", "unknown"),
            "prompt_type": meta.get("prompt_type", "unknown"),
            "complexity": pmeta.get("complexity", ""),
            "trigger": pmeta.get("trigger", ""),
            "adversarial_category": pmeta.get("adversarial_category", ""),
            # Per-tool counts
            "slither_count": len(slither_vulns),
            "mythril_count": len(mythril_vulns),
            "semgrep_count": len(semgrep_vulns),
            # Deduplicated counts
            "total_vulns": len(deduped),
            "high": high,
            "medium": medium,
            "low": low,
            "informational": info,
            "vuln_score": score,
            "has_high": high > 0,
            "has_reentrancy": cwe_counts.get("CWE-841", 0) > 0,
            "has_access_control": cwe_counts.get("CWE-284", 0) > 0,
            "has_unchecked_return": cwe_counts.get("CWE-252", 0) > 0,
            # CWE breakdown (top ones)
            "cwe_841_reentrancy": cwe_counts.get("CWE-841", 0),
            "cwe_284_access_control": cwe_counts.get("CWE-284", 0),
            "cwe_252_unchecked_return": cwe_counts.get("CWE-252", 0),
            "cwe_909_uninitialized": cwe_counts.get("CWE-909", 0),
            "cwe_829_timestamp": cwe_counts.get("CWE-829", 0),
            "cwe_477_tx_origin": cwe_counts.get("CWE-477", 0),
            "cwe_330_weak_random": cwe_counts.get("CWE-330", 0),
        })

        # Store detailed vulns for deep analysis
        for v in deduped:
            all_vulns.append({**v, "filepath": filepath, **meta})

    # Create dataframe
    df = pd.DataFrame(rows)

    output_path = Path(output_csv)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False)

    # Save all vulnerabilities
    with open(output_vulns, "w") as f:
        json.dump(all_vulns, f, indent=2)

    # Print summary
    print(f"\n{'='*60}")
    print("AGGREGATED RESULTS SUMMARY")
    print(f"{'='*60}")
    print(f"\nTotal contracts: {len(df)}")
    print(f"Total vulnerabilities (deduped): {df['total_vulns'].sum()}")
    print(f"Contracts with any vulnerability: {(df['total_vulns'] > 0).sum()} ({(df['total_vulns'] > 0).mean()*100:.1f}%)")
    print(f"Contracts with high severity: {df['has_high'].sum()} ({df['has_high'].mean()*100:.1f}%)")

    print(f"\nBy LLM:")
    for llm in sorted(df['llm'].unique()):
        llm_df = df[df['llm'] == llm]
        print(f"  {llm:14s}: mean={llm_df['total_vulns'].mean():.2f}, "
              f"high={llm_df['has_high'].mean()*100:.1f}%, "
              f"n={len(llm_df)}")

    print(f"\nBy prompt type:")
    for pt in sorted(df['prompt_type'].unique()):
        pt_df = df[df['prompt_type'] == pt]
        print(f"  {pt:14s}: mean={pt_df['total_vulns'].mean():.2f}, n={len(pt_df)}")

    print(f"\nResults saved to: {output_path}")
    print(f"Vulnerabilities saved to: {output_vulns}")

    return df


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Aggregate analysis results")
    parser.add_argument("--slither", default="analysis/results/slither_results.json")
    parser.add_argument("--mythril", default="analysis/results/mythril_results.json")
    parser.add_argument("--semgrep", default="analysis/results/semgrep_results.json")
    parser.add_argument("--dataset", default="dataset")
    parser.add_argument("--output", default="analysis/results/aggregated_results.csv")
    args = parser.parse_args()

    aggregate_results(args.slither, args.mythril, args.semgrep, args.dataset, args.output)
