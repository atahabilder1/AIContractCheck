"""
Master script to generate smart contracts from all 6 LLMs.
300 contracts per LLM = 1,800 total.

Features:
- Skips already-generated contracts (resume-safe)
- Saves raw response + extracted code separately
- Logs metadata for reproducibility
- Handles rate limits with configurable delays
- Validates output (must contain 'pragma' or 'contract')
- Retries failed generations up to 3 times
"""

import json
import os
import re
import sys
import time
import traceback
from datetime import datetime
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()


# ── LLM Registry ─────────────────────────────────────────────────────────────

def _import_generator(llm_name: str):
    """Lazily import a single LLM generator to avoid loading all deps at once."""
    if llm_name == "gpt4o":
        from llm_clients.openai_client import generate_contract
        return generate_contract
    elif llm_name == "claude":
        from llm_clients.anthropic_client import generate_contract
        return generate_contract
    elif llm_name == "gemini":
        from llm_clients.gemini_client import generate_contract
        return generate_contract
    elif llm_name == "codellama":
        from llm_clients.codellama_client import generate_contract
        return generate_contract
    elif llm_name == "deepseek":
        from llm_clients.deepseek_client import generate_contract
        return generate_contract
    elif llm_name == "qwen":
        from llm_clients.qwen_client import generate_contract
        return generate_contract
    elif llm_name == "gpt5":
        from llm_clients.gpt5_client import generate_contract
        return generate_contract
    elif llm_name == "codestral":
        from llm_clients.codestral_client import generate_contract
        return generate_contract
    else:
        raise ValueError(f"Unknown LLM: {llm_name}")


# Order matters: run local models first (free), then API models
ALL_LLMS = ["codellama", "deepseek", "qwen", "codestral", "claude", "gemini", "gpt4o", "gpt5"]

# Per-LLM delay (seconds) to respect rate limits
RATE_LIMITS = {
    "gpt4o": 1.0,      # OpenAI: generous limits
    "gpt5": 1.0,        # OpenAI: generous limits
    "claude": 3.0,      # Claude CLI: give it time
    "gemini": 5.0,      # Gemini 2.5 Flash-Lite: 15 RPM, 1000 RPD
    "codellama": 1.0,   # Local: no limit (but sequential)
    "deepseek": 1.0,    # Local
    "qwen": 1.0,        # Local
    "codestral": 1.0,   # Local
}


# ── Code Extraction ──────────────────────────────────────────────────────────

def extract_solidity_code(response: str) -> str:
    """Extract Solidity code from LLM response, stripping markdown wrappers."""
    if not response:
        return ""

    # Try ```solidity ... ``` first
    if "```solidity" in response:
        start = response.find("```solidity") + len("```solidity")
        end = response.find("```", start)
        if end != -1:
            return response[start:end].strip()

    # Try ``` ... ``` (generic code block)
    if "```" in response:
        start = response.find("```") + 3
        # Skip language identifier on same line
        newline = response.find("\n", start)
        if newline != -1 and (newline - start) < 20:
            start = newline + 1
        end = response.find("```", start)
        if end != -1:
            return response[start:end].strip()

    # No markdown wrapper, return as-is
    return response.strip()


def validate_solidity(code: str) -> bool:
    """Check if extracted code looks like valid Solidity."""
    if not code or len(code) < 50:
        return False
    # Must contain at least one of these Solidity markers
    markers = ["pragma solidity", "contract ", "interface ", "library "]
    return any(m in code.lower() for m in markers)


def sanitize_filename(name: str) -> str:
    """Convert a category name to a safe filename."""
    name = re.sub(r'[/\\()\s]+', '_', name)
    name = re.sub(r'[^a-zA-Z0-9_-]', '', name)
    return name


# ── Main Generation ──────────────────────────────────────────────────────────

