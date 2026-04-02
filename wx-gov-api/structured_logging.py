import json
import logging
import os
from contextvars import ContextVar, Token
from datetime import datetime, timezone
from typing import Any

REQUEST_ID_CONTEXT: ContextVar[str] = ContextVar("request_id", default="-")
REQUEST_FIELDS_CONTEXT: ContextVar[dict[str, Any]] = ContextVar(
    "request_fields", default={}
)

_RESERVED_LOG_RECORD_FIELDS = {
    "args",
    "asctime",
    "created",
    "exc_info",
    "exc_text",
    "filename",
    "funcName",
    "levelname",
    "levelno",
    "lineno",
    "module",
    "msecs",
    "message",
    "msg",
    "name",
    "pathname",
    "process",
    "processName",
    "relativeCreated",
    "stack_info",
    "thread",
    "threadName",
}


def _utc_timestamp() -> str:
    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": _utc_timestamp(),
            "level": record.levelname,
            "logger": record.name,
            "request_id": getattr(record, "request_id", get_request_id()),
            "event": getattr(record, "event", "application.log"),
            "message": record.getMessage(),
        }
        payload.update(get_request_fields())

        for key, value in record.__dict__.items():
            if key.startswith("_") or key in _RESERVED_LOG_RECORD_FIELDS or key in payload:
                continue
            payload[key] = value

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)

        if record.stack_info:
            payload["stack"] = self.formatStack(record.stack_info)

        return json.dumps(payload, ensure_ascii=True, default=str)


def configure_logging() -> None:
    level_name = os.getenv("LOG_LEVEL", "INFO").upper()
    log_level = logging._nameToLevel.get(level_name, logging.INFO)

    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())

    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.setLevel(log_level)
    root_logger.addHandler(handler)

    for logger_name in ("uvicorn", "uvicorn.error", "uvicorn.access", "fastapi"):
        app_logger = logging.getLogger(logger_name)
        app_logger.handlers.clear()
        app_logger.propagate = True


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)


def get_request_id() -> str:
    return REQUEST_ID_CONTEXT.get()


def set_request_id(request_id: str) -> Token[str]:
    return REQUEST_ID_CONTEXT.set(request_id)


def reset_request_id(token: Token[str]) -> None:
    REQUEST_ID_CONTEXT.reset(token)


def get_request_fields() -> dict[str, Any]:
    return dict(REQUEST_FIELDS_CONTEXT.get())


def set_request_fields(**fields: Any) -> Token[dict[str, Any]]:
    current_fields = get_request_fields()
    current_fields.update(fields)
    return REQUEST_FIELDS_CONTEXT.set(current_fields)


def reset_request_fields(token: Token[dict[str, Any]]) -> None:
    REQUEST_FIELDS_CONTEXT.reset(token)


def log_event(
    logger: logging.Logger,
    level: int,
    event: str,
    message: str,
    **fields: Any,
) -> None:
    logger.log(level, message, extra={"event": event, **fields})
