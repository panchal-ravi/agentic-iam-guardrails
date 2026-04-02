from contextlib import asynccontextmanager
from typing import AsyncGenerator

import structlog
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from api.routes import router
from config.settings import settings
from app_logging.logger import bind_request_id, clear_request_id, configure_logging


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    configure_logging(settings.log_level)
    settings.log_configured_values()
    structlog.get_logger(__name__).info("identity_broker_starting", vault_addr=settings.vault_addr)
    yield
    structlog.get_logger(__name__).info("identity_broker_stopping")


app = FastAPI(
    title="Identity Broker",
    description="Exchanges a Vault token for a Vault-signed OIDC Identity JWT.",
    version="0.1.0",
    lifespan=lifespan,
)


@app.middleware("http")
async def correlation_id_middleware(request: Request, call_next):
    """Bind a per-request correlation ID to all log entries."""
    request_id = request.headers.get("X-Request-ID")
    if request_id is not None:
        bind_request_id(request_id)

    try:
        response = await call_next(request)
    finally:
        clear_request_id()

    if request_id is not None:
        response.headers["X-Request-ID"] = request_id

    return response


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    structlog.get_logger(__name__).exception("unhandled_exception", error=str(exc))
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})


app.include_router(router)