def generate_for_llm(
    llm_name: str,
    prompts: list,
    output_dir: str = "dataset",
    max_retries: int = 3,
):
    """
    Generate all contracts for a single LLM.

    Args:
        llm_name: Name of the LLM
        prompts: List of prompt dicts from all_prompts.json
        output_dir: Base output directory
        max_retries: Max retries per failed generation
    """
    generator = _import_generator(llm_name)
    delay = RATE_LIMITS.get(llm_name, 2.0)

    # Create base directory
    llm_dir = Path(output_dir) / llm_name
    llm_dir.mkdir(parents=True, exist_ok=True)

    # Load existing progress
    progress_file = llm_dir / "progress.json"
    if progress_file.exists():
        with open(progress_file) as f:
            progress = json.load(f)
    else:
        progress = {"completed": [], "failed": [], "results": []}

    completed_ids = set(progress["completed"])

    print(f"\n{'='*60}")
    print(f" {llm_name.upper()} — {len(prompts)} prompts")
    print(f" Already completed: {len(completed_ids)}")
    print(f" Remaining: {len(prompts) - len(completed_ids)}")
    print(f" Delay: {delay}s between requests")
    print(f"{'='*60}\n")

    for i, prompt_data in enumerate(prompts):
        prompt_id = prompt_data["id"]

        # Skip already completed
        if prompt_id in completed_ids:
            continue

        category = prompt_data["category"]
        prompt_type = prompt_data["type"]  # "standard" or "adversarial"
        prompt = prompt_data["prompt"]
        safe_category = sanitize_filename(category)

        # Build folder path: dataset/<llm>/<type>/<category>/
        type_dir = llm_dir / prompt_type / safe_category
        raw_dir = llm_dir / "raw_responses" / prompt_type / safe_category
        type_dir.mkdir(parents=True, exist_ok=True)
        raw_dir.mkdir(parents=True, exist_ok=True)

        # Build filename with context
        if prompt_type == "standard":
            complexity = prompt_data.get("complexity", "unknown")
            filename = f"{prompt_id:03d}_{complexity}.sol"
        else:
            trigger = sanitize_filename(prompt_data.get("trigger", "unknown"))
            adv_cat = sanitize_filename(prompt_data.get("adversarial_category", "unknown"))
            filename = f"{prompt_id:03d}_{adv_cat}.sol"

        filepath = type_dir / filename
        raw_filepath = raw_dir / filename.replace(".sol", ".txt")

        display_name = f"{prompt_type}/{safe_category}/{filename}"
        print(f"[{i+1}/{len(prompts)}] {display_name}")
        print(f"  Prompt: {prompt[:70]}...")

        # Retry loop
        success = False
        for attempt in range(1, max_retries + 1):
            try:
                raw_response = generator(prompt)

                # Save raw response
                with open(raw_filepath, "w") as f:
                    f.write(raw_response)

                # Extract and validate code
                code = extract_solidity_code(raw_response)

                if not validate_solidity(code):
                    print(f"  WARNING: Invalid Solidity (attempt {attempt}/{max_retries})")
                    if attempt < max_retries:
                        time.sleep(delay)
                        continue
                    # Save anyway on last attempt
                    print(f"  Saving anyway (best effort)")

                # Save extracted code
                with open(filepath, "w") as f:
                    f.write(code)

                # Record success
                progress["completed"].append(prompt_id)
                progress["results"].append({
                    "prompt_id": prompt_id,
                    "category": category,
                    "type": prompt_type,
                    "complexity": prompt_data.get("complexity", ""),
                    "trigger": prompt_data.get("trigger", ""),
                    "adversarial_category": prompt_data.get("adversarial_category", ""),
                    "filepath": str(filepath.relative_to(Path(output_dir))),
                    "raw_filepath": str(raw_filepath.relative_to(Path(output_dir))),
                    "filename": filename,
                    "code_length": len(code),
                    "raw_length": len(raw_response),
                    "valid_solidity": validate_solidity(code),
                    "attempt": attempt,
                    "timestamp": datetime.now().isoformat(),
                })
                completed_ids.add(prompt_id)
                success = True
                print(f"  OK ({len(code)} chars, attempt {attempt})")
                break

            except Exception as e:
                print(f"  ERROR (attempt {attempt}/{max_retries}): {e}")
                if attempt < max_retries:
                    wait = delay * attempt * 2  # exponential backoff
                    print(f"  Retrying in {wait}s...")
                    time.sleep(wait)

        if not success:
            progress["failed"].append({
                "prompt_id": prompt_id,
                "category": category,
                "error": traceback.format_exc(),
                "timestamp": datetime.now().isoformat(),
            })
            print(f"  FAILED after {max_retries} attempts")

        # Save progress after each contract (resume-safe)
        with open(progress_file, "w") as f:
            json.dump(progress, f, indent=2)

        # Rate limit delay
        time.sleep(delay)

    # Final summary
    n_ok = len(progress["completed"])
    n_fail = len(progress["failed"])
    print(f"\n{llm_name.upper()} DONE: {n_ok} succeeded, {n_fail} failed")
    return progress


def generate_all(
    llm_names: list = None,
    output_dir: str = "dataset",
    prompts_file: str = "prompts/all_prompts.json",
):
    """Generate contracts for all (or specified) LLMs."""
    with open(prompts_file) as f:
        prompts = json.load(f)
    print(f"Loaded {len(prompts)} prompts")

    llms = llm_names or ALL_LLMS
    print(f"LLMs to run: {llms}")

    all_results = {}
    for llm_name in llms:
        try:
            result = generate_for_llm(llm_name, prompts, output_dir)
            all_results[llm_name] = {
                "completed": len(result["completed"]),
                "failed": len(result["failed"]),
            }
        except KeyboardInterrupt:
            print(f"\n\nInterrupted during {llm_name}. Progress saved.")
            sys.exit(1)
        except Exception as e:
            print(f"\nFATAL ERROR for {llm_name}: {e}")
            traceback.print_exc()
            all_results[llm_name] = {"error": str(e)}

    # Final summary
    print(f"\n{'='*60}")
    print("FINAL SUMMARY")
    print(f"{'='*60}")
    for llm, info in all_results.items():
        if "error" in info:
            print(f"  {llm}: ERROR - {info['error']}")
        else:
            print(f"  {llm}: {info['completed']} completed, {info['failed']} failed")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Generate smart contracts from LLMs")
    parser.add_argument(
        "--llm", type=str, choices=ALL_LLMS,
        help="Generate from a single LLM only"
    )
    parser.add_argument(
        "--llms", type=str, nargs="+", choices=ALL_LLMS,
        help="Generate from specific LLMs"
    )
    parser.add_argument("--output", type=str, default="dataset", help="Output directory")
    parser.add_argument("--prompts", type=str, default="prompts/all_prompts.json")

    args = parser.parse_args()

    if args.llm:
        llm_list = [args.llm]
    elif args.llms:
        llm_list = args.llms
    else:
        llm_list = None  # all

    generate_all(llm_names=llm_list, output_dir=args.output, prompts_file=args.prompts)
