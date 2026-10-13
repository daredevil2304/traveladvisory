from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Mumbai-Pune Travel Intelligence API"
    app_version: str = "1.0.0"
    debug: bool = True

    database_url: str = (
        "postgresql://postgres:postgres@localhost:5432/"
        "mumbai_pune_travel"
    )

    openrouter_api_key: str = ""
    openrouter_model: str = "openrouter/free"
    openrouter_base_url: str = (
        "https://openrouter.ai/api/v1"
    )

    groq_api_key: str = ""
    groq_model: str = "openai/gpt-oss-120b"

    openweather_api_key: str = ""
    openweather_base_url: str = (
        "https://api.openweathermap.org/data/2.5"
    )

    fast2sms_api_key: str = ""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()