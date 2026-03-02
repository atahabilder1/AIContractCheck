"""
Master script to generate smart contracts from all LLMs.
Generates 300 contracts per LLM (1500 total).
"""

import json
import os
import re
import time
from datetime import datetime
from pathlib import Path

from dotenv import load_dotenv
from tqdm import tqdm

load_dotenv()

# Import LLM generators
from llm_clients.openai_client import generate_contract as gpt4_generate
from llm_clients.anthropic_client import generate_contract as claude_generate
from llm_clients.gemini_client import generate_contract as gemini_generate
# from llm_clients.codellama_client import generate_contract as codellama_generate

# LLM generators to use
LLM_GENERATORS = {
    "gpt4o": gpt4_generate,
    "claude": claude_generate,
    "gemini": gemini_generate,
    # "codellama": codellama_generate,  # Requires GPU
    # "copilot": copilot_generate,       # Add when available
}


def extract_solidity_code(response: str) -> str:
    """Extract Solidity code from LLM response (handles markdown blocks)."""
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


def sanitize_filename(name: str) -> str:
    """Convert a category name to a safe filename."""
    # Replace special characters with underscores
    name = re.sub(r'[/\\()\s]+', '_', name)
    # Remove other special characters
    name = re.sub(r'[^a-zA-Z0-9_-]', '', name)
    return name


def generate_dataset(
    llm_names: list = None,
    output_dir: str = "dataset",
    prompts_file: str = "prompts/all_prompts.json",
    delay_between_requests: float = 1.0
):
    """
    Generate smart contracts from all specified LLMs.

    Args:
        llm_names: List of LLM names to use (None = all available)
        output_dir: Directory to save generated contracts
        prompts_file: Path to prompts JSON file
        delay_between_requests: Delay between API calls (rate limiting)
    """
    # Load prompts
    with open(prompts_file) as f:
        prompts = json.load(f)

    print(f"Loaded {len(prompts)} prompts")

    # Filter LLMs if specified
    generators = LLM_GENERATORS
    if llm_names:
        generators = {k: v for k, v in LLM_GENERATORS.items() if k in llm_names}

    print(f"Using LLMs: {list(generators.keys())}")

    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)

    results = []
    errors = []

    # Generate contracts for each LLM
    for llm_name, generator in generators.items():
        print(f"\n{'='*60}")
        print(f"Generating contracts with: {llm_name}")
        print(f"{'='*60}")

        llm_dir = output_path / llm_name
        llm_dir.mkdir(exist_ok=True)

        for prompt_data in tqdm(prompts, desc=f"{llm_name}"):
            prompt_id = prompt_data["id"]
            category = prompt_data["category"]
            prompt = prompt_data["prompt"]

            # Create filename
            safe_category = sanitize_filename(category)
            filename = f"{safe_category}_{prompt_id:03d}.sol"
            filepath = llm_dir / filename

            try:
                # Generate contract
                raw_response = generator(prompt)
                code = extract_solidity_code(raw_response)

                # Save contract
                with open(filepath, "w") as f:
                    f.write(code)

                # Record metadata
                results.append({
                    "llm": llm_name,
                    "prompt_id": prompt_id,
                    "category": category,
                    "type": prompt_data["type"],
                    "complexity": prompt_data.get("complexity", ""),
                    "trigger": prompt_data.get("trigger", ""),
                    "prompt": prompt,
                    "filepath": str(filepath),
                    "code_length": len(code),
                    "timestamp": datetime.now().isoformat()
                })

            except Exception as e:
                error_msg = str(e)
                print(f"\nError generating {filename}: {error_msg}")
                errors.append({
                    "llm": llm_name,
                    "prompt_id": prompt_id,
                    "category": category,
                    "error": error_msg,
                    "timestamp": datetime.now().isoformat()
                })

            # Rate limiting
            time.sleep(delay_between_requests)

    # Save metadata
    metadata = {
        "generated_at": datetime.now().isoformat(),
        "total_prompts": len(prompts),
        "llms_used": list(generators.keys()),
        "successful": len(results),
        "failed": len(errors),
        "results": results,
        "errors": errors
    }

    with open(output_path / "metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)

    # Print summary
    print(f"\n{'='*60}")
    print("GENERATION SUMMARY")
    print(f"{'='*60}")
    print(f"Total contracts generated: {len(results)}")
    print(f"Failed generations: {len(errors)}")
    print(f"Output directory: {output_path.absolute()}")
    print(f"Metadata saved to: {output_path / 'metadata.json'}")

    # Per-LLM summary
    for llm_name in generators.keys():
        llm_results = [r for r in results if r["llm"] == llm_name]
        llm_errors = [e for e in errors if e["llm"] == llm_name]
        print(f"\n{llm_name}:")
        print(f"  Successful: {len(llm_results)}")
        print(f"  Failed: {len(llm_errors)}")

    return results, errors


def generate_single_llm(llm_name: str, **kwargs):
    """Generate contracts from a single LLM only."""
    return generate_dataset(llm_names=[llm_name], **kwargs)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Generate smart contracts from LLMs")
    parser.add_argument(
        "--llm",
        type=str,
        choices=list(LLM_GENERATORS.keys()),
        help="Generate from a single LLM only"
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=1.0,
        help="Delay between API requests (seconds)"
    )
    parser.add_argument(
        "--output",
        type=str,
        default="dataset",
        help="Output directory"
    )

    args = parser.parse_args()

    llm_names = [args.llm] if args.llm else None
    generate_dataset(
        llm_names=llm_names,
        output_dir=args.output,
        delay_between_requests=args.delay
    )
