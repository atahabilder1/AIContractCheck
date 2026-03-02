"""
Run Slither static analysis on all generated contracts.
"""

import json
import subprocess
from pathlib import Path

from tqdm import tqdm


def analyze_contract(filepath: str, timeout: int = 60) -> dict:
    """
    Run Slither on a single contract.

    Args:
        filepath: Path to the Solidity file
        timeout: Maximum time to wait for analysis (seconds)

    Returns:
        Dictionary containing Slither findings
    """
    try:
        result = subprocess.run(
            ["slither", filepath, "--json", "-"],
            capture_output=True,
            text=True,
            timeout=timeout
        )

        if result.stdout:
            return json.loads(result.stdout)
        else:
            return {"error": result.stderr or "No output", "success": False}

    except subprocess.TimeoutExpired:
        return {"error": "timeout", "success": False}
    except json.JSONDecodeError as e:
        return {"error": f"JSON parse error: {e}", "success": False}
    except FileNotFoundError:
        return {"error": "slither not installed", "success": False}
    except Exception as e:
        return {"error": str(e), "success": False}


def analyze_all_contracts(
    dataset_dir: str = "dataset",
    output_file: str = "analysis/slither_results.json"
):
    """
    Run Slither analysis on all contracts in the dataset.

    Args:
        dataset_dir: Directory containing generated contracts
        output_file: Path to save results
    """
    dataset_path = Path(dataset_dir)
    results = []

    # Find all Solidity files
    sol_files = list(dataset_path.rglob("*.sol"))
    print(f"Found {len(sol_files)} Solidity files")

    for sol_file in tqdm(sol_files, desc="Analyzing contracts"):
        analysis = analyze_contract(str(sol_file))

        results.append({
            "file": str(sol_file),
            "llm": sol_file.parent.name,
            "filename": sol_file.name,
            "findings": analysis
        })

    # Save results
    output_path = Path(output_file)
    output_path.parent.mkdir(exist_ok=True)

    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)

    # Print summary
    successful = [r for r in results if "error" not in r["findings"]]
    failed = [r for r in results if "error" in r["findings"]]

    print(f"\nAnalysis complete:")
    print(f"  Successful: {len(successful)}")
    print(f"  Failed: {len(failed)}")
    print(f"  Results saved to: {output_path}")

    return results


def summarize_findings(results_file: str = "analysis/slither_results.json"):
    """Generate a summary of Slither findings."""
    with open(results_file) as f:
        results = json.load(f)

    summary = {
        "total_contracts": len(results),
        "by_llm": {},
        "by_severity": {"High": 0, "Medium": 0, "Low": 0, "Informational": 0},
        "by_detector": {}
    }

    for result in results:
        llm = result["llm"]
        findings = result.get("findings", {})

        if llm not in summary["by_llm"]:
            summary["by_llm"][llm] = {
                "total": 0,
                "vulnerabilities": 0,
                "by_severity": {"High": 0, "Medium": 0, "Low": 0, "Informational": 0}
            }

        summary["by_llm"][llm]["total"] += 1

        # Extract detectors from findings
        detectors = findings.get("results", {}).get("detectors", [])
        for detector in detectors:
            severity = detector.get("impact", "Unknown")
            check = detector.get("check", "unknown")

            summary["by_llm"][llm]["vulnerabilities"] += 1
            if severity in summary["by_severity"]:
                summary["by_severity"][severity] += 1
                summary["by_llm"][llm]["by_severity"][severity] += 1

            summary["by_detector"][check] = summary["by_detector"].get(check, 0) + 1

    return summary


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Run Slither analysis")
    parser.add_argument("--dataset", type=str, default="dataset", help="Dataset directory")
    parser.add_argument("--output", type=str, default="analysis/slither_results.json")
    parser.add_argument("--summary", action="store_true", help="Generate summary only")

    args = parser.parse_args()

    if args.summary:
        summary = summarize_findings(args.output)
        print(json.dumps(summary, indent=2))
    else:
        analyze_all_contracts(args.dataset, args.output)
