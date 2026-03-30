from __future__ import annotations

import logging
import uuid

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, StreamingResponse
from langchain_openai import ChatOpenAI

from agent_runtime import AgentRuntime
from config import Settings, load_settings
from errors import AppError
from identity import OboTokenService
from logging_utils import log_event
from models import ChatRequest
from security import extract_bearer_token, validate_access_token
from tools import TOOLS

SETTINGS = load_settings()
LOGGER = logging.getLogger("agent_api")
llm = ChatOpenAI(model=SETTINGS.openai_model, streaming=True)
llm_with_tools = llm.bind_tools(TOOLS)


def _error_response(request: Request, status_code: int, error: str, message: str) -> JSONResponse:
    request_id = getattr(request.state, "request_id", None)
    log_event(
        LOGGER,
        "request_failed",
        level=logging.ERROR,
        request_id=request_id,
        path=request.url.path,
        status_code=status_code,
        error=error,
        message=message,
    )
    return JSONResponse(
        status_code=status_code,
        content={"error": error, "message": message},
    )


def create_app(
    settings: Settings | None = None,
    runtime: AgentRuntime | None = None,
    token_service: OboTokenService | None = None,
) -> FastAPI:
    active_settings = settings or SETTINGS
    app = FastAPI()
    app.state.settings = active_settings
    app.state.agent_runtime = runtime or AgentRuntime(
        llm=llm,
        llm_with_tools=llm_with_tools,
        logger=LOGGER,
    )
    app.state.token_service = token_service or OboTokenService(
        settings=active_settings,
        logger=LOGGER,
    )

    @app.middleware("http")
    async def request_logging_middleware(request: Request, call_next):
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        request.state.request_id = request_id
        log_event(
            LOGGER,
            "request_received",
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
                request_id=request_id,
                path=request.url.path,
                status_code=response.status_code,
            )
        return response

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
        access_token = extract_bearer_token(request)
        validate_access_token(access_token)
        obo_token = request.app.state.token_service.resolve_token(
            access_token,
            request.state.request_id,
        )
        return request.app.state.agent_runtime.handle_request(
            chat_request=chat_request,
            obo_token=obo_token,
            request_id=request.state.request_id,
            request_path=request.url.path,
        )

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=SETTINGS.host, port=SETTINGS.port)
