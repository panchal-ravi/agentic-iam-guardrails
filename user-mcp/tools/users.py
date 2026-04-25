from __future__ import annotations

import logging

from fastmcp import FastMCP
from fastmcp.exceptions import ToolError

from errors import AppError
from logging_utils import log_event
from models import UserRecord
from storage.base import UserRepository

LOGGER = logging.getLogger("user_mcp.tools.users")


def register_tools(mcp: FastMCP, repo: UserRepository) -> None:
    """Attach the user-management tools to the given FastMCP server.

    Tools are async closures over `repo`. AppError raised by the repository
    is translated into FastMCP `ToolError` so the model-facing error message
    preserves the validation-style intent (already-exists, not-found, etc.).
    """

    @mcp.tool(
        name="list_all_users",
        description=(
            "Return every user currently stored in the user repository. "
            "Use this whenever the caller asks to list, show, or inspect all users."
        ),
    )
    async def list_all_users() -> list[UserRecord]:
        return await _run_tool(
            "list_all_users",
            lambda: repo.list_all(),
            result_summary=lambda result: {"count": len(result)},
        )

    @mcp.tool(
        name="search_users_by_first_name",
        description=(
            "Return users whose first name matches the provided value (case-insensitive, exact). "
            "Use this whenever the caller asks to find or look up users by first name."
        ),
    )
    async def search_users_by_first_name(first_name: str) -> list[UserRecord]:
        return await _run_tool(
            "search_users_by_first_name",
            lambda: repo.search_by_first_name(first_name),
            result_summary=lambda result: {"count": len(result), "first_name": first_name},
        )

    @mcp.tool(
        name="create_user",
        description=(
            "Create a new user in the user repository and return the created record. "
            "Use this when the caller asks to add a user. Email must be unique."
        ),
    )
    async def create_user(user: UserRecord) -> UserRecord:
        return await _run_tool(
            "create_user",
            lambda: repo.create(user),
            result_summary=lambda result: {"email": result.email},
        )

    @mcp.tool(
        name="delete_user_by_email",
        description=(
            "Delete a user by email and return the deleted record. "
            "Use this when the caller asks to remove or delete a user by email."
        ),
    )
    async def delete_user_by_email(email: str) -> UserRecord:
        return await _run_tool(
            "delete_user_by_email",
            lambda: repo.delete_by_email(email),
            result_summary=lambda result: {"email": result.email},
        )

    @mcp.tool(
        name="update_user_by_email",
        description=(
            "Update a user identified by email and return the updated record. "
            "Use this when the caller asks to modify a user by email."
        ),
    )
    async def update_user_by_email(email: str, user: UserRecord) -> UserRecord:
        return await _run_tool(
            "update_user_by_email",
            lambda: repo.update_by_email(email, user),
            result_summary=lambda result: {"email": result.email},
        )


async def _run_tool(tool_name, action, result_summary):
    log_event(
        LOGGER,
        "tool_invoked",
        message=f"{tool_name} invoked",
        tool=tool_name,
    )
    try:
        result = await action()
    except AppError as exc:
        log_event(
            LOGGER,
            "tool_failed",
            level=logging.ERROR,
            message=f"{tool_name} failed: {exc.message}",
            tool=tool_name,
            error=exc.error,
            status_code=exc.status_code,
        )
        raise ToolError(exc.message) from exc
    except Exception as exc:  # pragma: no cover - defensive guard
        log_event(
            LOGGER,
            "tool_failed",
            level=logging.ERROR,
            message=f"{tool_name} failed unexpectedly: {exc}",
            tool=tool_name,
            error="agent_error",
            status_code=500,
        )
        raise ToolError(f"{tool_name} failed: {exc}") from exc

    summary = result_summary(result) if result_summary else {}
    log_event(
        LOGGER,
        "tool_completed",
        level=logging.DEBUG,
        message=f"{tool_name} completed",
        tool=tool_name,
        **summary,
    )
    return result
