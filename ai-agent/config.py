from __future__ import annotations

import logging
import os
from dataclasses import asdict, dataclass
from pathlib import Path

from dotenv import load_dotenv
from logging_utils import configure_logging, log_event

load_dotenv()
LOGGER = logging.getLogger("config")


@dataclass
class Settings:
    openai_model: str
    actor_token_path: Path
    token_exchange_url: str
    token_exchange_timeout_seconds: float
    obo_role_name: str
    host: str
    port: int
    log_level: str


def load_settings() -> Settings:
    settings = Settings(
        openai_model=os.getenv("OPENAI_MODEL", "gpt-5-mini"),
        actor_token_path=Path(
            os.getenv("ACTOR_TOKEN_PATH", "/vault/secrets/actor-token")
        ),
        token_exchange_url=os.getenv(
            "TOKEN_EXCHANGE_URL", "http://localhost:8080/v1/identity/obo-token"
        ),
        token_exchange_timeout_seconds=float(
            os.getenv("TOKEN_EXCHANGE_TIMEOUT_SECONDS", "10")
        ),
        obo_role_name=os.getenv("OBO_ROLE_NAME", "agent-runtime"),
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", "8000")),
        log_level=os.getenv("LOG_LEVEL", "INFO").upper(),
    )
    configure_logging(settings.log_level)
    serialized_settings = asdict(settings)
    serialized_settings["actor_token_path"] = str(settings.actor_token_path)
    log_event(LOGGER, "settings_loaded", **serialized_settings)
    return settings
