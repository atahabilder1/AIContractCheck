"""
Run Slither on human baseline contracts with proper compiler version detection.
Automatically selects the correct solc version based on pragma.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from collections import Counter

DATASET_DIR = Path("dataset/human_baseline_forge")
OUTPUT_FILE = Path("analysis/human_baseline_results/slither_results.json")
PROGRESS_FILE = Path("analysis/human_baseline_results/slither_progress.json")


def detect_pragma_version(filepath):
    """Extract solidity version from pragma statement."""
    try:
        with open(filepath) as f:
            content = f.read()
    except:
        return "0.8.20"

    # Find pragma solidity statements
    pragmas = re.findall(r'pragma\s+solidity\s+([^;]+);', content)
    if not pragmas:
        return "0.8.20"

    pragma = pragmas[0].strip()

    # Extract version number
    version_match = re.search(r'(\d+\.\d+\.\d+)', pragma)
    if not version_match:
        return "0.8.20"

    version = version_match.group(1)

    # Map to installed versions
    major_minor = ".".join(version.split(".")[:2])
    version_map = {
        "0.5": "0.5.17",
        "0.6": "0.6.12",
        "0.7": "0.7.6",
        "0.8": "0.8.20",
    }

    # Try exact version first, then fall back to major.minor
    return version_map.get(major_minor, "0.8.20")


def run_slither_on_file(filepath, solc_version):
    """Run Slither on a single file with the specified solc version."""
    # Set solc version
    subprocess.run(
        ["solc-select", "use", solc_version],
        capture_output=True, timeout=10
    )

    try:
        result = subprocess.run(
            ["slither", str(filepath), "--json", "-"],
            capture_output=True, text=True, timeout=120,
            cwd=str(Path.cwd()),  # Run from project root for node_modules
        )

        if result.stdout:
            data = json.loads(result.stdout)
            success = data.get("success", False)
            detectors = data.get("results", {}).get("detectors", [])
            return {
                "success": success,
                "detectors": detectors,
                "error": None if success else "compilation_failed",
            }
    except subprocess.TimeoutExpired:
        return {"success": False, "detectors": [], "error": "timeout"}
    except json.JSONDecodeError:
        return {"success": False, "detectors": [], "error": "json_error"}
    except Exception as e:
        return {"success": False, "detectors": [], "error": str(e)}

    return {"success": False, "detectors": [], "error": "unknown"}


def categorize_finding(detector):
    """Map a Slither detector to our vulnerability categories."""
    check = detector.get("check", "")
    impact = detector.get("impact", "Informational")
    confidence = detector.get("confidence", "Low")

    return {
        "tool": "slither",
        "detector": check,
        "severity": impact,
        "confidence": confidence,
        "description": detector.get("description", "")[:200],
    }


def main():
    # Find all .sol files
    sol_files = sorted(DATASET_DIR.rglob("*.sol"))
    sol_files = [f for f in sol_files if "metadata" not in str(f) and "raw" not in str(f)]

    print(f"Found {len(sol_files)} Solidity files")

    # Load progress
    results = []
    done_files = set()
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE) as f:
            progress = json.load(f)
        results = progress.get("results", [])
        done_files = set(progress.get("done_files", []))
        print(f"Resuming: {len(done_files)} already done")

    compiled = 0
    failed = 0
    total_vulns = 0

    for i, filepath in enumerate(sol_files):
        fstr = str(filepath)
        if fstr in done_files:
            # Count existing
            for r in results:
                if r["file"] == fstr:
                    if r.get("compiled"):
                        compiled += 1
                    else:
                        failed += 1
                    total_vulns += r.get("vuln_count", 0)
                    break
            continue

        # Detect correct solc version
        solc_version = detect_pragma_version(filepath)

        rel_path = filepath.relative_to(DATASET_DIR)
        parts = list(rel_path.parts)
        category = parts[0] if parts else "unknown"

        print(f"[{i+1}/{len(sol_files)}] {rel_path} (solc {solc_version})")

        # Run Slither
        slither_result = run_slither_on_file(filepath, solc_version)

        entry = {
            "file": fstr,
            "category": category,
            "filename": filepath.name,
            "solc_version": solc_version,
            "compiled": slither_result["success"],
            "error": slither_result["error"],
            "findings": [categorize_finding(d) for d in slither_result["detectors"]],
            "vuln_count": len(slither_result["detectors"]),
        }

        results.append(entry)
        done_files.add(fstr)

        if slither_result["success"]:
            compiled += 1
            total_vulns += len(slither_result["detectors"])
            print(f"  OK: {len(slither_result['detectors'])} findings")
        else:
            failed += 1
            print(f"  FAILED: {slither_result['error']}")

        # Save progress every 10 contracts
        if (i + 1) % 10 == 0:
            with open(PROGRESS_FILE, "w") as f:
                json.dump({"results": results, "done_files": list(done_files)}, f)

    # Save final results
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_FILE, "w") as f:
        json.dump(results, f, indent=2)

    # Save progress
    with open(PROGRESS_FILE, "w") as f:
        json.dump({"results": results, "done_files": list(done_files)}, f)

    # Reset solc to default
    subprocess.run(["solc-select", "use", "0.8.20"], capture_output=True)

    print(f"\n{'='*60}")
    print(f"SLITHER ANALYSIS COMPLETE")
    print(f"{'='*60}")
    print(f"Total: {len(sol_files)}")
    print(f"Compiled: {compiled} ({compiled/len(sol_files)*100:.1f}%)")
    print(f"Failed: {failed} ({failed/len(sol_files)*100:.1f}%)")
    print(f"Total findings: {total_vulns}")

    # Per-category summary
    print(f"\nPer-category:")
    cat_stats = Counter()
    cat_compiled = Counter()
    for r in results:
        cat = r["category"]
        cat_stats[cat] += 1
        if r["compiled"]:
            cat_compiled[cat] += 1
    for cat in sorted(cat_stats.keys()):
        total = cat_stats[cat]
        comp = cat_compiled[cat]
        print(f"  {cat}: {comp}/{total} compiled ({comp/total*100:.0f}%)")


if __name__ == "__main__":
    main()
