from services.llm_service import LLMService
from services.openrouter_provider import openrouter_provider

service = LLMService(
    provider=openrouter_provider
)

try:
    response = service.generate(
        prompt='Return exactly this JSON: {"test": "ok"}',
        system_prompt="Return only valid JSON."
    )

    print("SUCCESS")
    print("Provider:", response.provider)
    print("Model:", response.model)
    print("Content:")
    print(response.content)

except Exception as e:
    print("FAILED")
    print("Exception type:", type(e).__name__)
    print("Exception:", repr(e))
