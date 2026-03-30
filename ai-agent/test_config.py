import json
import logging
from pathlib import Path

from config import Settings, load_settings


def test_load_settings_logs_all_configured_values(monkeypatch, tmp_path, caplog):
    actor_token_path = tmp_path / "actor-token"
    configured_values = {
        "OPENAI_MODEL": "gpt-5.4",
        "ACTOR_TOKEN_PATH": str(actor_token_path),
        "TOKEN_EXCHANGE_URL": "https://example.test/v1/identity/obo-token",
        "TOKEN_EXCHANGE_TIMEOUT_SECONDS": "42.5",
        "OBO_ROLE_NAME": "runtime-role",
        "HOST": "127.0.0.1",
        "PORT": "9000",
        "LOG_LEVEL": "debug",
    }

    for key, value in configured_values.items():
        monkeypatch.setenv(key, value)

    with caplog.at_level(logging.DEBUG, logger="config"):
        settings = load_settings()

    assert settings == Settings(
        openai_model="gpt-5.4",
        actor_token_path=Path(str(actor_token_path)),
        token_exchange_url="https://example.test/v1/identity/obo-token",
        token_exchange_timeout_seconds=42.5,
        obo_role_name="runtime-role",
        host="127.0.0.1",
        port=9000,
        log_level="DEBUG",
    )
    assert len(caplog.records) == 1

    payload = json.loads(caplog.records[0].getMessage())
    assert payload == {
        "actor_token_path": str(actor_token_path),
        "event": "settings_loaded",
        "host": "127.0.0.1",
        "log_level": "DEBUG",
        "obo_role_name": "runtime-role",
        "openai_model": "gpt-5.4",
        "port": 9000,
        "timestamp": payload["timestamp"],
        "token_exchange_timeout_seconds": 42.5,
        "token_exchange_url": "https://example.test/v1/identity/obo-token",
    }
