from services.openrouter_provider import (
    OpenRouterProvider,
)


def test_provider_configuration():
    provider = OpenRouterProvider(
        api_key="test-key",
        model="test-model",
        base_url="https://example.com",
    )

    assert provider.api_key == "test-key"
    assert provider.model == "test-model"
    assert provider.base_url == "https://example.com"


def test_empty_api_key():
    provider = OpenRouterProvider(
        api_key="",
    )

    try:
        provider.generate("Hello")
        assert False, "Expected OpenRouterError"
    except Exception as exc:
        assert (
            "API key is not configured"
            in str(exc)
        )


def test_empty_prompt():
    provider = OpenRouterProvider(
        api_key="test-key",
    )

    try:
        provider.generate("")
        assert False, "Expected ValueError"
    except ValueError:
        pass