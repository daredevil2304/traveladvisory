from __future__ import annotations

import logging
import requests

from config import settings
from services.llm_service import LLMProvider, LLMResponse

logger = logging.getLogger(__name__)


class GroqError(Exception):
    """Raised when a Groq request fails."""


class GroqProvider(LLMProvider):
    """
    Groq implementation of the application's LLMProvider.
    Uses Groq's OpenAI-compatible chat-completions API with multi-model fallback.
    """

    CANDIDATE_MODELS = [
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b",
        "qwen/qwen3.8-27b",
    ]

    def __init__(
        self,
        api_key: str | None = None,
        model: str | None = None,
        base_url: str = "https://api.groq.com/openai/v1",
        timeout: int = 25,
    ) -> None:
        self.api_key = (
            api_key
            if api_key is not None
            else settings.groq_api_key
        )

        self.model = (
            model
            if model is not None
            else settings.groq_model
        )

        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    def generate(
        self,
        prompt: str,
        system_prompt: str | None = None,
    ) -> LLMResponse:
        if not self.api_key:
            raise GroqError("Groq API key is not configured.")

        if not isinstance(prompt, str) or not prompt.strip():
            raise ValueError("Prompt cannot be empty.")

        messages: list[dict[str, str]] = []
        if system_prompt is not None and system_prompt.strip():
            messages.append({"role": "system", "content": system_prompt.strip()})
        messages.append({"role": "user", "content": prompt.strip()})

        url = f"{self.base_url}/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        # Try active model first, then fallbacks
        models_to_try = [self.model] + [m for m in self.CANDIDATE_MODELS if m != self.model]
        last_error = None

        for model_candidate in models_to_try:
            payload = {
                "model": model_candidate,
                "messages": messages,
                "temperature": 0.2,
            }

            try:
                response = requests.post(
                    url,
                    headers=headers,
                    json=payload,
                    timeout=self.timeout,
                )
                if response.ok:
                    data = response.json()
                    content = self._extract_content(data)
                    return LLMResponse(
                        content=content,
                        provider="groq",
                        model=model_candidate,
                    )
                else:
                    err = self._extract_error(response)
                    logger.warning(f"Groq model {model_candidate} returned HTTP {response.status_code}: {err}")
                    last_error = f"HTTP {response.status_code}: {err}"
            except Exception as exc:
                logger.warning(f"Groq request to {model_candidate} failed: {exc}")
                last_error = str(exc)

        raise GroqError(f"All Groq models failed. Last error: {last_error}")

    @staticmethod
    def _extract_content(data: dict) -> str:
        try:
            choices = data["choices"]
            if not choices:
                raise KeyError("choices is empty")
            content = choices[0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise GroqError("Groq response did not contain expected message content.") from exc

        if not isinstance(content, str):
            raise GroqError("Groq response content is not a string.")

        return content.strip()

    @staticmethod
    def _extract_error(response: requests.Response) -> str:
        try:
            data = response.json()
            if isinstance(data, dict):
                error = data.get("error")
                if isinstance(error, dict):
                    message = error.get("message")
                    if isinstance(message, str) and message.strip():
                        return message.strip()
                if isinstance(error, str) and error.strip():
                    return error.strip()
        except ValueError:
            pass

        text = response.text
        if isinstance(text, str) and text.strip():
            return text.strip()

        return "Unknown Groq error."


groq_provider = GroqProvider()
