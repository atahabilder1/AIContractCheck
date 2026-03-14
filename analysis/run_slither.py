"""
Run Slither static analysis on all generated contracts.
Handles the new folder structure: dataset/<llm>/<type>/<category>/*.sol
"""

import json
import subprocess
import sys
import time
from pathlib import Path

from tqdm import tqdm

from .categorize import categorize_findings

# Path to project root (for slither config)
PROJECT_ROOT = Path(__file__).parent.parent
CONFIG_FILE = PROJECT_ROOT / "slither.config.json"


def parse_contract_path(sol_file: Path, dataset_dir: Path) -> dict:
    """Extract metadata from the contract's path."""
    rel = sol_file.relative_to(dataset_dir)
    parts = list(rel.parts)
    # Expected: <llm>/<type>/<category>/<filename>.sol
    if len(parts) >= 4:
        return {
            "llm": parts[0],
            "prompt_type": parts[1],
            "category": parts[2],
            "filename": parts[3],
        }
    return {
        "llm": parts[0] if len(parts) > 0 else "unknown",
        "prompt_type": "unknown",
        "category": "unknown",
        "filename": sol_file.name,
    }


def analyze_contract(filepath: str, timeout: int = 120) -> dict:
    """
    Run Slither on a single contract.

    Returns:
        Dictionary containing Slither findings
    """
    try:
        cmd = [
            "slither", filepath,
            "--json", "-",
            "--exclude-informational",
            "--exclude-optimization",
        ]
        if CONFIG_FILE.exists():
            cmd.extend(["--config-file", str(CONFIG_FILE)])

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(PROJECT_ROOT),
        )

        if result.stdout:
            try:
                return json.loads(result.stdout)
            except json.JSONDecodeError:
                return {"error": f"JSON parse error", "success": False}
        else:
            return {"error": result.stderr[:500] if result.stderr else "No output", "success": False}

    except subprocess.TimeoutExpired:
        return {"error": "timeout", "success": False}
    except FileNotFoundError:
        return {"error": "slither not installed", "success": False}
    except Exception as e:
        return {"error": str(e), "success": False}


def analyze_all_contracts(
    dataset_dir: str = "dataset",
    output_file: str = "analysis/results/slither_results.json",
    resume: bool = True,
):
    """Run Slither analysis on all contracts in the dataset."""
    dataset_path = Path(dataset_dir)
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Find all .sol files (skip raw_responses)
    sol_files = sorted([
        f for f in dataset_path.rglob("*.sol")
        if "raw_responses" not in str(f)
    ])
    print(f"Found {len(sol_files)} Solidity files")

    # Resume from previous run
    existing_results = {}
    if resume and output_path.exists():
        with open(output_path) as f:
            for r in json.load(f):
                existing_results[r["file"]] = r
        print(f"Resuming: {len(existing_results)} already analyzed")

    results = list(existing_results.values())
    analyzed_files = set(existing_results.keys())

    for sol_file in tqdm(sol_files, desc="Slither"):
        file_key = str(sol_file)
        if file_key in analyzed_files:
            continue

        meta = parse_contract_path(sol_file, dataset_path)
        analysis = analyze_contract(file_key)

        # Categorize findings with CWE mapping
        # Slither JSON has "error": null on success, so check for truthy error
        categorized = []
        if not analysis.get("error"):
            categorized = categorize_findings(analysis)

        results.append({
            "file": file_key,
            **meta,
            "findings": analysis,
            "categorized": categorized,
            "vuln_count": len(categorized),
        })

        # Save periodically (every 50 contracts)
        if len(results) % 50 == 0:
            with open(output_path, "w") as f:
                json.dump(results, f, indent=2)

    # Final save
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)

    # Summary
    successful = [r for r in results if not r["findings"].get("error")]
    failed = [r for r in results if r["findings"].get("error")]
    total_vulns = sum(r["vuln_count"] for r in results)

    print(f"\nSlither analysis complete:")
    print(f"  Analyzed: {len(successful)}/{len(results)}")
    print(f"  Failed:   {len(failed)}")
    print(f"  Total vulnerabilities found: {total_vulns}")
    print(f"  Results saved to: {output_path}")

    return results


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Run Slither analysis")
    parser.add_argument("--dataset", type=str, default="dataset")
    parser.add_argument("--output", type=str, default="analysis/results/slither_results.json")
    parser.add_argument("--no-resume", action="store_true")
    args = parser.parse_args()

    analyze_all_contracts(args.dataset, args.output, resume=not args.no_resume)
