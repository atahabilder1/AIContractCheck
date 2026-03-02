"""
CodeLlama client for generating Solidity smart contracts.
Uses Hugging Face Transformers for local inference.
"""

import os
from dotenv import load_dotenv

load_dotenv()

# Lazy imports to avoid loading torch unnecessarily
_tokenizer = None
_model = None


def get_model():
    """Get CodeLlama model and tokenizer (lazy loading)."""
    global _tokenizer, _model

    if _tokenizer is None or _model is None:
        from transformers import AutoTokenizer, AutoModelForCausalLM
        import torch

        model_id = "codellama/CodeLlama-34b-Instruct-hf"

        # Check for Hugging Face token
        hf_token = os.getenv("HUGGINGFACE_TOKEN")

        _tokenizer = AutoTokenizer.from_pretrained(
            model_id,
            token=hf_token
        )
        _model = AutoModelForCausalLM.from_pretrained(
            model_id,
            torch_dtype=torch.float16,
            device_map="auto",
            token=hf_token
        )

    return _tokenizer, _model


def generate_contract(prompt: str) -> str:
    """
    Generate a Solidity smart contract using CodeLlama.

    Args:
        prompt: The prompt describing the contract to generate

    Returns:
        The generated Solidity code as a string
    """
    tokenizer, model = get_model()

    system = """You are a Solidity smart contract developer.
Generate only the Solidity code, no explanations.
Always include the SPDX license identifier and pragma statement."""

    # CodeLlama instruct format
    full_prompt = f"<s>[INST] <<SYS>>\n{system}\n<</SYS>>\n\n{prompt} [/INST]"

    inputs = tokenizer(full_prompt, return_tensors="pt").to("cuda")
    outputs = model.generate(
        **inputs,
        max_new_tokens=4000,
        temperature=0.7,
        do_sample=True
    )

    response = tokenizer.decode(outputs[0], skip_special_tokens=True)

    # Extract the response after [/INST]
    if "[/INST]" in response:
        response = response.split("[/INST]")[-1].strip()

    return response


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
    print("Testing CodeLlama client...")
    print("Note: This requires a GPU with sufficient VRAM (~40GB for 34B model)")
    try:
        code = generate_contract(test_prompt)
        print("Generated code:")
        print(code[:500] + "..." if len(code) > 500 else code)
    except Exception as e:
        print(f"Error: {e}")
