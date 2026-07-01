"""
Mitigation Experiment: Test whether security-enhanced prompts reduce vulnerability rates.

Sends 20 diverse prompts with prepended security instructions to an LLM,
then compares Slither results against the original (unenhanced) GPT-4o generations.

Usage:
    python run_mitigation_test.py                   # Use GPT-4o (default)
    python run_mitigation_test.py --use-anthropic    # Use Claude 3.5 Sonnet (fallback)
"""

import argparse
import csv
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

# ── Config ───────────────────────────────────────────────────────────────────

SYSTEM_PROMPT = """You are a Solidity smart contract developer.
Generate only the Solidity code, no explanations.
Always include the SPDX license identifier and pragma statement."""

SECURITY_PREFIX = """IMPORTANT SECURITY REQUIREMENTS: Follow these security best practices:
- Use the checks-effects-interactions pattern to prevent reentrancy
- Validate all function inputs (zero address checks, bounds checking)
- Use OpenZeppelin's ReentrancyGuard for functions that make external calls
- Always check return values of external calls
- Implement proper access control with modifiers
- Avoid using block.timestamp for critical logic
- Use SafeERC20 for token transfers

"""

# 20 diverse prompt IDs: one per category, rotating complexity
SELECTED_IDS = [0, 16, 32, 48, 64, 75, 91, 107, 123, 139,
                150, 166, 182, 198, 214, 225, 241, 257, 273, 289]

OUTPUT_DIR = Path("dataset/mitigation_test")
RESULTS_FILE = Path("analysis/results/mitigation_results.json")


# ── LLM Backends ─────────────────────────────────────────────────────────────

def generate_openai(prompt: str, system: str) -> str:
    """Generate using GPT-4o via OpenAI API."""
    from openai import OpenAI
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY not set in .env")
    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": prompt}
        ],
        temperature=0.7,
        max_tokens=4000
    )
    return response.choices[0].message.content


def generate_anthropic(prompt: str, system: str) -> str:
    """Generate using Claude 3.5 Sonnet via Anthropic API."""
    import anthropic
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY not set in .env")
    client = anthropic.Anthropic(api_key=api_key)
    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4000,
        temperature=0.7,
        system=system,
        messages=[{"role": "user", "content": prompt}]
    )
    return response.content[0].text


# ── Helpers ──────────────────────────────────────────────────────────────────

def extract_solidity_code(response: str) -> str:
    """Extract Solidity code from LLM response, stripping markdown wrappers."""
    if not response:
        return ""
    if "```solidity" in response:
        start = response.find("```solidity") + len("```solidity")
        end = response.find("```", start)
        if end != -1:
            return response[start:end].strip()
    if "```" in response:
        start = response.find("```") + 3
        newline = response.find("\n", start)
        if newline != -1 and (newline - start) < 20:
            start = newline + 1
        end = response.find("```", start)
        if end != -1:
            return response[start:end].strip()
    return response.strip()


def run_slither(sol_path: str) -> dict:
    """Run Slither on a Solidity file and return parsed JSON results."""
    try:
        result = subprocess.run(
            ["slither", sol_path, "--json", "-",
             "--exclude-informational", "--exclude-optimization"],
            capture_output=True, text=True, timeout=120
        )
        # Slither outputs JSON to stdout when using --json -
        if result.stdout.strip():
            data = json.loads(result.stdout)
            detectors = data.get("results", {}).get("detectors", [])
            return {
                "compiled": data.get("success", True),
                "detectors": detectors,
                "total_vulns": len(detectors),
                "high": sum(1 for d in detectors if d.get("impact") == "High"),
                "medium": sum(1 for d in detectors if d.get("impact") == "Medium"),
                "low": sum(1 for d in detectors if d.get("impact") == "Low"),
            }
        else:
            return {"compiled": False, "detectors": [], "total_vulns": 0,
                    "high": 0, "medium": 0, "low": 0,
                    "error": result.stderr[:500] if result.stderr else "No output"}
    except subprocess.TimeoutExpired:
        return {"compiled": False, "detectors": [], "total_vulns": 0,
                "high": 0, "medium": 0, "low": 0, "error": "timeout"}
    except Exception as e:
        return {"compiled": False, "detectors": [], "total_vulns": 0,
                "high": 0, "medium": 0, "low": 0, "error": str(e)}


