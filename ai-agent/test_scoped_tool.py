from __future__ import annotations

import asyncio
import logging
from typing import Any
from unittest.mock import patch

import pytest

import agent_api
from errors import AppError
from identity import OboTokenService
from scoped_tool import make_scoped_tool


def _run(coro):
    return asyncio.run(coro)


class TemplateTool:
    """Stand-in for a langchain-mcp-adapters StructuredTool."""

    def __init__(self, name: str, description: str = ""):
        self.name = name
        self.description = description or f"Template for {name}"
        self.args_schema = None


class TokenServiceStub:
    def __init__(self, raise_on_resolve: AppError | None = None):
        self.calls: list[dict] = []
        self._raise = raise_on_resolve

    def resolve_token(self, *, subject_token, request_id, scopes):
        self.calls.append(
            {
                "subject_token": subject_token,
                "request_id": request_id,
                "scopes": list(scopes),
            }
        )
        if self._raise is not None:
            raise self._raise
        return f"obo:{subject_token}:{','.join(sorted(scopes))}"


@pytest.fixture
def template():
    return TemplateTool("list_all_users")


def test_per_call_obo_uses_required_scopes(template):
    service = TokenServiceStub()
    captured: dict = {}

    async def fake_invoke(*, user_mcp_url, tool_name, args, obo_token, request_id):
        captured["url"] = user_mcp_url
        captured["tool_name"] = tool_name
        captured["args"] = args
        captured["obo_token"] = obo_token
        captured["request_id"] = request_id
        return [{"email": "a@b.com"}]

    with patch("scoped_tool.invoke_mcp_tool", fake_invoke):
        wrapped = make_scoped_tool(
            template_tool=template,
            required_scopes=["users.read"],
            token_service=service,
            subject_token="user-jwt",
            request_id="req-1",
            user_mcp_url="http://user-mcp.local/mcp",
        )
        result = _run(wrapped.ainvoke({}))

    assert result == [{"email": "a@b.com"}]
    assert service.calls == [
        {
            "subject_token": "user-jwt",
            "request_id": "req-1",
            "scopes": ["users.read"],
        }
    ]
    assert captured["obo_token"] == "obo:user-jwt:users.read"
    assert captured["tool_name"] == "list_all_users"
    assert captured["request_id"] == "req-1"


def test_token_exchange_failure_returns_permission_denied_string():
    service = TokenServiceStub(
        raise_on_resolve=AppError(
            status_code=403,
            error="forbidden",
            message="user lacks users.write",
        )
    )

    async def should_not_be_called(**kwargs):
        raise AssertionError("invoke_mcp_tool should not run when exchange fails")

    with patch("scoped_tool.invoke_mcp_tool", should_not_be_called):
        wrapped = make_scoped_tool(
            template_tool=TemplateTool("create_user"),
            required_scopes=["users.write"],
            token_service=service,
            subject_token="user-jwt",
            request_id="req-2",
            user_mcp_url="http://user-mcp.local/mcp",
        )
        result = _run(wrapped.ainvoke({}))

    assert isinstance(result, str)
    assert "Permission denied" in result
    assert "users.write" in result
    assert "create_user" in result


def test_mcp_insufficient_scope_returns_permission_denied_string():
    service = TokenServiceStub()

    async def fake_invoke(**kwargs):
        raise RuntimeError(
            "Tool 'create_user' requires scope(s) ['users.write'] but the OBO "
            "token grants ['users.read']. (insufficient_scope)"
        )

    with patch("scoped_tool.invoke_mcp_tool", fake_invoke):
        wrapped = make_scoped_tool(
            template_tool=TemplateTool("create_user"),
            required_scopes=["users.write"],
            token_service=service,
            subject_token="user-jwt",
            request_id="req-3",
            user_mcp_url="http://user-mcp.local/mcp",
        )
        result = _run(wrapped.ainvoke({}))

    assert isinstance(result, str)
    assert "Permission denied" in result
    assert "users.write" in result


def test_other_mcp_errors_propagate():
    service = TokenServiceStub()

    async def fake_invoke(**kwargs):
        raise RuntimeError("something else went wrong")

    with patch("scoped_tool.invoke_mcp_tool", fake_invoke):
        wrapped = make_scoped_tool(
            template_tool=TemplateTool("list_all_users"),
            required_scopes=["users.read"],
            token_service=service,
            subject_token="user-jwt",
            request_id="req-4",
            user_mcp_url="http://user-mcp.local/mcp",
        )
        with pytest.raises(RuntimeError, match="something else"):
            _run(wrapped.ainvoke({}))


def test_extract_required_scopes_reads_meta():
    from mcp_client import extract_required_scopes

    class FakeTool:
        metadata = {"_meta": {"required_scopes": ["users.read", "users.write"]}}

    assert extract_required_scopes(FakeTool()) == ["users.read", "users.write"]


def test_extract_required_scopes_handles_missing_meta():
    from mcp_client import extract_required_scopes

    class A:
        metadata = None

    class B:
        metadata = {}

    class C:
        metadata = {"_meta": None}

    class D:
        metadata = {"_meta": {"other": "value"}}

    assert extract_required_scopes(A()) == []
    assert extract_required_scopes(B()) == []
    assert extract_required_scopes(C()) == []
    assert extract_required_scopes(D()) == []


def _build_settings(tmp_path):
    actor_token_path = tmp_path / "actor"
    actor_token_path.write_text("actor-token", encoding="utf-8")
    return type(agent_api.SETTINGS)(
        model="x",
        actor_token_path=actor_token_path,
        token_exchange_url="http://t.local/obo",
        token_exchange_timeout_seconds=1.0,
        obo_role_name="r",
        bypass_auth_token_exchange=False,
        host="0",
        port=0,
        log_level="INFO",
        user_mcp_url="http://u.local/mcp",
    )


def test_resolve_token_caches_per_scope_set(tmp_path):
    service = OboTokenService(
        settings=_build_settings(tmp_path), logger=logging.getLogger("test")
    )
    calls: list[str] = []

    def fake_exchange(subject_token, actor_token, request_id, scope):
        calls.append(scope)
        import time

        return f"obo-{scope}", time.time() + 600

    service.perform_token_exchange = fake_exchange  # type: ignore[assignment]

    a = service.resolve_token(subject_token="u", request_id="r", scopes=["users.read"])
    b = service.resolve_token(subject_token="u", request_id="r", scopes=["users.read"])
    c = service.resolve_token(subject_token="u", request_id="r", scopes=["users.write"])

    assert a == b == "obo-users.read"
    assert c == "obo-users.write"
    assert calls == ["users.read", "users.write"]


def test_resolve_token_normalizes_scope_order(tmp_path):
    service = OboTokenService(
        settings=_build_settings(tmp_path), logger=logging.getLogger("test")
    )
    calls: list[str] = []

    def fake_exchange(subject_token, actor_token, request_id, scope):
        calls.append(scope)
        import time

        return f"obo-{scope}", time.time() + 600

    service.perform_token_exchange = fake_exchange  # type: ignore[assignment]

    first = service.resolve_token(
        subject_token="u", request_id="r", scopes=["users.write", "users.read"]
    )
    second = service.resolve_token(
        subject_token="u", request_id="r", scopes=["users.read", "users.write"]
    )

    assert first == second
    # Single exchange because both calls normalize to the same scope key.
    assert calls == ["users.read users.write"]
