"""
Run Mythril symbolic execution analysis on all generated contracts.
"""

import json
import subprocess
from pathlib import Path

from tqdm import tqdm


def analyze_contract(filepath: str, timeout: int = 300) -> dict:
    """
    Run Mythril on a single contract.

    Args:
        filepath: Path to the Solidity file
        timeout: Maximum time to wait for analysis (seconds)

    Returns:
        Dictionary containing Mythril findings
    """
    try:
        result = subprocess.run(
            ["myth", "analyze", filepath, "-o", "json"],
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
        return {"error": "mythril not installed", "success": False}
    except Exception as e:
        return {"error": str(e), "success": False}


def analyze_all_contracts(
    dataset_dir: str = "dataset",
    output_file: str = "analysis/mythril_results.json"
):
    """
    Run Mythril analysis on all contracts in the dataset.

    Args:
        dataset_dir: Directory containing generated contracts
        output_file: Path to save results
    """
    dataset_path = Path(dataset_dir)
    results = []

    # Find all Solidity files
    sol_files = list(dataset_path.rglob("*.sol"))
    print(f"Found {len(sol_files)} Solidity files")
    print("Note: Mythril is slow (~2-5 min per contract)")

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


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Run Mythril analysis")
    parser.add_argument("--dataset", type=str, default="dataset", help="Dataset directory")
    parser.add_argument("--output", type=str, default="analysis/mythril_results.json")

    args = parser.parse_args()
    analyze_all_contracts(args.dataset, args.output)
