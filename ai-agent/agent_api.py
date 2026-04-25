from __future__ import annotations

import logging
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, StreamingResponse
from langchain.chat_models import init_chat_model

from agent_runtime import AgentRuntime
from config import Settings, load_settings
from errors import AppError
from identity import OboTokenService
from logging_utils import (
    bind_log_context,
    build_uvicorn_log_config,
    log_event,
    reset_log_context,
)
from mcp_client import fetch_mcp_tools, probe_mcp_tools
from models import AgentTokensResponse, ChatRequest
from security import (
    extract_agent_identity_claims,
    extract_bearer_token,
    extract_user_identity_claims,
    validate_access_token,
)
from tools import TOOLS as LOCAL_TOOLS

SETTINGS = load_settings()
LOGGER = logging.getLogger("agent_api")


def _get_client_ip(request: Request) -> str | None:
    return request.client.host if request.client is not None else None


def _build_base_llm(settings: Settings):
    return init_chat_model(settings.model, streaming=True)


def _build_runtime_for_request(
    llm,
    tools: list,
) -> AgentRuntime:
    return AgentRuntime(
        llm_with_tools=llm.bind_tools(tools),
        logger=LOGGER,
        tool_registry={tool.name: tool for tool in tools},
    )


def _error_response(request: Request, status_code: int, error: str, message: str) -> JSONResponse:
    request_id = getattr(request.state, "request_id", None)
    log_event(
        LOGGER,
        "request_failed",
        level=logging.ERROR,
        message="Request failed",
        request_id=request_id,
        path=request.url.path,
        status_code=status_code,
        error=error,
        error_message=message,
    )
    return JSONResponse(
        status_code=status_code,
        content={"error": error, "message": message},
    )


def _load_startup_agent_id(token_service: OboTokenService) -> str | None:
    try:
        actor_token = token_service.read_actor_token()
    except AppError as exc:
        log_event(
            LOGGER,
            "actor_token_unavailable_at_startup",
            level=logging.WARNING,
            message="Actor token unavailable at startup; agent_id will be omitted from log prefix.",
            error=exc.error,
            error_message=exc.message,
        )
        return None
    return extract_agent_identity_claims(actor_token)["actor_agent_id"]


def create_app(
    settings: Settings | None = None,
    runtime: AgentRuntime | None = None,
    token_service: OboTokenService | None = None,
    llm: object | None = None,
) -> FastAPI:
    active_settings = settings or SETTINGS

    @asynccontextmanager
    async def lifespan(app_inner: FastAPI):
        await probe_mcp_tools(active_settings.user_mcp_url)
        yield

    app = FastAPI(lifespan=lifespan)
    app.state.settings = active_settings
    app.state.llm = llm or _build_base_llm(active_settings)
    # When set (in tests), this fixed runtime is used instead of building one
    # per request. In production it stays None and the route fetches MCP tools
    # per-request and binds a fresh runtime.
    app.state.agent_runtime = runtime
    app.state.token_service = token_service or OboTokenService(
        settings=active_settings,
        logger=LOGGER,
    )
    app.state.actor_agent_id = _load_startup_agent_id(app.state.token_service)

    @app.middleware("http")
    async def request_logging_middleware(request: Request, call_next):
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        request.state.request_id = request_id
        request.state.client_ip = _get_client_ip(request)
        context_token = bind_log_context(
            request_id=request_id,
            path=request.url.path,
            http_method=request.method,
            client_ip=request.state.client_ip,
            actor_agent_id=request.app.state.actor_agent_id,
        )
        try:
            log_event(
                LOGGER,
                "request_received",
                level=logging.DEBUG,
                message="Request received",
                request_id=request_id,
                path=request.url.path,
                method=request.method,
            )
            response = await call_next(request)
            response.headers["X-Request-ID"] = request_id
            if request.url.path != "/v1/agent/query" and not isinstance(
                response, StreamingResponse
            ):
                log_event(
                    LOGGER,
                    "response_sent",
                    level=logging.DEBUG,
                    message="Response sent",
                    request_id=request_id,
                    path=request.url.path,
                    status_code=response.status_code,
                )
            return response
        finally:
            reset_log_context(context_token)

    @app.exception_handler(AppError)
    async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
        return _error_response(request, exc.status_code, exc.error, exc.message)

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        return _error_response(
            request,
            status_code=400,
            error="invalid_request",
            message=str(exc),
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(
        request: Request, exc: Exception
    ) -> JSONResponse:
        return _error_response(
            request,
            status_code=500,
            error="agent_error",
            message="Agent execution failed.",
        )

    @app.post("/v1/agent/query")
    async def query_agent(request: Request, chat_request: ChatRequest):
        obo_token: str | None = None
        preferred_username: str | None = None
        if not request.app.state.settings.bypass_auth_token_exchange:
            access_token = extract_bearer_token(request)
            access_token_payload = validate_access_token(access_token)
            obo_token = request.app.state.token_service.resolve_token(
                access_token,
                request.state.request_id,
            )
            preferred_username = extract_user_identity_claims(
                access_token_payload
            )["preferred_username"]
        bind_log_context(preferred_username=preferred_username)

        runtime = request.app.state.agent_runtime
        if runtime is None:
            mcp_tools = await fetch_mcp_tools(
                request.app.state.settings.user_mcp_url,
                obo_token,
            )
            tools = list(LOCAL_TOOLS) + mcp_tools
            runtime = _build_runtime_for_request(request.app.state.llm, tools)

        return await runtime.handle_request(
            chat_request=chat_request,
            obo_token=obo_token,
            request_id=request.state.request_id,
            request_path=request.url.path,
            request_method=request.method,
            client_ip=request.state.client_ip,
        )

    @app.get("/v1/agent/tokens", response_model=AgentTokensResponse)
    async def get_cached_tokens(request: Request) -> AgentTokensResponse:
        if request.app.state.settings.bypass_auth_token_exchange:
            raise AppError(
                status_code=404,
                error="token_not_found",
                message="No cached OBO token found for the provided bearer token.",
            )

        access_token = extract_bearer_token(request)
        validate_access_token(access_token)
        obo_token = request.app.state.token_service.get_cached_token(
            access_token,
            request.state.request_id,
        )
        actor_token = request.app.state.token_service.read_actor_token()
        return AgentTokensResponse(obo_token=obo_token, actor_token=actor_token)

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host=SETTINGS.host,
        port=SETTINGS.port,
        log_level=SETTINGS.log_level.lower(),
        log_config=build_uvicorn_log_config(SETTINGS.log_level),
    )