def get_original_vulns(prompt_id: int) -> dict:
    """Look up original GPT-4o vulnerability counts from aggregated results."""
    csv_path = Path("analysis/results/aggregated_results.csv")
    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row["llm"] != "gpt4o":
                continue
            fname = row["filepath"].split("/")[-1]
            pid = int(fname.split("_")[0])
            if pid == prompt_id:
                return {
                    "total_vulns": int(row["total_vulns"]),
                    "high": int(row["high"]),
                    "medium": int(row["medium"]),
                    "low": int(row["low"]),
                    "filepath": row["filepath"],
                }
    return None


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Prompt mitigation experiment")
    parser.add_argument("--use-anthropic", action="store_true",
                        help="Use Claude 3.5 Sonnet instead of GPT-4o")
    args = parser.parse_args()

    if args.use_anthropic:
        generate_fn = generate_anthropic
        model_name = "claude-sonnet-4"
        print("Using Claude Sonnet 4 (Anthropic API)")
    else:
        generate_fn = generate_openai
        model_name = "gpt-4o"
        print("Using GPT-4o (OpenAI API)")

    # Load prompts
    with open("prompts/all_prompts.json") as f:
        all_prompts = json.load(f)

    prompt_map = {p["id"]: p for p in all_prompts}
    selected = [prompt_map[pid] for pid in SELECTED_IDS]

    # Setup
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    results = []
    print(f"Running mitigation experiment: {len(selected)} prompts")
    print(f"Output: {OUTPUT_DIR}")
    print("=" * 70)

    for i, prompt_data in enumerate(selected):
        pid = prompt_data["id"]
        category = prompt_data["category"]
        complexity = prompt_data.get("complexity", "")
        original_prompt = prompt_data["prompt"]
        enhanced_prompt = SECURITY_PREFIX + original_prompt

        print(f"\n[{i+1}/{len(selected)}] ID={pid} | {category} | {complexity}")
        print(f"  Prompt: {original_prompt[:70]}...")

        # Generate with security-enhanced prompt
        try:
            raw = generate_fn(enhanced_prompt, SYSTEM_PROMPT)
            code = extract_solidity_code(raw)
        except Exception as e:
            print(f"  API ERROR: {e}")
            results.append({
                "prompt_id": pid, "category": category, "complexity": complexity,
                "error": str(e), "enhanced_compiled": False,
                "enhanced_total_vulns": 0, "enhanced_high": 0,
                "enhanced_medium": 0, "enhanced_low": 0,
            })
            continue

        # Save contract
        safe_cat = re.sub(r'[/\\()\s]+', '_', category)
        safe_cat = re.sub(r'[^a-zA-Z0-9_-]', '', safe_cat)
        filename = f"{pid:03d}_{safe_cat}_{complexity}.sol"
        filepath = OUTPUT_DIR / filename
        with open(filepath, "w") as f:
            f.write(code)
        print(f"  Saved: {filepath} ({len(code)} chars)")

        # Run Slither on enhanced version
        print(f"  Running Slither...")
        enhanced_results = run_slither(str(filepath))
        print(f"  Enhanced: compiled={enhanced_results['compiled']}, "
              f"vulns={enhanced_results['total_vulns']}, "
              f"high={enhanced_results['high']}, med={enhanced_results['medium']}")

        # Get original results
        orig = get_original_vulns(pid)
        if orig:
            print(f"  Original: vulns={orig['total_vulns']}, "
                  f"high={orig['high']}, med={orig['medium']}")
            delta = orig['total_vulns'] - enhanced_results['total_vulns']
            print(f"  Delta: {'+' if delta > 0 else ''}{delta} "
                  f"({'fewer' if delta > 0 else 'more' if delta < 0 else 'same'} vulns)")
        else:
            print(f"  Original: not found in aggregated results")

        results.append({
            "prompt_id": pid,
            "category": category,
            "complexity": complexity,
            "original_prompt": original_prompt,
            "enhanced_compiled": enhanced_results["compiled"],
            "enhanced_total_vulns": enhanced_results["total_vulns"],
            "enhanced_high": enhanced_results["high"],
            "enhanced_medium": enhanced_results["medium"],
            "enhanced_low": enhanced_results["low"],
            "original_total_vulns": orig["total_vulns"] if orig else None,
            "original_high": orig["high"] if orig else None,
            "original_medium": orig["medium"] if orig else None,
            "original_low": orig["low"] if orig else None,
            "vuln_delta": (orig["total_vulns"] - enhanced_results["total_vulns"]) if orig else None,
            "high_delta": (orig["high"] - enhanced_results["high"]) if orig else None,
            "detector_details": [
                {"check": d.get("check", ""), "impact": d.get("impact", ""),
                 "confidence": d.get("confidence", "")}
                for d in enhanced_results.get("detectors", [])
            ],
            "filepath": str(filepath),
        })

        # Small delay for rate limiting
        time.sleep(1.5)

    # ── Summary ──────────────────────────────────────────────────────────
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)

    paired = [r for r in results if r.get("original_total_vulns") is not None
              and r.get("enhanced_compiled")]
    not_compiled = [r for r in results if not r.get("enhanced_compiled") and "error" not in r]
    errored = [r for r in results if "error" in r]

    if paired:
        orig_total = sum(r["original_total_vulns"] for r in paired)
        enh_total = sum(r["enhanced_total_vulns"] for r in paired)
        orig_high = sum(r["original_high"] for r in paired)
        enh_high = sum(r["enhanced_high"] for r in paired)
        enh_compiled = sum(1 for r in results if r.get("enhanced_compiled"))

        print(f"Paired comparisons (both compiled): {len(paired)}")
        print(f"  Original total vulns:  {orig_total} (mean {orig_total/len(paired):.2f})")
        print(f"  Enhanced total vulns:  {enh_total} (mean {enh_total/len(paired):.2f})")
        if orig_total > 0:
            print(f"  Reduction:             {orig_total - enh_total} "
                  f"({(1 - enh_total/orig_total)*100:.1f}%)")
        else:
            print(f"  Reduction:             N/A (no original vulns)")
        print(f"  Original high-sev:     {orig_high}")
        print(f"  Enhanced high-sev:     {enh_high}")
        print(f"  High-sev reduction:    {orig_high - enh_high}")
        print(f"\nCompilation rates:")
        print(f"  Enhanced: {enh_compiled}/{len(results)}")

        # Per-prompt breakdown
        print(f"\nPer-prompt breakdown:")
        print(f"{'ID':>4} {'Category':>25} {'Orig':>5} {'Enh':>5} {'Delta':>6}")
        print("-" * 50)
        for r in paired:
            d = r["vuln_delta"]
            sign = "+" if d > 0 else "" if d < 0 else " "
            print(f"{r['prompt_id']:>4} {r['category']:>25} "
                  f"{r['original_total_vulns']:>5} {r['enhanced_total_vulns']:>5} "
                  f"{sign}{d:>5}")
    else:
        print("No paired comparisons available.")

    # Save results
    summary = {
        "experiment": "prompt_mitigation",
        "model": model_name,
        "n_prompts": len(results),
        "n_compiled": sum(1 for r in results if r.get("enhanced_compiled")),
        "n_paired": len(paired) if paired else 0,
        "original_mean_vulns": orig_total / len(paired) if paired else 0,
        "enhanced_mean_vulns": enh_total / len(paired) if paired else 0,
        "total_reduction": orig_total - enh_total if paired else 0,
        "total_reduction_pct": (1 - enh_total / max(orig_total, 1)) * 100 if paired else 0,
        "high_sev_reduction": orig_high - enh_high if paired else 0,
        "security_prefix": SECURITY_PREFIX.strip(),
        "per_prompt": results,
    }

    RESULTS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(RESULTS_FILE, "w") as f:
        json.dump(summary, f, indent=2)
    print(f"\nResults saved to {RESULTS_FILE}")


if __name__ == "__main__":
    main()
