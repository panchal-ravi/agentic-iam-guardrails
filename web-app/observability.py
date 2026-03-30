"""Request-scoped logging helpers for the Streamlit app."""

from __future__ import annotations

import logging
import os
import uuid
from collections.abc import Mapping, MutableMapping
from contextvars import ContextVar
from typing import Any

_APP_LOGGER_NAME = "verify_vault"
_REQUEST_ID_HEADER = "X-Request-ID"
_request_id_var: ContextVar[str] = ContextVar("request_id", default="")


class _RequestIdFilter(logging.Filter):
    """Inject the active request ID into each log record."""

    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = _request_id_var.get() or "-"
        return True


def configure_logging() -> None:
    """Configure the application logger once per process."""
    app_logger = logging.getLogger(_APP_LOGGER_NAME)
    if getattr(app_logger, "_request_logging_configured", False):
        return

    handler = logging.StreamHandler()
    handler.setFormatter(
        logging.Formatter(
            "%(asctime)s %(levelname)s [%(name)s] request_id=%(request_id)s %(message)s"
        )
    )
    handler.addFilter(_RequestIdFilter())

    level_name = os.getenv("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, level_name, logging.INFO)

    app_logger.setLevel(level)
    app_logger.addHandler(handler)
    app_logger.propagate = False
    app_logger._request_logging_configured = True  # type: ignore[attr-defined]


def get_logger(name: str) -> logging.Logger:
    """Return a child logger of the app logger."""
    configure_logging()
    return logging.getLogger(f"{_APP_LOGGER_NAME}.{name}")


def _normalize_headers(headers: Mapping[str, Any] | None) -> dict[str, str]:
    """Return a lowercase header map for stable lookups."""
    if not headers:
        return {}

    normalized: dict[str, str] = {}
    for key in headers:
        value = headers.get(key)
        if value is not None:
            normalized[str(key).lower()] = str(value)
    return normalized


def resolve_request_id(headers: Mapping[str, Any] | None = None) -> str:
    """Resolve the current request ID from headers or generate a fallback."""
    normalized_headers = _normalize_headers(headers)
    incoming_request_id = normalized_headers.get(_REQUEST_ID_HEADER.lower(), "").strip()
    request_id = incoming_request_id or str(uuid.uuid4())
    _request_id_var.set(request_id)
    return request_id


def bind_request_context(
    session_state: MutableMapping[str, Any], headers: Mapping[str, Any] | None, url: str = ""
) -> str:
    """Persist and bind the current request ID for this Streamlit session."""
    normalized_headers = _normalize_headers(headers)
    incoming_request_id = normalized_headers.get(_REQUEST_ID_HEADER.lower(), "").strip()
    request_id = incoming_request_id or str(session_state.get("request_id") or "") or str(
        uuid.uuid4()
    )

    _request_id_var.set(request_id)
    session_state["request_id"] = request_id

    if session_state.get("_logged_request_id") != request_id:
        logger = get_logger("request")
        path = url or "streamlit-session"
        source = "header" if incoming_request_id else "generated"
        logger.info("Bound request context for %s using %s request ID", path, source)
        session_state["_logged_request_id"] = request_id

    return request_id


def get_request_id() -> str:
    """Return the active request ID, creating one if needed."""
    request_id = _request_id_var.get().strip()
    if request_id:
        return request_id
    return resolve_request_id()


def build_outbound_headers(headers: Mapping[str, str] | None = None) -> dict[str, str]:
    """Return headers with the active request ID propagated upstream."""
    outbound_headers = dict(headers or {})
    outbound_headers[_REQUEST_ID_HEADER] = get_request_id()
    return outbound_headers
