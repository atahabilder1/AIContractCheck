"""
LLM Client modules for generating smart contracts.
Each client provides a generate_contract(prompt) function.
"""

from .openai_client import generate_contract as gpt4_generate
from .anthropic_client import generate_contract as claude_generate
from .gemini_client import generate_contract as gemini_generate
from .codellama_client import generate_contract as codellama_generate

__all__ = [
    "gpt4_generate",
    "claude_generate",
    "gemini_generate",
    "codellama_generate",
]
