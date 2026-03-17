"""
Run analysis pipeline on human baseline contracts.
Outputs to analysis/human_baseline_results/ to avoid overwriting LLM results.
"""

import sys
import time
from pathlib import Path


def main():
    dataset_dir = "dataset/human_baseline"
    results_dir = "analysis/human_baseline_results"
    Path(results_dir).mkdir(parents=True, exist_ok=True)

    # ── Step 1: Slither ──────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("STEP 1: Running Slither on human baseline")
    print("=" * 60)
    t0 = time.time()
    from analysis.run_slither import analyze_all_contracts as run_slither
    run_slither(
        dataset_dir=dataset_dir,
        output_file=f"{results_dir}/slither_results.json",
        resume=True,
    )
    print(f"Slither done in {time.time() - t0:.0f}s")

    # ── Step 2: Semgrep ──────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("STEP 2: Running Semgrep on human baseline")
    print("=" * 60)
    t0 = time.time()
    from analysis.run_semgrep import analyze_all_contracts as run_semgrep
    run_semgrep(
        dataset_dir=dataset_dir,
        output_file=f"{results_dir}/semgrep_results.json",
        resume=True,
    )
    print(f"Semgrep done in {time.time() - t0:.0f}s")

    # ── Skip Mythril (too slow, not needed for baseline comparison) ─────
    print("\n[Skipping Mythril for human baseline]")

    # ── Step 3: Aggregate ────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("STEP 3: Aggregating human baseline results")
    print("=" * 60)
    from analysis.aggregate_results import aggregate_results
    aggregate_results(
        slither_file=f"{results_dir}/slither_results.json",
        mythril_file=f"{results_dir}/mythril_results.json",  # won't exist, that's ok
        semgrep_file=f"{results_dir}/semgrep_results.json",
        dataset_dir=dataset_dir,
        output_csv=f"{results_dir}/aggregated_results.csv",
        output_vulns=f"{results_dir}/all_vulnerabilities.json",
    )

    # ── Step 4: Quick summary ────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("HUMAN BASELINE ANALYSIS COMPLETE")
    print("=" * 60)
    print(f"Results: {results_dir}/aggregated_results.csv")

    # Print quick comparison stats
    import csv
    with open(f"{results_dir}/aggregated_results.csv") as f:
        rows = list(csv.DictReader(f))

    total = len(rows)
    compiled = [r for r in rows if r.get('compiled', '').lower() == 'true']
    n_compiled = len(compiled)

    if n_compiled > 0:
        vulns = [int(r.get('total_vulnerabilities', 0)) for r in compiled]
        has_vuln = sum(1 for v in vulns if v > 0)
        mean_v = sum(vulns) / len(vulns)
        total_v = sum(vulns)

        print(f"\n  Total contracts: {total}")
        print(f"  Compiled: {n_compiled} ({n_compiled/total*100:.1f}%)")
        print(f"  Total vulnerabilities: {total_v}")
        print(f"  With vulnerabilities: {has_vuln}/{n_compiled} ({has_vuln/n_compiled*100:.1f}%)")
        print(f"  Mean vulns per contract: {mean_v:.2f}")
    else:
        print(f"\n  Total contracts: {total}")
        print(f"  No compiled contracts found")


if __name__ == "__main__":
    main()
