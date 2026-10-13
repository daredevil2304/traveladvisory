from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass(frozen=True)
class LLMResponse:
    """
    Standard response returned by any LLM provider.
    """

    content: str

    provider: str

    model: str | None = None


class LLMProvider(ABC):
    """
    Common interface for all LLM providers.

    The rest of the backend should communicate with this
    interface instead of directly depending on Ollama or
    any specific cloud provider.
    """

    @abstractmethod
    def generate(
        self,
        prompt: str,
        system_prompt: str | None = None,
    ) -> LLMResponse:
        """
        Generate a response from the configured LLM.
        """
        raise NotImplementedError


class FallbackLLMProvider(LLMProvider):
    """
    Temporary provider used while no real LLM provider
    is configured.

    It deliberately does not pretend to understand the
    user's message. This prevents fabricated answers from
    entering the travel intelligence pipeline.
    """

    def generate(
        self,
        prompt: str,
        system_prompt: str | None = None,
    ) -> LLMResponse:
        return LLMResponse(
            content="LLM provider is not configured yet.",
            provider="fallback",
            model=None,
        )


class LLMService:
    """
    Main LLM access point for the backend.

    Future providers such as:
        - cloud LLM
        - Ollama
        - another local model

    can be connected without changing the chatbot,
    observation extraction, or intelligence engine.
    """

    def __init__(
        self,
        provider: LLMProvider | None = None,
    ) -> None:
        self._provider = (
            provider
            if provider is not None
            else FallbackLLMProvider()
        )

    def set_provider(
        self,
        provider: LLMProvider,
    ) -> None:
        if not isinstance(provider, LLMProvider):
            raise TypeError(
                "provider must implement LLMProvider."
            )

        self._provider = provider

    def generate(
        self,
        prompt: str,
        system_prompt: str | None = None,
    ) -> LLMResponse:
        if not isinstance(prompt, str):
            raise ValueError(
                "Prompt must be a string."
            )

        if not prompt.strip():
            raise ValueError(
                "Prompt cannot be empty."
            )

        if system_prompt is not None:
            if not isinstance(system_prompt, str):
                raise ValueError(
                    "System prompt must be a string."
                )

            if not system_prompt.strip():
                system_prompt = None

        return self._provider.generate(
            prompt=prompt,
            system_prompt=system_prompt,
        )

    @property
    def provider_name(self) -> str:
        return self._provider.__class__.__name__


llm_service = LLMService()