"""
Run Mythril symbolic execution on all generated contracts.
Handles the new folder structure: dataset/<llm>/<type>/<category>/*.sol
NOTE: Mythril is SLOW (~2-5 min per contract). 1,800 contracts = ~60-150 hours.
Consider running on a subset or using --timeout to limit.
"""

import json
import subprocess
import sys
from pathlib import Path

from tqdm import tqdm

PROJECT_ROOT = Path(__file__).parent.parent
OZ_NODE_MODULES = PROJECT_ROOT / "node_modules"


def parse_contract_path(sol_file: Path, dataset_dir: Path) -> dict:
    """Extract metadata from the contract's path."""
    rel = sol_file.relative_to(dataset_dir)
    parts = list(rel.parts)
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


def analyze_contract(filepath: str, timeout: int = 300, max_depth: int = 12) -> dict:
    """
    Run Mythril on a single contract.

    Returns:
        Dictionary containing Mythril findings
    """
    try:
        cmd = [
            "myth", "analyze", filepath,
            "-o", "json",
            "--max-depth", str(max_depth),
            "--execution-timeout", str(timeout),
        ]
        # Only add OZ include path if the contract imports from @openzeppelin
        if OZ_NODE_MODULES.exists():
            try:
                with open(filepath) as f:
                    source = f.read()
                if "@openzeppelin" in source:
                    cmd.extend([
                        "--solc-args",
                        f"--allow-paths . --include-path {OZ_NODE_MODULES}",
                    ])
            except Exception:
                pass

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout + 60,  # Extra buffer for startup
        )

        if result.stdout:
            try:
                return json.loads(result.stdout)
            except json.JSONDecodeError:
                return {"error": "JSON parse error", "success": False}
        else:
            stderr = result.stderr[:500] if result.stderr else "No output"
            return {"error": stderr, "success": False}

    except subprocess.TimeoutExpired:
        return {"error": "timeout", "success": False}
    except FileNotFoundError:
        return {"error": "mythril not installed", "success": False}
    except Exception as e:
        return {"error": str(e), "success": False}


def analyze_all_contracts(
    dataset_dir: str = "dataset",
    output_file: str = "analysis/results/mythril_results.json",
    timeout: int = 300,
    resume: bool = True,
    sample_file: str = None,
):
    """Run Mythril analysis on all contracts (or a sample) in the dataset."""
    dataset_path = Path(dataset_dir)
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if sample_file:
        with open(sample_file) as f:
            sol_files = sorted([Path(line.strip()) for line in f if line.strip()])
        print(f"Using sample file: {sample_file}")
    else:
        # Find all .sol files (skip raw_responses)
        sol_files = sorted([
            f for f in dataset_path.rglob("*.sol")
            if "raw_responses" not in str(f)
        ])
    print(f"Found {len(sol_files)} Solidity files")
    print(f"WARNING: Mythril is slow. Estimated time: {len(sol_files) * 3 // 60} - {len(sol_files) * 5 // 60} hours")

    # Resume from previous run
    existing_results = {}
    if resume and output_path.exists():
        with open(output_path) as f:
            for r in json.load(f):
                existing_results[r["file"]] = r
        print(f"Resuming: {len(existing_results)} already analyzed")

    results = list(existing_results.values())
    analyzed_files = set(existing_results.keys())

    for sol_file in tqdm(sol_files, desc="Mythril"):
        file_key = str(sol_file)
        if file_key in analyzed_files:
            continue

        meta = parse_contract_path(sol_file, dataset_path)
        analysis = analyze_contract(file_key, timeout=timeout)

        # Extract issues
        issues = analysis.get("issues", []) if not analysis.get("error") else []

        results.append({
            "file": file_key,
            **meta,
            "findings": analysis,
            "vuln_count": len(issues),
        })

        # Save periodically
        if len(results) % 20 == 0:
            with open(output_path, "w") as f:
                json.dump(results, f, indent=2)

    # Final save
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)

    successful = [r for r in results if not r["findings"].get("error")]
    failed = [r for r in results if r["findings"].get("error")]
    total_vulns = sum(r["vuln_count"] for r in results)

    print(f"\nMythril analysis complete:")
    print(f"  Analyzed: {len(successful)}/{len(results)}")
    print(f"  Failed:   {len(failed)}")
    print(f"  Total issues found: {total_vulns}")
    print(f"  Results saved to: {output_path}")

    return results


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Run Mythril analysis")
    parser.add_argument("--dataset", type=str, default="dataset")
    parser.add_argument("--output", type=str, default="analysis/results/mythril_results.json")
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--no-resume", action="store_true")
    parser.add_argument("--sample", type=str, default=None,
                        help="Path to file listing contracts to analyze (one per line)")
    args = parser.parse_args()

    analyze_all_contracts(args.dataset, args.output, args.timeout,
                          resume=not args.no_resume, sample_file=args.sample)
