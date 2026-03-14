"""
Run Semgrep with custom Solidity security rules on all generated contracts.
Handles the new folder structure: dataset/<llm>/<type>/<category>/*.sol
"""

import json
import subprocess
import sys
from pathlib import Path

from tqdm import tqdm

# Path to custom Solidity rules
RULES_DIR = Path(__file__).parent / "semgrep_rules"


def ensure_rules():
    """Create custom Semgrep rules for Solidity security analysis if they don't exist."""
    RULES_DIR.mkdir(parents=True, exist_ok=True)
    rules_file = RULES_DIR / "solidity_security.yaml"

    if rules_file.exists():
        return str(rules_file)

    rules = {
        "rules": [
            {
                "id": "reentrancy-state-after-call",
                "patterns": [
                    {"pattern": "(...).call{value: ...}(...); \n ... \n $VAR = ...;"},
                ],
                "message": "Potential reentrancy: state change after external call",
                "languages": ["solidity"],
                "severity": "ERROR",
                "metadata": {"cwe": "CWE-841", "category": "reentrancy"},
            },
            {
                "id": "tx-origin-auth",
                "pattern": "require(tx.origin == ...)",
                "message": "tx.origin used for authentication (use msg.sender instead)",
                "languages": ["solidity"],
                "severity": "ERROR",
                "metadata": {"cwe": "CWE-477", "category": "authentication"},
            },
            {
                "id": "unchecked-call-return",
                "patterns": [
                    {"pattern": "address($ADDR).call(...);"},
                    {"pattern": "$ADDR.call{...}(...);"},
                ],
                "pattern-not": "(bool $SUCCESS, ...) = ...",
                "message": "Unchecked return value of low-level call",
                "languages": ["solidity"],
                "severity": "WARNING",
                "metadata": {"cwe": "CWE-252", "category": "unchecked-return"},
            },
            {
                "id": "selfdestruct-usage",
                "pattern": "selfdestruct(...)",
                "message": "Contract uses selfdestruct which can be dangerous",
                "languages": ["solidity"],
                "severity": "WARNING",
                "metadata": {"cwe": "CWE-284", "category": "dangerous-function"},
            },
            {
                "id": "delegatecall-usage",
                "pattern": "delegatecall(...)",
                "message": "delegatecall usage detected - ensure input is trusted",
                "languages": ["solidity"],
                "severity": "WARNING",
                "metadata": {"cwe": "CWE-829", "category": "dangerous-call"},
            },
            {
                "id": "block-timestamp-dependence",
                "pattern": "block.timestamp",
                "message": "Dependence on block.timestamp which can be manipulated by miners",
                "languages": ["solidity"],
                "severity": "WARNING",
                "metadata": {"cwe": "CWE-829", "category": "timestamp"},
            },
            {
                "id": "unprotected-ether-withdrawal",
                "patterns": [
                    {"pattern": "function withdraw(...) $VISIBILITY { ... $ADDR.transfer(...); ... }"},
                ],
                "pattern-not-inside": "function withdraw(...) $VISIBILITY { ... require(...); ... }",
                "message": "Potential unprotected ether withdrawal",
                "languages": ["solidity"],
                "severity": "ERROR",
                "metadata": {"cwe": "CWE-284", "category": "access-control"},
            },
            {
                "id": "weak-randomness",
                "patterns": [
                    {"pattern": "keccak256(abi.encodePacked(block.timestamp, ...))"},
                    {"pattern": "keccak256(abi.encodePacked(..., block.difficulty, ...))"},
                    {"pattern": "keccak256(abi.encodePacked(..., block.number, ...))"},
                ],
                "message": "Weak randomness source - block variables are predictable",
                "languages": ["solidity"],
                "severity": "WARNING",
                "metadata": {"cwe": "CWE-330", "category": "randomness"},
            },
            {
                "id": "empty-modifier",
                "pattern": "modifier $NAME() { _; }",
                "message": "Empty modifier - may be a phantom guard pattern",
                "languages": ["solidity"],
                "severity": "WARNING",
                "metadata": {"cwe": "CWE-841", "category": "phantom-guard"},
            },
        ]
    }

    import yaml
    with open(rules_file, "w") as f:
        yaml.dump(rules, f, default_flow_style=False, sort_keys=False)

    print(f"Created Semgrep rules at: {rules_file}")
    return str(rules_file)


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


def analyze_contract(filepath: str, rules_path: str, timeout: int = 60) -> dict:
    """Run Semgrep on a single contract."""
    try:
        result = subprocess.run(
            [
                "semgrep",
                "--config", rules_path,
                "--json",
                "--no-git-ignore",
                "--quiet",
                filepath,
            ],
            capture_output=True,
            text=True,
            timeout=timeout,
        )

        if result.stdout:
            try:
                return json.loads(result.stdout)
            except json.JSONDecodeError:
                return {"error": "JSON parse error", "success": False}
        else:
            return {"results": [], "errors": []}

    except subprocess.TimeoutExpired:
        return {"error": "timeout", "success": False}
    except FileNotFoundError:
        return {"error": "semgrep not installed", "success": False}
    except Exception as e:
        return {"error": str(e), "success": False}


def analyze_all_contracts(
    dataset_dir: str = "dataset",
    output_file: str = "analysis/results/semgrep_results.json",
    resume: bool = True,
):
    """Run Semgrep analysis on all contracts in the dataset."""
    rules_path = ensure_rules()
    dataset_path = Path(dataset_dir)
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    sol_files = sorted([
        f for f in dataset_path.rglob("*.sol")
        if "raw_responses" not in str(f)
    ])
    print(f"Found {len(sol_files)} Solidity files")

    existing_results = {}
    if resume and output_path.exists():
        with open(output_path) as f:
            for r in json.load(f):
                existing_results[r["file"]] = r
        print(f"Resuming: {len(existing_results)} already analyzed")

    results = list(existing_results.values())
    analyzed_files = set(existing_results.keys())

    for sol_file in tqdm(sol_files, desc="Semgrep"):
        file_key = str(sol_file)
        if file_key in analyzed_files:
            continue

        meta = parse_contract_path(sol_file, dataset_path)
        analysis = analyze_contract(file_key, rules_path)

        findings = analysis.get("results", []) if not analysis.get("error") else []

        results.append({
            "file": file_key,
            **meta,
            "findings": analysis,
            "vuln_count": len(findings),
        })

        if len(results) % 100 == 0:
            with open(output_path, "w") as f:
                json.dump(results, f, indent=2)

    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)

    total_vulns = sum(r["vuln_count"] for r in results)
    print(f"\nSemgrep analysis complete:")
    print(f"  Analyzed: {len(results)}")
    print(f"  Total findings: {total_vulns}")
    print(f"  Results saved to: {output_path}")

    return results


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Run Semgrep analysis")
    parser.add_argument("--dataset", type=str, default="dataset")
    parser.add_argument("--output", type=str, default="analysis/results/semgrep_results.json")
    parser.add_argument("--no-resume", action="store_true")
    args = parser.parse_args()

    analyze_all_contracts(args.dataset, args.output, resume=not args.no_resume)
