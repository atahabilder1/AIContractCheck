"""
Master script to run the full analysis pipeline:
  1. Slither (fast, ~2-5 min total)
  2. Semgrep (fast, ~1-2 min total)
  3. Mythril (SLOW, ~60-150 hours for 1,800 contracts — use --skip-mythril if needed)
  4. Aggregate results across all tools
  5. Statistical analysis
  6. Generate figures
"""

import argparse
import sys
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Run full analysis pipeline")
    parser.add_argument("--dataset", default="dataset", help="Dataset directory")
    parser.add_argument("--skip-mythril", action="store_true",
                        help="Skip Mythril (very slow, symbolic execution)")
    parser.add_argument("--skip-figures", action="store_true",
                        help="Skip figure generation")
    parser.add_argument("--mythril-timeout", type=int, default=180,
                        help="Mythril per-contract timeout in seconds")
    parser.add_argument("--no-resume", action="store_true",
                        help="Don't resume from previous results")
    args = parser.parse_args()

    results_dir = "analysis/results"
    Path(results_dir).mkdir(parents=True, exist_ok=True)
    resume = not args.no_resume

    # ── Step 1: Slither ──────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("STEP 1: Running Slither static analysis")
    print("=" * 60)
    t0 = time.time()
    from analysis.run_slither import analyze_all_contracts as run_slither
    run_slither(
        dataset_dir=args.dataset,
        output_file=f"{results_dir}/slither_results.json",
        resume=resume,
    )
    print(f"Slither done in {time.time() - t0:.0f}s")

    # ── Step 2: Semgrep ──────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("STEP 2: Running Semgrep custom rules")
    print("=" * 60)
    t0 = time.time()
    from analysis.run_semgrep import analyze_all_contracts as run_semgrep
    run_semgrep(
        dataset_dir=args.dataset,
        output_file=f"{results_dir}/semgrep_results.json",
        resume=resume,
    )
    print(f"Semgrep done in {time.time() - t0:.0f}s")

    # ── Step 3: Mythril (optional) ───────────────────────────────────────
    if not args.skip_mythril:
        print("\n" + "=" * 60)
        print("STEP 3: Running Mythril symbolic execution (SLOW)")
        print("=" * 60)
        t0 = time.time()
        from analysis.run_mythril import analyze_all_contracts as run_mythril
        run_mythril(
            dataset_dir=args.dataset,
            output_file=f"{results_dir}/mythril_results.json",
            timeout=args.mythril_timeout,
            resume=resume,
        )
        print(f"Mythril done in {time.time() - t0:.0f}s")
    else:
        print("\n[Skipping Mythril]")

    # ── Step 4: Aggregate ────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("STEP 4: Aggregating results")
    print("=" * 60)
    from analysis.aggregate_results import aggregate_results
    aggregate_results(
        slither_file=f"{results_dir}/slither_results.json",
        mythril_file=f"{results_dir}/mythril_results.json",
        semgrep_file=f"{results_dir}/semgrep_results.json",
        dataset_dir=args.dataset,
        output_csv=f"{results_dir}/aggregated_results.csv",
        output_vulns=f"{results_dir}/all_vulnerabilities.json",
    )

    # ── Step 5: Statistics ───────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("STEP 5: Statistical analysis")
    print("=" * 60)
    from analysis.statistical_analysis import generate_paper_statistics
    generate_paper_statistics(
        csv_file=f"{results_dir}/aggregated_results.csv",
        output_file=f"{results_dir}/statistical_results.json",
    )

    # ── Step 6: Figures ──────────────────────────────────────────────────
    if not args.skip_figures:
        print("\n" + "=" * 60)
        print("STEP 6: Generating figures")
        print("=" * 60)
        from visualization.generate_figures import generate_all_figures
        generate_all_figures(
            csv_path=f"{results_dir}/aggregated_results.csv",
            output_dir="visualization/figures",
        )

    print("\n" + "=" * 60)
    print("PIPELINE COMPLETE")
    print("=" * 60)
    print(f"Results:    {results_dir}/aggregated_results.csv")
    print(f"Statistics: {results_dir}/statistical_results.json")
    print(f"Figures:    visualization/figures/")


if __name__ == "__main__":
    main()
