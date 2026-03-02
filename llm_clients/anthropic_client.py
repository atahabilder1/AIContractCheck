"""
Anthropic Claude 3.5 Sonnet client for generating Solidity smart contracts.
"""

import os
import anthropic
from dotenv import load_dotenv

load_dotenv()

SYSTEM_PROMPT = """You are a Solidity smart contract developer.
Generate only the Solidity code, no explanations.
Always include the SPDX license identifier and pragma statement."""


def get_client() -> anthropic.Anthropic:
    """Get Anthropic client with API key from environment."""
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY environment variable not set")
    return anthropic.Anthropic(api_key=api_key)


def generate_contract(prompt: str, model: str = "claude-3-5-sonnet-20241022") -> str:
    """
    Generate a Solidity smart contract using Claude 3.5 Sonnet.

    Args:
        prompt: The prompt describing the contract to generate
        model: The Anthropic model to use (default: claude-3-5-sonnet)

    Returns:
        The generated Solidity code as a string
    """
    client = get_client()

    response = client.messages.create(
        model=model,
        max_tokens=4000,
        system=SYSTEM_PROMPT,
        messages=[
            {"role": "user", "content": prompt}
        ]
    )

    return response.content[0].text


def extract_solidity_code(response: str) -> str:
    """
    Extract Solidity code from a response that may contain markdown code blocks.

    Args:
        response: The raw response from the LLM

    Returns:
        The extracted Solidity code
    """
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


if __name__ == "__main__":
    test_prompt = "Write a basic ERC20 token contract in Solidity."
    print("Testing Claude client...")
    try:
        code = generate_contract(test_prompt)
        print("Generated code:")
        print(code[:500] + "..." if len(code) > 500 else code)
    except Exception as e:
        print(f"Error: {e}")
