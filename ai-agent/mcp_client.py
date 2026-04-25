from __future__ import annotations

import logging
from typing import Any

from logging_utils import log_event

LOGGER = logging.getLogger("agent_api.mcp_client")


def _import_multi_server_client():
    try:
        from langchain_mcp_adapters.client import MultiServerMCPClient
    except ImportError as exc:  # pragma: no cover - dep is required in prod
        raise RuntimeError(
            "langchain-mcp-adapters is required to load MCP tools. "
            "Install it via `uv sync`."
        ) from exc
    return MultiServerMCPClient


async def fetch_mcp_tools(user_mcp_url: str, obo_token: str | None) -> list[Any]:
    """Build a fresh MCP client whose streamable-HTTP requests carry the
    given OBO bearer (if any) and return the LangChain tool wrappers.

    A fresh client per request avoids cross-thread ContextVar propagation
    problems when LangChain's sync `tool.invoke()` bridges into the
    adapter's async transport.
    """
    MultiServerMCPClient = _import_multi_server_client()

    headers: dict[str, str] = {}
    if obo_token:
        headers["Authorization"] = f"Bearer {obo_token}"

    client = MultiServerMCPClient(
        {
            "user-mcp": {
                "url": user_mcp_url,
                "transport": "streamable_http",
                "headers": headers,
            }
        }
    )
    tools = await client.get_tools()
    log_event(
        LOGGER,
        "mcp_tools_loaded",
        level=logging.DEBUG,
        message="Loaded MCP tools for request",
        user_mcp_url=user_mcp_url,
        authorization_present=bool(obo_token),
        tool_count=len(tools),
        tool_names=[getattr(t, "name", None) for t in tools],
    )
    return list(tools)


async def probe_mcp_tools(user_mcp_url: str) -> list[str]:
    """Best-effort startup probe: list tool names available on user-mcp.

    Used at app startup so failures (unreachable server, bad URL) surface
    early rather than at first request. Probing without an OBO token will
    fail when JWT validation is enforced; in that case we just log a
    warning and continue.
    """
    MultiServerMCPClient = _import_multi_server_client()
    try:
        client = MultiServerMCPClient(
            {
                "user-mcp": {
                    "url": user_mcp_url,
                    "transport": "streamable_http",
                    "headers": {},
                }
            }
        )
        tools = await client.get_tools()
    except Exception as exc:  # noqa: BLE001 - probe is best-effort
        log_event(
            LOGGER,
            "mcp_probe_failed",
            level=logging.WARNING,
            message=f"Could not probe user-mcp at startup: {exc}",
            user_mcp_url=user_mcp_url,
        )
        return []

    names = [getattr(t, "name", None) for t in tools]
    log_event(
        LOGGER,
        "mcp_probe_succeeded",
        message="Probed user-mcp tool list at startup",
        user_mcp_url=user_mcp_url,
        tool_count=len(names),
        tool_names=names,
    )
    return [n for n in names if n]
