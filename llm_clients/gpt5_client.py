"""
OpenAI GPT-5 client for generating Solidity smart contracts.
"""

import os
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

SYSTEM_PROMPT = """You are a Solidity smart contract developer.
Generate only the Solidity code, no explanations.
Always include the SPDX license identifier and pragma statement."""


def get_client() -> OpenAI:
    """Get OpenAI client with API key from environment."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY environment variable not set")
    return OpenAI(api_key=api_key, timeout=300.0)


def generate_contract(prompt: str) -> str:
    """
    Generate a Solidity smart contract using GPT-5.

    Args:
        prompt: The prompt describing the contract to generate

    Returns:
        The generated Solidity code as a string
    """
    client = get_client()

    response = client.chat.completions.create(
        model="gpt-5",
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt}
        ],
        max_completion_tokens=4000
    )

    return response.choices[0].message.content


if __name__ == "__main__":
    test_prompt = "Write a basic ERC20 token contract in Solidity."
    print("Testing GPT-5 client...")
    try:
        code = generate_contract(test_prompt)
        print("Generated code:")
        print(code[:500] + "..." if len(code) > 500 else code)
    except Exception as e:
        print(f"Error: {e}")
