#!/usr/bin/env python3
"""
Scan 2,400 LLM-generated contracts for three vulnerability patterns:
1. Phantom Guards - modifiers with only `_;` and no real logic
2. Inherited Vulnerabilities - SafeMath on Solidity 0.8+
3. Context Window Degradation - risky pattern density first-half vs second-half
"""

import os
import re
import json
from collections import defaultdict
from pathlib import Path

DATASET_DIR = "/home/anik/code/AIContractCheck/dataset"
LLMS = ["claude", "codellama", "codestral", "deepseek", "gemini", "gpt4o", "gpt5", "qwen"]


def find_all_sol_files():
    """Find all .sol files grouped by LLM."""
    files_by_llm = {}
    for llm in LLMS:
        llm_dir = os.path.join(DATASET_DIR, llm)
        sol_files = []
        for root, dirs, files in os.walk(llm_dir):
            for f in files:
                if f.endswith(".sol"):
                    sol_files.append(os.path.join(root, f))
        files_by_llm[llm] = sorted(sol_files)
    return files_by_llm


def read_file(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except Exception:
        return ""


# ============================================================
# 1. PHANTOM GUARDS
# ============================================================
def detect_phantom_guards(content):
    """
    Find modifiers whose body contains only `_;` with no actual guard logic.
    We look for modifier declarations, extract their body, and check if
    the body (ignoring whitespace/comments) contains only `_;`.
    """
    phantom_modifiers = []

    # Match modifier declarations - need to handle nested braces
    # Pattern: modifier <name>(<params>?) {  ... }
    modifier_pattern = re.compile(
        r'modifier\s+(\w+)\s*\([^)]*\)\s*\{',
        re.DOTALL
    )

    for match in modifier_pattern.finditer(content):
        name = match.group(1)
        start = match.end()  # position after opening {

        # Find matching closing brace
        depth = 1
        pos = start
        while pos < len(content) and depth > 0:
            if content[pos] == '{':
                depth += 1
            elif content[pos] == '}':
                depth -= 1
            pos += 1

        if depth == 0:
            body = content[start:pos-1]  # content between { and }

            # Strip comments
            body_clean = re.sub(r'//[^\n]*', '', body)
            body_clean = re.sub(r'/\*.*?\*/', '', body_clean, flags=re.DOTALL)

            # Strip whitespace
            body_stripped = body_clean.strip()

            # Check if body is just `_;` or `_` (the placeholder with no guards)
            if body_stripped in ('_;', '_'):
                phantom_modifiers.append(name)
            # Also check: body might have newlines but still just _;
            elif re.fullmatch(r'\s*_\s*;?\s*', body_clean):
                phantom_modifiers.append(name)

    return phantom_modifiers


# ============================================================
# 2. INHERITED VULNERABILITIES (SafeMath on 0.8+)
# ============================================================
def detect_inherited_safemath(content):
    """
    Detect contracts that use pragma solidity ^0.8.x (or >=0.8.x)
    AND contain SafeMath usage (library SafeMath or using SafeMath).
    """
    # Check for 0.8+ pragma
    pragma_08 = re.search(
        r'pragma\s+solidity\s+[\^>=]*\s*0\.8', content
    )
    if not pragma_08:
        return False

    # Check for SafeMath usage
    has_safemath = bool(
        re.search(r'library\s+SafeMath', content) or
        re.search(r'using\s+SafeMath', content)
    )

    return has_safemath


# ============================================================
# 3. CONTEXT WINDOW DEGRADATION
# ============================================================
RISKY_PATTERNS = [
    re.compile(r'\.call\s*[\({]'),       # external .call
    re.compile(r'\bassembly\s*\{'),       # inline assembly
    re.compile(r'\bunchecked\s*\{'),      # unchecked blocks
    re.compile(r'\bdelegatecall\s*\('),   # delegatecall
]


def count_risky_patterns(text):
    """Count occurrences of risky patterns in text."""
    total = 0
    for pat in RISKY_PATTERNS:
        total += len(pat.findall(text))
    return total


def detect_context_degradation(content):
    """
    For contracts >100 LOC, compare risky pattern density
    in first half vs second half.
    Returns (loc, first_half_count, second_half_count, first_density, second_density)
    or None if <100 LOC.
    """
    lines = content.split('\n')
    loc = len(lines)
    if loc <= 100:
        return None

    mid = loc // 2
    first_half = '\n'.join(lines[:mid])
    second_half = '\n'.join(lines[mid:])

    first_count = count_risky_patterns(first_half)
    second_count = count_risky_patterns(second_half)

    # Density = count per 100 lines
    first_density = (first_count / mid) * 100 if mid > 0 else 0
    second_density = (second_count / (loc - mid)) * 100 if (loc - mid) > 0 else 0

    return (loc, first_count, second_count, first_density, second_density)


# ============================================================
# MAIN ANALYSIS
# ============================================================
def main():
    files_by_llm = find_all_sol_files()

    total_files = sum(len(v) for v in files_by_llm.values())
    print(f"Total contracts found: {total_files}")
    print("=" * 70)

    # --- Pattern 1: Phantom Guards ---
    print("\n" + "=" * 70)
    print("PATTERN 1: PHANTOM GUARDS")
    print("Modifiers containing only `_;` with no actual guard logic")
    print("=" * 70)

    phantom_by_llm = {}
    phantom_examples = {}
    phantom_total_contracts = 0
    phantom_total_modifiers = 0

    for llm in LLMS:
        contracts_with_phantom = 0
        modifier_count = 0
        examples = []

        for fpath in files_by_llm[llm]:
            content = read_file(fpath)
            phantoms = detect_phantom_guards(content)
            if phantoms:
                contracts_with_phantom += 1
                modifier_count += len(phantoms)
                if len(examples) < 3:
                    examples.append((fpath, phantoms))

        phantom_by_llm[llm] = (contracts_with_phantom, modifier_count)
        phantom_examples[llm] = examples
        phantom_total_contracts += contracts_with_phantom
        phantom_total_modifiers += modifier_count

    print(f"\nTotal contracts with phantom guards: {phantom_total_contracts} / {total_files}")
    print(f"Total phantom modifier instances: {phantom_total_modifiers}")
    print(f"\nPer-LLM breakdown:")
    print(f"  {'LLM':<15} {'Contracts':>10} {'Modifiers':>10} {'Rate':>8}")
    print(f"  {'-'*45}")
    for llm in LLMS:
        c, m = phantom_by_llm[llm]
        rate = c / len(files_by_llm[llm]) * 100
        print(f"  {llm:<15} {c:>10} {m:>10} {rate:>7.1f}%")

    print(f"\nExample files:")
    for llm in LLMS:
        for fpath, mods in phantom_examples[llm]:
            print(f"  [{llm}] {fpath}")
            print(f"         Phantom modifiers: {', '.join(mods)}")

    # --- Pattern 2: Inherited Vulnerabilities (SafeMath on 0.8+) ---
    print("\n" + "=" * 70)
    print("PATTERN 2: INHERITED VULNERABILITIES (SafeMath on Solidity 0.8+)")
    print("Contracts that manually use SafeMath despite built-in overflow checks")
    print("=" * 70)

    safemath_by_llm = {}
    safemath_examples = {}
    safemath_total = 0

    # Also track: how many are 0.8+ total
    pragma08_by_llm = {}

    for llm in LLMS:
        count = 0
        pragma08_count = 0
        examples = []

        for fpath in files_by_llm[llm]:
            content = read_file(fpath)

            if re.search(r'pragma\s+solidity\s+[\^>=]*\s*0\.8', content):
                pragma08_count += 1

            if detect_inherited_safemath(content):
                count += 1
                if len(examples) < 3:
                    examples.append(fpath)

        safemath_by_llm[llm] = count
        pragma08_by_llm[llm] = pragma08_count
        safemath_examples[llm] = examples
        safemath_total += count

    total_pragma08 = sum(pragma08_by_llm.values())
    print(f"\nTotal 0.8+ contracts: {total_pragma08} / {total_files}")
    print(f"Total with unnecessary SafeMath: {safemath_total} / {total_pragma08} ({safemath_total/total_pragma08*100:.1f}% of 0.8+ contracts)")
    print(f"\nPer-LLM breakdown:")
    print(f"  {'LLM':<15} {'0.8+ Total':>10} {'SafeMath':>10} {'Rate':>8}")
    print(f"  {'-'*45}")
    for llm in LLMS:
        n08 = pragma08_by_llm[llm]
        nsm = safemath_by_llm[llm]
        rate = (nsm / n08 * 100) if n08 > 0 else 0
        print(f"  {llm:<15} {n08:>10} {nsm:>10} {rate:>7.1f}%")

    print(f"\nExample files:")
    for llm in LLMS:
        for fpath in safemath_examples[llm]:
            print(f"  [{llm}] {fpath}")

    # --- Pattern 3: Context Window Degradation ---
    print("\n" + "=" * 70)
    print("PATTERN 3: CONTEXT WINDOW DEGRADATION")
    print("Risky pattern density: first half vs second half (contracts >100 LOC)")
    print("Risky patterns: .call, assembly{}, unchecked{}, delegatecall()")
    print("=" * 70)

    degradation_by_llm = {}
    contracts_over_100 = {}
    # For aggregate stats
    all_first_densities = defaultdict(list)
    all_second_densities = defaultdict(list)
    all_first_counts = defaultdict(list)
    all_second_counts = defaultdict(list)

    # Track contracts where second half has MORE risky patterns
    more_in_second = defaultdict(int)
    more_in_first = defaultdict(int)
    equal_halves = defaultdict(int)

    degradation_examples = {}

    for llm in LLMS:
        over100 = 0
        examples = []

        for fpath in files_by_llm[llm]:
            content = read_file(fpath)
            result = detect_context_degradation(content)
            if result is None:
                continue

            over100 += 1
            loc, fc, sc, fd, sd = result

            all_first_counts[llm].append(fc)
            all_second_counts[llm].append(sc)
            all_first_densities[llm].append(fd)
            all_second_densities[llm].append(sd)

            if sc > fc:
                more_in_second[llm] += 1
            elif fc > sc:
                more_in_first[llm] += 1
            else:
                equal_halves[llm] += 1

            # Collect extreme examples where second >> first
            if sc > fc and sc >= 2 and len(examples) < 3:
                examples.append((fpath, loc, fc, sc, fd, sd))

        contracts_over_100[llm] = over100
        degradation_examples[llm] = examples

    total_over100 = sum(contracts_over_100.values())
    print(f"\nContracts >100 LOC: {total_over100} / {total_files}")

    # Aggregate across all LLMs
    all_first = []
    all_second = []
    for llm in LLMS:
        all_first.extend(all_first_densities[llm])
        all_second.extend(all_second_densities[llm])

    if all_first:
        avg_first = sum(all_first) / len(all_first)
        avg_second = sum(all_second) / len(all_second)
        print(f"\nOverall avg risky pattern density (per 100 LOC):")
        print(f"  First half:  {avg_first:.2f}")
        print(f"  Second half: {avg_second:.2f}")
        print(f"  Ratio (2nd/1st): {avg_second/avg_first:.2f}x" if avg_first > 0 else "")

    total_more_second = sum(more_in_second.values())
    total_more_first = sum(more_in_first.values())
    total_equal = sum(equal_halves.values())
    print(f"\n  Contracts with MORE risky patterns in 2nd half: {total_more_second} ({total_more_second/total_over100*100:.1f}%)")
    print(f"  Contracts with MORE risky patterns in 1st half: {total_more_first} ({total_more_first/total_over100*100:.1f}%)")
    print(f"  Contracts with equal halves: {total_equal} ({total_equal/total_over100*100:.1f}%)")

    print(f"\nPer-LLM breakdown:")
    print(f"  {'LLM':<15} {'>100LOC':>8} {'AvgDens1st':>11} {'AvgDens2nd':>11} {'Ratio':>7} {'More2nd':>8} {'More1st':>8}")
    print(f"  {'-'*70}")
    for llm in LLMS:
        n = contracts_over_100[llm]
        if n == 0:
            print(f"  {llm:<15} {n:>8}  {'N/A':>10} {'N/A':>10} {'N/A':>6} {'N/A':>7} {'N/A':>7}")
            continue
        avg_f = sum(all_first_densities[llm]) / len(all_first_densities[llm])
        avg_s = sum(all_second_densities[llm]) / len(all_second_densities[llm])
        ratio = avg_s / avg_f if avg_f > 0 else float('inf')
        ms = more_in_second[llm]
        mf = more_in_first[llm]
        print(f"  {llm:<15} {n:>8} {avg_f:>10.2f} {avg_s:>10.2f} {ratio:>6.2f}x {ms:>7} {mf:>7}")

    print(f"\nExample files (where second half has notably more risky patterns):")
    for llm in LLMS:
        for fpath, loc, fc, sc, fd, sd in degradation_examples[llm]:
            print(f"  [{llm}] {fpath}")
            print(f"         LOC={loc}, 1st_half={fc} ({fd:.1f}/100LOC), 2nd_half={sc} ({sd:.1f}/100LOC)")

    # --- Summary stats with raw counts too ---
    print("\n" + "=" * 70)
    print("CONTEXT DEGRADATION: RAW COUNTS (not density)")
    print("=" * 70)
    print(f"\n  {'LLM':<15} {'AvgCount1st':>12} {'AvgCount2nd':>12}")
    print(f"  {'-'*40}")
    for llm in LLMS:
        if contracts_over_100[llm] == 0:
            continue
        avg_fc = sum(all_first_counts[llm]) / len(all_first_counts[llm])
        avg_sc = sum(all_second_counts[llm]) / len(all_second_counts[llm])
        print(f"  {llm:<15} {avg_fc:>11.2f} {avg_sc:>11.2f}")


if __name__ == "__main__":
    main()
