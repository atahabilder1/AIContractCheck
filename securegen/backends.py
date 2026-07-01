"""
LLM backends with a uniform multi-turn `chat()` interface.

The existing `llm_clients/` package exposes single-shot `generate_contract()`
functions. The repair-loop and checkpoint strategies need *conversational*
generation (send history, get reply) and *token accounting*, so we wrap the
underlying APIs here behind one ABC.

White-box access (hidden states / logits) for the inline-probe strategy lives in
`WhiteBoxBackend`, kept separate because it needs `transformers` + a GPU and
should never be imported for the API-only strategies.
"""

from __future__ import annotations

import os
from abc import ABC, abstractmethod

from dotenv import load_dotenv

from .types import TokenUsage

load_dotenv()

DEFAULT_SYSTEM = (
    "You are a Solidity smart contract developer.\n"
    "Generate only the Solidity code, no explanations.\n"
    "Always include the SPDX license identifier and pragma statement."
)


def extract_solidity_code(response: str) -> str:
    """Strip markdown fences from an LLM response. (Shared by all strategies.)"""
    if not response:
        return ""
    if "```solidity" in response:
        start = response.find("```solidity") + len("```solidity")
        end = response.find("```", start)
        if end != -1:
            return response[start:end].strip()
    if "```" in response:
        start = response.find("```") + 3
        newline = response.find("\n", start)
        if newline != -1 and (newline - start) < 20:
            start = newline + 1
        end = response.find("```", start)
        if end != -1:
            return response[start:end].strip()
    return response.strip()


class Backend(ABC):
    """Uniform chat interface. A 'message' is {role, content}."""

    name: str = "abstract"
    supports_white_box: bool = False

    @abstractmethod
    def chat(self, messages: list[dict], temperature: float = 0.7,
             max_tokens: int = 4000) -> tuple[str, TokenUsage]:
        """Return (assistant_text, usage)."""

    def generate(self, user: str, system: str = DEFAULT_SYSTEM,
                 **kw) -> tuple[str, TokenUsage]:
        """Single-turn convenience."""
        return self.chat([{"role": "user", "content": user}], **kw,
                          ) if system is None else self.chat(
            [{"role": "system", "content": system},
             {"role": "user", "content": user}], **kw)


class OpenAIBackend(Backend):
    def __init__(self, model: str = "gpt-4o"):
        from openai import OpenAI
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY not set")
        self.client = OpenAI(api_key=api_key)
        self.model = model
        self.name = model

    def chat(self, messages, temperature=0.7, max_tokens=4000):
        # GPT-5 family: no temperature, uses max_completion_tokens
        kw = {"model": self.model, "messages": messages}
        if self.model.startswith("gpt-5"):
            kw["max_completion_tokens"] = max_tokens
        else:
            kw["temperature"] = temperature
            kw["max_tokens"] = max_tokens
        resp = self.client.chat.completions.create(**kw)
        text = resp.choices[0].message.content or ""
        u = resp.usage
        usage = TokenUsage(
            input_tokens=getattr(u, "prompt_tokens", 0),
            output_tokens=getattr(u, "completion_tokens", 0),
            llm_calls=1,
        )
        return text, usage


class AnthropicBackend(Backend):
    def __init__(self, model: str = "claude-sonnet-4-20250514"):
        import anthropic
        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY not set")
        self.client = anthropic.Anthropic(api_key=api_key)
        self.model = model
        self.name = model

    def chat(self, messages, temperature=0.7, max_tokens=4000):
        # Anthropic takes system separately, not as a message role.
        system = DEFAULT_SYSTEM
        turns = []
        for m in messages:
            if m["role"] == "system":
                system = m["content"]
            else:
                turns.append(m)
        resp = self.client.messages.create(
            model=self.model, max_tokens=max_tokens, temperature=temperature,
            system=system, messages=turns,
        )
        text = resp.content[0].text if resp.content else ""
        usage = TokenUsage(
            input_tokens=resp.usage.input_tokens,
            output_tokens=resp.usage.output_tokens,
            llm_calls=1,
        )
        return text, usage


