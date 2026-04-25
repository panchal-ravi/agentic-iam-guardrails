from __future__ import annotations

import logging
from typing import Literal

from dotenv import load_dotenv
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

from logging_utils import configure_logging, log_event

load_dotenv()
LOGGER = logging.getLogger("user_mcp.config")


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="",
        env_file=".env",
        extra="ignore",
        case_sensitive=False,
    )

    # HTTP / process
    host: str = Field(default="0.0.0.0", alias="USER_MCP_HOST")
    port: int = Field(default=8090, alias="USER_MCP_PORT")
    mount_path: str = Field(default="/mcp", alias="USER_MCP_PATH")
    log_level: str = Field(default="INFO", alias="USER_MCP_LOG_LEVEL")

    # JWT validation
    verify_base_url: str = Field(default="", alias="USER_MCP_VERIFY_BASE_URL")
    verify_jwks_url: str = Field(default="", alias="USER_MCP_VERIFY_JWKS_URL")
    audience: str = Field(default="", alias="USER_MCP_AUDIENCE")
    issuer: str = Field(default="", alias="USER_MCP_ISSUER")
    jwks_cache_seconds: int = Field(default=3600, alias="USER_MCP_JWKS_CACHE_SECONDS")
    bypass_auth: bool = Field(default=False, alias="USER_MCP_BYPASS_AUTH")

    # Storage backend
    user_backend: Literal["file", "postgres"] = Field(default="file", alias="USER_BACKEND")
    users_file: str = Field(default="./users_repository.json", alias="USER_MCP_USERS_FILE")
    pg_dsn: str = Field(default="", alias="USER_MCP_PG_DSN")
    pg_auto_migrate: bool = Field(default=True, alias="USER_MCP_AUTO_MIGRATE")

    @field_validator("log_level")
    @classmethod
    def _normalize_level(cls, value: str) -> str:
        return value.upper()

    @property
    def effective_issuer(self) -> str:
        return self.issuer or self.verify_base_url

    @property
    def effective_jwks_url(self) -> str:
        if self.verify_jwks_url:
            return self.verify_jwks_url
        if not self.verify_base_url:
            return ""
        return self.verify_base_url.rstrip("/") + "/oauth2/jwks"


def load_settings() -> Settings:
    settings = Settings()
    configure_logging(settings.log_level)
    log_event(
        LOGGER,
        "settings_loaded",
        message="Settings loaded",
        host=settings.host,
        port=settings.port,
        mount_path=settings.mount_path,
        log_level=settings.log_level,
        user_backend=settings.user_backend,
        users_file=settings.users_file if settings.user_backend == "file" else None,
        pg_dsn_configured=bool(settings.pg_dsn) if settings.user_backend == "postgres" else None,
        verify_issuer=settings.effective_issuer or None,
        verify_audience=settings.audience or None,
        verify_jwks_url=settings.effective_jwks_url or None,
        bypass_auth=settings.bypass_auth,
    )
    return settings
