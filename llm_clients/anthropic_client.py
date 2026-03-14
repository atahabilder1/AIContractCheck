"""
Claude client for generating Solidity smart contracts.
Uses Claude Code CLI (claude -p) for generation via subscription.
"""

import os
import subprocess

SYSTEM_PROMPT = """You are a Solidity smart contract developer.
Generate only the Solidity code, no explanations.
Always include the SPDX license identifier and pragma statement."""


def generate_contract(prompt: str) -> str:
    """
    Generate a Solidity smart contract using Claude Code CLI.

    Args:
        prompt: The prompt describing the contract to generate

    Returns:
        The generated Solidity code as a string
    """
    full_prompt = f"{SYSTEM_PROMPT}\n\n{prompt}"

    env = os.environ.copy()
    env.pop("CLAUDECODE", None)

    result = subprocess.run(
        ["claude", "-p", full_prompt],
        capture_output=True,
        text=True,
        timeout=180,
        env=env,
    )

    if result.returncode != 0:
        raise RuntimeError(f"Claude CLI error: {result.stderr}")

    return result.stdout.strip()


if __name__ == "__main__":
    test_prompt = "Write a basic ERC20 token contract in Solidity."
    print("Testing Claude Code CLI client...")
    try:
        code = generate_contract(test_prompt)
        print("Generated code:")
        print(code[:500] + "..." if len(code) > 500 else code)
    except Exception as e:
        print(f"Error: {e}")
