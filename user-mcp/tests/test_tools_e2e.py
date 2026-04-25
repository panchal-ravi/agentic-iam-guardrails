from __future__ import annotations

import json

import pytest
from fastmcp import Client, FastMCP

from storage.file_repo import FileUserRepository
from tools.users import register_tools


@pytest.fixture
async def mcp_with_repo(users_file):
    repo = FileUserRepository(file_path=users_file)
    await repo.startup()
    mcp = FastMCP(name="user-mcp-test")
    register_tools(mcp, repo)
    return mcp


def _record_payload(call_result) -> dict:
    """FastMCP returns CallToolResult.content as a list of TextContent. The
    structured JSON payload is serialized in the first text block."""
    content = call_result.content[0].text if call_result.content else None
    return json.loads(content) if content else {}


async def test_list_all_users_via_mcp_client(mcp_with_repo):
    async with Client(mcp_with_repo) as client:
        tools = await client.list_tools()
        names = {t.name for t in tools}
        assert names == {
            "list_all_users",
            "search_users_by_first_name",
            "create_user",
            "delete_user_by_email",
            "update_user_by_email",
        }

        result = await client.call_tool("list_all_users", {})
        assert result.is_error is False


async def test_search_users_by_first_name_via_mcp_client(mcp_with_repo):
    async with Client(mcp_with_repo) as client:
        result = await client.call_tool(
            "search_users_by_first_name", {"first_name": "Noah"}
        )
        assert result.is_error is False


async def test_create_user_via_mcp_client(mcp_with_repo):
    async with Client(mcp_with_repo) as client:
        result = await client.call_tool(
            "create_user",
            {"user": {"email": "ava.brown@example.com", "first_name": "Ava"}},
        )
        assert result.is_error is False

        listing = await client.call_tool("list_all_users", {})
        assert listing.is_error is False


async def test_create_user_duplicate_returns_error(mcp_with_repo):
    async with Client(mcp_with_repo) as client:
        with pytest.raises(Exception, match="already exists"):
            await client.call_tool(
                "create_user",
                {"user": {"email": "emma.taylor@example.com", "first_name": "Other"}},
            )


async def test_delete_user_via_mcp_client(mcp_with_repo):
    async with Client(mcp_with_repo) as client:
        result = await client.call_tool(
            "delete_user_by_email", {"email": "emma.taylor@example.com"}
        )
        assert result.is_error is False

        with pytest.raises(Exception, match="not found"):
            await client.call_tool(
                "delete_user_by_email", {"email": "ghost@example.com"}
            )


async def test_update_user_via_mcp_client(mcp_with_repo):
    async with Client(mcp_with_repo) as client:
        result = await client.call_tool(
            "update_user_by_email",
            {
                "email": "noah.thompson206@example.com",
                "user": {
                    "email": "noah.updated@example.com",
                    "first_name": "Noah",
                    "phone": "+1-000-000-0000",
                },
            },
        )
        assert result.is_error is False
