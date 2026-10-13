from services.llm_service import (
    FallbackLLMProvider,
    LLMProvider,
    LLMResponse,
    LLMService,
)


def test_fallback_provider():
    service = LLMService()

    result = service.generate(
        "Understand this traveler observation."
    )

    assert isinstance(result, LLMResponse)
    assert result.provider == "fallback"
    assert result.content == (
        "LLM provider is not configured yet."
    )


def test_provider_name():
    service = LLMService()

    assert service.provider_name == (
        "FallbackLLMProvider"
    )


def test_set_provider():
    service = LLMService()

    provider = FallbackLLMProvider()

    service.set_provider(provider)

    assert service.provider_name == (
        "FallbackLLMProvider"
    )


def test_empty_prompt():
    service = LLMService()

    try:
        service.generate("")
        assert False, "Expected ValueError"
    except ValueError:
        pass


def test_whitespace_prompt():
    service = LLMService()

    try:
        service.generate("   ")
        assert False, "Expected ValueError"
    except ValueError:
        pass