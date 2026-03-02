"""
Google Gemini 1.5 Pro client for generating Solidity smart contracts.
"""

import os
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

SYSTEM_PROMPT = """You are a Solidity smart contract developer.
Generate only the Solidity code, no explanations.
Always include the SPDX license identifier and pragma statement."""


def get_model():
    """Get Gemini model configured with API key from environment."""
    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        raise ValueError("GOOGLE_API_KEY environment variable not set")
    genai.configure(api_key=api_key)
    return genai.GenerativeModel('gemini-1.5-pro')


def generate_contract(prompt: str) -> str:
    """
    Generate a Solidity smart contract using Gemini 1.5 Pro.

    Args:
        prompt: The prompt describing the contract to generate

    Returns:
        The generated Solidity code as a string
    """
    model = get_model()

    full_prompt = f"{SYSTEM_PROMPT}\n\n{prompt}"
    response = model.generate_content(full_prompt)

    return response.text


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
    print("Testing Gemini client...")
    try:
        code = generate_contract(test_prompt)
        print("Generated code:")
        print(code[:500] + "..." if len(code) > 500 else code)
    except Exception as e:
        print(f"Error: {e}")
