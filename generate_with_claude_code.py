"""
Generate smart contracts using Claude Code CLI.
This script reads prompts and invokes Claude Code to generate each contract.
"""

import json
import subprocess
import re
import time
from pathlib import Path
from datetime import datetime

SYSTEM_INSTRUCTION = """You are a Solidity smart contract developer.
Generate ONLY the Solidity code, nothing else.
No explanations, no markdown, just pure Solidity code.
Always include the SPDX license identifier and pragma statement."""


def sanitize_filename(name: str) -> str:
    """Convert a category name to a safe filename."""
    name = re.sub(r'[/\\()\s]+', '_', name)
    name = re.sub(r'[^a-zA-Z0-9_-]', '', name)
    return name


def extract_solidity_code(response: str) -> str:
    """Extract Solidity code from response (handles markdown blocks)."""
    if not response:
        return ""

    # Check for markdown code blocks
    if "```solidity" in response:
        start = response.find("```solidity") + len("```solidity")
        end = response.find("```", start)
        if end != -1:
            return response[start:end].strip()

    if "```" in response:
        start = response.find("```") + 3
        newline = response.find("\n", start)
        if newline != -1:
            start = newline + 1
        end = response.find("```", start)
        if end != -1:
            return response[start:end].strip()

    return response.strip()


def generate_with_claude_code(prompt: str, timeout: int = 120) -> str:
    """
    Generate contract using Claude Code CLI.

    Args:
        prompt: The prompt to send to Claude Code
        timeout: Maximum time to wait (seconds)

    Returns:
        Generated Solidity code
    """
    full_prompt = f"{SYSTEM_INSTRUCTION}\n\n{prompt}"

    try:
        # Use claude CLI with -p flag for non-interactive mode
        result = subprocess.run(
            ["claude", "-p", full_prompt],
            capture_output=True,
            text=True,
            timeout=timeout
        )

        if result.returncode == 0:
            return extract_solidity_code(result.stdout)
        else:
            print(f"Error: {result.stderr}")
            return ""

    except subprocess.TimeoutExpired:
        print("Timeout expired")
        return ""
    except FileNotFoundError:
        print("Claude Code CLI not found. Make sure 'claude' is in your PATH.")
        return ""
    except Exception as e:
        print(f"Error: {e}")
        return ""


def generate_all_contracts(
    prompts_file: str = "prompts/all_prompts.json",
    output_dir: str = "dataset/claude_code",
    start_index: int = 0,
    end_index: int = None,
    delay: float = 2.0
):
    """
    Generate all contracts using Claude Code.

    Args:
        prompts_file: Path to prompts JSON
        output_dir: Directory to save contracts
        start_index: Start from this prompt index (for resuming)
        end_index: Stop at this prompt index (None = all)
        delay: Delay between requests (seconds)
    """
    # Load prompts
    with open(prompts_file) as f:
        prompts = json.load(f)

    if end_index is None:
        end_index = len(prompts)

    prompts_to_process = prompts[start_index:end_index]
    print(f"Processing prompts {start_index} to {end_index} ({len(prompts_to_process)} total)")

    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    results = []
    errors = []

    for i, prompt_data in enumerate(prompts_to_process):
        actual_index = start_index + i
        prompt_id = prompt_data["id"]
        category = prompt_data["category"]
        prompt = prompt_data["prompt"]

        # Create filename
        safe_category = sanitize_filename(category)
        filename = f"{safe_category}_{prompt_id:03d}.sol"
        filepath = output_path / filename

        # Skip if already exists
        if filepath.exists():
            print(f"[{actual_index}/{end_index}] Skipping {filename} (exists)")
            continue

        print(f"[{actual_index}/{end_index}] Generating: {filename}")
        print(f"  Prompt: {prompt[:60]}...")

        try:
            code = generate_with_claude_code(prompt)

            if code:
                # Save contract
                with open(filepath, "w") as f:
                    f.write(code)

                results.append({
                    "prompt_id": prompt_id,
                    "category": category,
                    "type": prompt_data["type"],
                    "filepath": str(filepath),
                    "code_length": len(code),
                    "timestamp": datetime.now().isoformat()
                })
                print(f"  Saved: {len(code)} characters")
            else:
                errors.append({
                    "prompt_id": prompt_id,
                    "category": category,
                    "error": "Empty response"
                })
                print(f"  ERROR: Empty response")

        except Exception as e:
            errors.append({
                "prompt_id": prompt_id,
                "category": category,
                "error": str(e)
            })
            print(f"  ERROR: {e}")

        # Delay between requests
        time.sleep(delay)

    # Save progress
    progress_file = output_path / "generation_progress.json"
    with open(progress_file, "w") as f:
        json.dump({
            "last_index": end_index,
            "successful": len(results),
            "failed": len(errors),
            "results": results,
            "errors": errors
        }, f, indent=2)

    print(f"\n{'='*60}")
    print(f"COMPLETE: {len(results)} generated, {len(errors)} failed")
    print(f"Progress saved to: {progress_file}")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Generate contracts with Claude Code")
    parser.add_argument("--start", type=int, default=0, help="Start index")
    parser.add_argument("--end", type=int, default=None, help="End index")
    parser.add_argument("--delay", type=float, default=2.0, help="Delay between requests")
    parser.add_argument("--output", type=str, default="dataset/claude_code", help="Output directory")

    args = parser.parse_args()

    generate_all_contracts(
        start_index=args.start,
        end_index=args.end,
        delay=args.delay,
        output_dir=args.output
    )
