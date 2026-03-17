# Manual Validation Guidelines

## Purpose

This manual validation assesses the **precision** of automated vulnerability detection tools (Slither, Semgrep, Mythril) applied to LLM-generated smart contracts. The goal is to determine what fraction of reported findings are true vulnerabilities versus false positives, which is critical for the validity of our quantitative results.

We sample 120 LLM-generated contracts (15 per LLM, stratified by severity) and 30 human-written baseline contracts. For each contract, we review up to 3 findings.

## Reviewer Qualifications

Reviewers should have:
- Familiarity with Solidity and smart contract development
- Understanding of common vulnerability classes (reentrancy, access control, unchecked returns, timestamp dependence, tx.origin misuse)
- Ability to read static analysis tool output

## Review Process

For each row in the validation CSV:

1. **Open the contract source file** at the path in the `filepath` column (relative to the project root).
2. **Read the contract code** to understand its purpose and logic.
3. **For each finding (finding_1, finding_2, finding_3):**
   a. Read the `finding_N_tool`, `finding_N_detector`, `finding_N_severity`, and `finding_N_description` columns.
   b. Locate the relevant code section referenced in the description.
   c. Determine whether the finding represents a real vulnerability in context.
   d. Enter your verdict in the `reviewer_verdict_N` column.
4. **Add any notes** in the `reviewer_notes` column (optional but helpful for edge cases).

## Verdict Labels

Enter one of the following in each `reviewer_verdict_N` cell:

### TP (True Positive)
The finding identifies a **real, exploitable vulnerability** or a **genuine security concern** in the contract.

**Examples:**
- Reentrancy: A function sends ETH via `.call{value:}()` before updating state, and an attacker could re-enter to drain funds.
- Access control: A sensitive function (e.g., `withdraw`, `selfdestruct`, `setOwner`) has no access modifier and can be called by anyone.
- Unchecked return: A low-level `.call()` return value is ignored, and failure could lead to loss of funds.
- Timestamp dependence: `block.timestamp` is used in a way that miners could manipulate for profit (e.g., auction end time with significant value at stake).

### FP (False Positive)
The finding is **incorrect**, **irrelevant**, or **not exploitable** in the context of this contract.

**Examples:**
- Reentrancy reported but the function has a reentrancy guard (`nonReentrant` modifier) or follows checks-effects-interactions correctly.
- Timestamp dependence reported for a simple time check where miner manipulation is economically irrelevant (e.g., a cooldown timer with no value at stake).
- Access control finding on a function that is intentionally public (e.g., a view function, a public mint function by design).
- A finding about a pattern that is standard and safe in the specific Solidity version used.
- The detector flags dead code or unreachable paths.

### UN (Uncertain)
You **cannot confidently determine** whether the finding is a true or false positive.

**Use sparingly.** This is appropriate when:
- The contract logic is too complex or ambiguous to determine exploitability.
- The finding depends on external contract behavior that is not visible.
- The vulnerability is theoretical but exploitation is unclear.
- You are unsure whether the developer intended the behavior.

## Edge Cases

### Informational / Low-Severity Findings
- Even low-severity findings should be assessed. A "low" reentrancy-events finding may still be a real code smell.
- However, be lenient: if the finding is technically accurate but has no security impact, mark as **FP**.

### Contracts That Do Not Compile
- Some sampled contracts may not compile (compiled=False). These may still have Semgrep findings (which work on source text). Assess those findings based on the source code.

### Duplicate or Overlapping Findings
- If finding_2 and finding_3 describe the same underlying issue from different tools/detectors, assess each independently based on what that specific detector claims.

### Minimal or Trivial Contracts
- If a contract is trivially small (e.g., < 10 lines) and a finding is reported, assess whether the finding is meaningful in context.

### Empty Finding Columns
- If `finding_N_severity` is empty, skip that finding (leave the verdict empty too).

## Time Estimate

- **LLM contracts:** ~3-5 minutes per contract (120 contracts = ~6-10 hours total)
- **Human baseline:** ~5-7 minutes per contract (30 contracts = ~2.5-3.5 hours total)
- **Total per reviewer:** ~8.5-13.5 hours

It is recommended to review in sessions of 1-2 hours to maintain consistency.

## Inter-Rater Agreement

If two reviewers independently assess the same contracts, we compute **Cohen's kappa** to measure agreement:

```
kappa = (p_observed - p_expected) / (1 - p_expected)
```

Where:
- `p_observed` = fraction of findings where both reviewers agree (both TP or both FP)
- `p_expected` = expected agreement by chance

**Interpretation (Landis & Koch, 1977):**

| Kappa     | Interpretation     |
|-----------|--------------------|
| < 0.00    | Poor               |
| 0.00-0.20 | Slight             |
| 0.21-0.40 | Fair               |
| 0.41-0.60 | Moderate           |
| 0.61-0.80 | Substantial        |
| 0.81-1.00 | Almost perfect     |

For security research, we aim for **substantial** agreement (kappa > 0.61).

### Resolving Disagreements

When two reviewers disagree:
1. Both reviewers discuss the specific finding.
2. If consensus is reached, use the agreed verdict.
3. If no consensus, a third reviewer (or the lead author) makes the final call.
4. Report both the initial kappa and the final resolved precision.

## Running the Analysis

After filling in all verdicts:

```bash
# Single reviewer
python compute_results.py

# Two reviewers (second reviewer saves their verdicts in a separate CSV)
python compute_results.py --reviewer2 path/to/reviewer2_validation_sample.csv
```

This produces:
- Overall precision (TP / (TP + FP))
- Per-severity, per-LLM, per-tool, and per-detector precision
- Cohen's kappa (if two reviewers)
- Adjusted vulnerability counts (raw counts * precision rate)

## Output

Results are saved to `manual_validation/validation_results.json` and printed to the console.
