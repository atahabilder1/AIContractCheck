"""
Phase 6: Verify 3 LLM-specific vulnerability patterns.
1. Phantom Guards: modifiers with empty bodies (just _;)
2. Inherited Vulnerabilities: hand-rolled SafeMath without OZ imports
3. Context Degradation: higher vuln density in second half of large contracts
"""

import json
import re
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import mannwhitneyu


def detect_phantom_guards(filepath: str) -> list:
    """Find modifiers that contain only _; (no real logic)."""
    try:
        with open(filepath) as f:
            content = f.read()
    except FileNotFoundError:
        return []

    findings = []
    # Match modifier blocks - look for modifier keyword then find body
    pattern = r'modifier\s+(\w+)\s*\([^)]*\)\s*\{([^}]*)\}'
    for m in re.finditer(pattern, content):
        name = m.group(1)
        body = m.group(2).strip()
        # Phantom guard: body is just _; or whitespace + _;
        cleaned = re.sub(r'//[^\n]*', '', body).strip()  # remove comments
        if cleaned in ('_;', '_') or re.match(r'^\s*_;\s*$', cleaned):
            findings.append({
                "type": "phantom_guard",
                "modifier": name,
                "body": body.strip()[:100],
            })
    return findings


def detect_hand_rolled_safemath(filepath: str) -> list:
    """Find contracts that implement SafeMath-like functions without importing OZ."""
    try:
        with open(filepath) as f:
            content = f.read()
    except FileNotFoundError:
        return []

    findings = []
    has_oz_import = "@openzeppelin" in content

    # Look for hand-rolled SafeMath patterns
    safemath_patterns = [
        (r'function\s+safeAdd', "safeAdd"),
        (r'function\s+safeSub', "safeSub"),
        (r'function\s+safeMul', "safeMul"),
        (r'function\s+safeDiv', "safeDiv"),
        (r'library\s+SafeMath', "SafeMath library"),
        (r'using\s+SafeMath\s+for', "using SafeMath"),
        (r'require\s*\(\s*[a-z]\s*\+\s*[a-z]\s*>=\s*[a-z]', "manual overflow check"),
        (r'require\s*\(\s*[a-z]\s*<=\s*[a-z]\s*\+\s*[a-z]', "manual overflow check"),
    ]

    for pattern, desc in safemath_patterns:
        if re.search(pattern, content, re.IGNORECASE):
            findings.append({
                "type": "inherited_vulnerability",
                "pattern": desc,
                "has_oz_import": has_oz_import,
                "issue": "unnecessary" if not has_oz_import else "redundant with OZ",
            })

    # Solidity >=0.8.0 has built-in overflow checks, so SafeMath is unnecessary
    version_match = re.search(r'pragma\s+solidity\s+[\^>=]*\s*0\.8', content)
    if version_match and findings:
        for f in findings:
            f["solidity_08"] = True
            f["issue"] = "unnecessary (Solidity 0.8+ has built-in overflow checks)"

    return findings


def detect_context_degradation(filepath: str, slither_results: dict = None) -> dict:
    """Check if vulnerability density is higher in the second half of large contracts."""
    try:
        with open(filepath) as f:
            lines = f.readlines()
    except FileNotFoundError:
        return None

    total_lines = len(lines)
    if total_lines < 100:  # Only for contracts > 100 lines
        return None

    mid = total_lines // 2

    # Count code features in each half as proxy for complexity
    first_half = ''.join(lines[:mid])
    second_half = ''.join(lines[mid:])

    def count_risky_patterns(code):
        patterns = {
            "external_calls": len(re.findall(r'\.\w+\s*\(', code)),
            "state_changes_after_call": len(re.findall(r'\.call\{', code)),
            "tx_origin": len(re.findall(r'tx\.origin', code)),
            "delegatecall": len(re.findall(r'delegatecall', code)),
            "selfdestruct": len(re.findall(r'selfdestruct', code)),
            "assembly": len(re.findall(r'assembly\s*\{', code)),
            "unchecked": len(re.findall(r'unchecked\s*\{', code)),
        }
        return patterns

    first_risks = count_risky_patterns(first_half)
    second_risks = count_risky_patterns(second_half)

    first_total = sum(first_risks.values())
    second_total = sum(second_risks.values())

    return {
        "type": "context_degradation",
        "total_lines": total_lines,
        "first_half_risks": first_total,
        "second_half_risks": second_total,
        "degradation_ratio": second_total / first_total if first_total > 0 else float('inf') if second_total > 0 else 1.0,
        "first_half_detail": first_risks,
        "second_half_detail": second_risks,
    }


