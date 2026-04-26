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


async def fetch_mcp_tools(
    user_mcp_url: str,
    obo_token: str | None,
    request_id: str,
) -> list[Any]:
    """Build a fresh MCP client whose streamable-HTTP requests carry the
    given OBO bearer (if any) and the caller's X-Request-ID, then return
    the LangChain tool wrappers.

    A fresh client per request avoids cross-thread ContextVar propagation
    problems when LangChain's sync `tool.invoke()` bridges into the
    adapter's async transport.
    """
    MultiServerMCPClient = _import_multi_server_client()

    headers: dict[str, str] = {"X-Request-ID": request_id}
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
    for tool in tools:
        tool_name = getattr(tool, "name", None)
        log_event(
            LOGGER,
            "mcp_tool_loaded",
            message=f"Loaded MCP tool {tool_name}",
            request_id=request_id,
            user_mcp_url=user_mcp_url,
            authorization_present=bool(obo_token),
            tool_name=tool_name,
        )
    return list(tools)


def extract_required_scopes(template_tool: Any) -> list[str]:
    """Read `_meta.required_scopes` from a langchain-mcp-adapters tool.

    The adapter places the upstream MCP `_meta` field under the LangChain
    tool's `metadata["_meta"]` (see langchain_mcp_adapters.tools._convert_call_tool_result).
    Returns an empty list if the tool didn't declare any scope contract.
    """
    metadata = getattr(template_tool, "metadata", None) or {}
    if not isinstance(metadata, dict):
        return []
    meta = metadata.get("_meta") or {}
    if not isinstance(meta, dict):
        return []
    scopes = meta.get("required_scopes")
    if isinstance(scopes, list):
        return [str(s) for s in scopes]
    return []


async def invoke_mcp_tool(
    user_mcp_url: str,
    tool_name: str,
    args: dict,
    obo_token: str,
    request_id: str,
) -> Any:
    """Build a transient MCP client carrying *obo_token* and call a single
    tool by name. Used by the per-call scope wrapper so each MCP tools/call
    travels with its own narrowly-scoped OBO."""
    MultiServerMCPClient = _import_multi_server_client()

    headers: dict[str, str] = {
        "X-Request-ID": request_id,
        "Authorization": f"Bearer {obo_token}",
    }
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
    target = next(
        (t for t in tools if getattr(t, "name", None) == tool_name), None
    )
    if target is None:
        raise RuntimeError(
            f"MCP tool {tool_name!r} not found at {user_mcp_url}"
        )
    return await target.ainvoke(args)


