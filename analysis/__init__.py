"""
Analysis module for security vulnerability detection in smart contracts.

Submodules:
    categorize          - CWE mapping and Slither finding categorization
    run_slither         - Slither static analysis runner
    run_mythril         - Mythril symbolic execution runner
    run_semgrep         - Semgrep custom rules runner
    aggregate_results   - Cross-tool result aggregation and deduplication
    statistical_analysis - Non-parametric statistical tests (Cliff's delta)
"""