def run_pattern_verification(
    csv_file: str = "analysis/results/aggregated_results.csv",
    output_file: str = "analysis/results/pattern_verification.json",
):
    df = pd.read_csv(csv_file)
    if "compiled" in df.columns:
        df = df[df["compiled"]].copy()

    results = {
        "phantom_guards": {"findings": [], "per_llm": {}},
        "inherited_vulnerabilities": {"findings": [], "per_llm": {}},
        "context_degradation": {"per_llm": {}, "overall": {}},
    }

    print(f"Analyzing {len(df)} compiled contracts for LLM-specific patterns...\n")

    # ── 1. Phantom Guards ──
    print("=== PHANTOM GUARDS ===")
    phantom_per_llm = {}
    all_phantoms = []
    for _, row in df.iterrows():
        findings = detect_phantom_guards(row["filepath"])
        if findings:
            for f in findings:
                f["filepath"] = row["filepath"]
                f["llm"] = row["llm"]
            all_phantoms.extend(findings)

    for llm in sorted(df["llm"].unique()):
        llm_phantoms = [p for p in all_phantoms if p["llm"] == llm]
        llm_total = len(df[df["llm"] == llm])
        contracts_with = len(set(p["filepath"] for p in llm_phantoms))
        phantom_per_llm[llm] = {
            "count": len(llm_phantoms),
            "contracts_affected": contracts_with,
            "rate": round(contracts_with / llm_total, 4) if llm_total > 0 else 0,
        }
        print(f"  {llm:12s}: {len(llm_phantoms)} phantom guards in {contracts_with}/{llm_total} contracts ({contracts_with/llm_total*100:.1f}%)")

    results["phantom_guards"]["findings"] = all_phantoms[:50]  # sample
    results["phantom_guards"]["per_llm"] = phantom_per_llm
    results["phantom_guards"]["total"] = len(all_phantoms)

    # ── 2. Inherited Vulnerabilities (hand-rolled SafeMath) ──
    print("\n=== INHERITED VULNERABILITIES (Hand-rolled SafeMath) ===")
    safemath_per_llm = {}
    all_safemath = []
    for _, row in df.iterrows():
        findings = detect_hand_rolled_safemath(row["filepath"])
        if findings:
            for f in findings:
                f["filepath"] = row["filepath"]
                f["llm"] = row["llm"]
            all_safemath.extend(findings)

    for llm in sorted(df["llm"].unique()):
        llm_sm = [s for s in all_safemath if s["llm"] == llm]
        llm_total = len(df[df["llm"] == llm])
        contracts_with = len(set(s["filepath"] for s in llm_sm))
        safemath_per_llm[llm] = {
            "count": len(llm_sm),
            "contracts_affected": contracts_with,
            "rate": round(contracts_with / llm_total, 4) if llm_total > 0 else 0,
        }
        print(f"  {llm:12s}: {len(llm_sm)} patterns in {contracts_with}/{llm_total} contracts ({contracts_with/llm_total*100:.1f}%)")

    results["inherited_vulnerabilities"]["findings"] = all_safemath[:50]
    results["inherited_vulnerabilities"]["per_llm"] = safemath_per_llm
    results["inherited_vulnerabilities"]["total"] = len(all_safemath)

    # ── 3. Context Degradation ──
    print("\n=== CONTEXT DEGRADATION (>100 LOC contracts) ===")
    degradation_data = []
    for _, row in df.iterrows():
        result = detect_context_degradation(row["filepath"])
        if result:
            result["filepath"] = row["filepath"]
            result["llm"] = row["llm"]
            result["total_vulns"] = row["total_vulns"]
            degradation_data.append(result)

    print(f"  Contracts >100 LOC: {len(degradation_data)}")

    if degradation_data:
        deg_df = pd.DataFrame(degradation_data)
        # Overall: is second half riskier?
        ratios = deg_df["degradation_ratio"].replace([np.inf], np.nan).dropna()
        mean_ratio = float(ratios.mean())
        median_ratio = float(ratios.median())
        pct_degraded = float((ratios > 1.0).mean())

        results["context_degradation"]["overall"] = {
            "n_contracts": len(degradation_data),
            "mean_degradation_ratio": round(mean_ratio, 3),
            "median_degradation_ratio": round(median_ratio, 3),
            "pct_second_half_worse": round(pct_degraded, 4),
        }
        print(f"  Mean degradation ratio: {mean_ratio:.2f} (>1 = second half worse)")
        print(f"  Median ratio: {median_ratio:.2f}")
        print(f"  % where 2nd half worse: {pct_degraded*100:.1f}%")

        # Per-LLM
        for llm in sorted(deg_df["llm"].unique()):
            ldf = deg_df[deg_df["llm"] == llm]
            lr = ldf["degradation_ratio"].replace([np.inf], np.nan).dropna()
            if len(lr) > 0:
                results["context_degradation"]["per_llm"][llm] = {
                    "n": len(lr),
                    "mean_ratio": round(float(lr.mean()), 3),
                    "median_ratio": round(float(lr.median()), 3),
                    "pct_degraded": round(float((lr > 1.0).mean()), 4),
                }
                print(f"  {llm:12s}: n={len(lr):3d}, mean_ratio={lr.mean():.2f}, "
                      f"degraded={((lr > 1.0).mean()*100):.1f}%")

        # Correlation: degradation ratio vs vuln count
        valid = deg_df[["degradation_ratio", "total_vulns"]].replace([np.inf], np.nan).dropna()
        if len(valid) > 10:
            from scipy.stats import spearmanr
            rho, p = spearmanr(valid["degradation_ratio"], valid["total_vulns"])
            results["context_degradation"]["correlation"] = {
                "spearman_rho": round(float(rho), 4),
                "p_value": float(p),
            }
            print(f"\n  Correlation (degradation ratio vs vulns): rho={rho:.3f}, p={p:.4f}")

    # Save
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2, default=str)
    print(f"\nSaved to: {output_path}")
    return results


if __name__ == "__main__":
    run_pattern_verification()
