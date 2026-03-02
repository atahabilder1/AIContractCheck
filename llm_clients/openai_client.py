"""
OpenAI GPT-4o client for generating Solidity smart contracts.
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
    return OpenAI(api_key=api_key)


def generate_contract(prompt: str, model: str = "gpt-4o") -> str:
    """
    Generate a Solidity smart contract using GPT-4o.

    Args:
        prompt: The prompt describing the contract to generate
        model: The OpenAI model to use (default: gpt-4o)

    Returns:
        The generated Solidity code as a string
    """
    client = get_client()

    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt}
        ],
        temperature=0.7,
        max_tokens=4000
    )

    return response.choices[0].message.content


def extract_solidity_code(response: str) -> str:
    """
    Extract Solidity code from a response that may contain markdown code blocks.

    Args:
        response: The raw response from the LLM

    Returns:
        The extracted Solidity code
    """
    # Check for markdown code blocks
    if "```solidity" in response:
        start = response.find("```solidity") + len("```solidity")
        end = response.find("```", start)
        if end != -1:
            return response[start:end].strip()

    if "```" in response:
        start = response.find("```") + 3
        # Skip potential language identifier
        newline = response.find("\n", start)
        if newline != -1:
            start = newline + 1
        end = response.find("```", start)
        if end != -1:
            return response[start:end].strip()

    # Return as-is if no code blocks found
    return response.strip()


if __name__ == "__main__":
    # Test the client
    test_prompt = "Write a basic ERC20 token contract in Solidity."
    print("Testing GPT-4o client...")
    try:
        code = generate_contract(test_prompt)
        print("Generated code:")
        print(code[:500] + "..." if len(code) > 500 else code)
    except Exception as e:
        print(f"Error: {e}")