class OllamaBackend(Backend):
    """Local / remote open-weight models (CodeLlama, DeepSeek, Qwen, Codestral)."""

    # registry: short name -> (ollama model tag, default host env override)
    MODELS = {
        "qwen": "qwen2.5-coder:32b",
        "qwen7b": "qwen2.5-coder:7b",
        "qwen14b": "qwen2.5-coder:14b",
        "deepseek": "deepseek-coder-v2:16b",
        "codellama": "codellama:34b",
        "codestral": "codestral:22b",
    }

    def __init__(self, model: str = "qwen", host: str | None = None):
        import requests
        self.requests = requests
        self.tag = self.MODELS.get(model, model)
        self.host = host or os.getenv("OLLAMA_HOST", "http://localhost:11434")
        self.name = model

    def chat(self, messages, temperature=0.7, max_tokens=4000):
        resp = self.requests.post(
            f"{self.host}/api/chat",
            json={
                "model": self.tag,
                "messages": messages,
                "stream": False,
                "options": {"temperature": temperature, "num_predict": max_tokens},
            },
            timeout=600,
        )
        resp.raise_for_status()
        data = resp.json()
        text = data.get("message", {}).get("content", "")
        usage = TokenUsage(
            input_tokens=data.get("prompt_eval_count", 0),
            output_tokens=data.get("eval_count", 0),
            llm_calls=1,
        )
        return text, usage


class GeminiBackend(Backend):
    """Gemini 2.5 Flash-Lite via google-genai (free tier, multi-turn)."""

    SAFETY = [
        {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
        {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
    ]

    def __init__(self, model: str = "gemini-2.5-flash-lite"):
        from google import genai
        self.genai = genai
        api_key = os.getenv("GOOGLE_API_KEY")
        if not api_key:
            raise ValueError("GOOGLE_API_KEY not set")
        self.client = genai.Client(api_key=api_key)
        self.model = model
        self.name = "gemini"

    def chat(self, messages, temperature=0.7, max_tokens=4000):
        import time as _time
        genai = self.genai
        system = DEFAULT_SYSTEM
        contents = []
        for m in messages:
            if m["role"] == "system":
                system = m["content"]
            else:
                role = "model" if m["role"] == "assistant" else "user"
                contents.append({"role": role, "parts": [{"text": m["content"]}]})
        cfg = genai.types.GenerateContentConfig(
            system_instruction=system, temperature=temperature,
            max_output_tokens=max_tokens, safety_settings=self.SAFETY,
        )
        # retry transient overload/rate-limit (503/429) with backoff
        for attempt in range(5):
            try:
                resp = self.client.models.generate_content(
                    model=self.model, contents=contents, config=cfg)
                break
            except Exception as e:
                code = getattr(e, "code", None) or getattr(e, "status_code", None)
                if code in (429, 503) or "503" in str(e) or "429" in str(e):
                    if attempt < 4:
                        _time.sleep(2 ** attempt * 3)
                        continue
                raise
        text = resp.text or ""
        um = getattr(resp, "usage_metadata", None)
        usage = TokenUsage(
            input_tokens=getattr(um, "prompt_token_count", 0) or 0,
            output_tokens=getattr(um, "candidates_token_count", 0) or 0,
            llm_calls=1,
        )
        return text, usage


# short-name registry so the CLI/eval can do get_backend("gpt4o")
_REGISTRY = {
    "gemini": lambda: GeminiBackend(),
    "gpt4o": lambda: OpenAIBackend("gpt-4o"),
    "gpt5": lambda: OpenAIBackend("gpt-5"),
    "claude": lambda: AnthropicBackend("claude-sonnet-4-20250514"),
    "qwen": lambda: OllamaBackend("qwen"),
    "qwen7b": lambda: OllamaBackend("qwen7b"),
    "qwen14b": lambda: OllamaBackend("qwen14b"),
    "deepseek": lambda: OllamaBackend("deepseek"),
    "codellama": lambda: OllamaBackend("codellama"),
    "codestral": lambda: OllamaBackend("codestral"),
}


def get_backend(name: str) -> Backend:
    if name not in _REGISTRY:
        raise ValueError(f"Unknown backend '{name}'. Options: {list(_REGISTRY)}")
    return _REGISTRY[name]()
