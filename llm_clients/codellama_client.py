"""
CodeLlama client for generating Solidity smart contracts.
Uses Ollama API running on remote A6000 machine.
"""

import os
import requests
from dotenv import load_dotenv

load_dotenv()

OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://100.127.35.85:11434")
MODEL_NAME = "codellama:34b"

SYSTEM_PROMPT = """You are a Solidity smart contract developer.
Generate only the Solidity code, no explanations.
Always include the SPDX license identifier and pragma statement."""


def generate_contract(prompt: str) -> str:
    """
    Generate a Solidity smart contract using CodeLlama via Ollama.

    Args:
        prompt: The prompt describing the contract to generate

    Returns:
        The generated Solidity code as a string
    """
    response = requests.post(
        f"{OLLAMA_HOST}/api/generate",
        json={
            "model": MODEL_NAME,
            "system": SYSTEM_PROMPT,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.7,
                "num_predict": 4000,
            },
        },
        timeout=300,
    )
    response.raise_for_status()
    return response.json()["response"]


if __name__ == "__main__":
    test_prompt = "Write a basic ERC20 token contract in Solidity."
    print(f"Testing CodeLlama client via Ollama at {OLLAMA_HOST}...")
    try:
        code = generate_contract(test_prompt)
        print("Generated code:")
        print(code[:500] + "..." if len(code) > 500 else code)
    except Exception as e:
        print(f"Error: {e}")
