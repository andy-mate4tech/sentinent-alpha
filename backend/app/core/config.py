from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_version: str = "1.0.0"
    database_url: str = "postgresql+asyncpg://sentient:sentient@localhost:5432/sentient"
    redis_url: str = "redis://localhost:6379/0"
    jwt_secret: str = "dev-change-me"
    jwt_ttl_days: int = 30
    bootstrap_pairing_code: str = "change-me-lab"
    allow_insecure_noauth: bool = False
    api_cors_origins: str = "*"

    llm_mode: Literal["cli", "deepseek", "openai", "google", "anthropic"] = "cli"
    llm_cli_provider: Literal["kimi", "cursor"] = "kimi"
    llm_bridge_url: str = "http://host.docker.internal:8099/v1"
    llm_bridge_api_key: str = "sk-local-cli"

    deepseek_api_key: str = ""
    openai_api_key: str = ""
    google_api_key: str = ""
    anthropic_api_key: str = ""

    tauric_max_jobs_per_day: int = 20
    book_review_top_n: int = 3
    tradingagents_memory_log_path: str = "/data/trading_memory.md"
    tauric_checkpoint: bool = False

    quote_rate_per_min: int = 60
    copilot_rate_per_min: int = 20


@lru_cache
def get_settings() -> Settings:
    return Settings()
