from __future__ import annotations

import requests

from config import settings
from services.llm_service import LLMProvider, LLMResponse


class OpenRouterError(Exception):
    """Raised when an OpenRouter request fails."""


class OpenRouterProvider(LLMProvider):
    """
    OpenRouter implementation of the application's LLMProvider.

    The rest of the backend communicates through LLMProvider,
    so the provider can be replaced later without changing
    chatbot/business logic.
    """

    def __init__(
        self,
        api_key: str | None = None,
        model: str | None = None,
        base_url: str | None = None,
        timeout: int = 30,
    ) -> None:
        self.api_key = (
            api_key
            if api_key is not None
            else settings.openrouter_api_key
        )

        self.model = (
            model
            if model is not None
            else settings.openrouter_model
        )

        self.base_url = (
            base_url
            if base_url is not None
            else settings.openrouter_base_url
        ).rstrip("/")

        self.timeout = timeout

    def generate(
        self,
        prompt: str,
        system_prompt: str | None = None,
    ) -> LLMResponse:
        if not self.api_key:
            raise OpenRouterError(
                "OpenRouter API key is not configured."
            )

        if not isinstance(prompt, str) or not prompt.strip():
            raise ValueError(
                "Prompt cannot be empty."
            )

        messages: list[dict[str, str]] = []

        if system_prompt is not None and system_prompt.strip():
            messages.append(
                {
                    "role": "system",
                    "content": system_prompt.strip(),
                }
            )

        messages.append(
            {
                "role": "user",
                "content": prompt.strip(),
            }
        )

        url = (
            f"{self.base_url}/chat/completions"
        )

        headers = {
            "Authorization": (
                f"Bearer {self.api_key}"
            ),
            "Content-Type": "application/json",
        }

        payload = {
            "model": self.model,
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
        except requests.RequestException as exc:
            raise OpenRouterError(
                f"Unable to connect to OpenRouter: {exc}"
            ) from exc

        if not response.ok:
            error_message = self._extract_error(
                response
            )

            raise OpenRouterError(
                f"OpenRouter request failed "
                f"(HTTP {response.status_code}): "
                f"{error_message}"
            )

        try:
            data = response.json()
        except ValueError as exc:
            raise OpenRouterError(
                "OpenRouter returned an invalid JSON response."
            ) from exc

        content = self._extract_content(data)

        return LLMResponse(
            content=content,
            provider="openrouter",
            model=self.model,
        )

    @staticmethod
    def _extract_content(
        data: dict,
    ) -> str:
        try:
            choices = data["choices"]

            if not choices:
                raise KeyError("choices is empty")

            content = choices[0]["message"]["content"]

        except (KeyError, IndexError, TypeError) as exc:
            raise OpenRouterError(
                "OpenRouter response did not contain "
                "expected message content."
            ) from exc

        if not isinstance(content, str):
            raise OpenRouterError(
                "OpenRouter returned non-text content."
            )

        return content

    @staticmethod
    def _extract_error(
        response: requests.Response,
    ) -> str:
        try:
            data = response.json()

            if isinstance(data, dict):
                error = data.get("error")

                if isinstance(error, dict):
                    message = error.get("message")

                    if message:
                        return str(message)

                if error:
                    return str(error)

        except ValueError:
            pass

        return response.text[:500]


openrouter_provider = OpenRouterProvider()