from __future__ import annotations

import json
import subprocess
from pathlib import Path
from threading import RLock
from typing import Any

from langchain_core.tools import tool

from errors import AppError

MODULE_DIR = Path(__file__).resolve().parent
USER_REPOSITORY_PATH = MODULE_DIR / "users_repository.json"
_USER_REPOSITORY_LOCK = RLock()
_USER_REPOSITORY: list[dict[str, Any]] | None = None


def _read_users_from_disk() -> list[dict[str, Any]]:
    if not USER_REPOSITORY_PATH.exists():
        raise AppError(
            status_code=500,
            error="agent_error",
            message=f"User repository not found at {USER_REPOSITORY_PATH}",
        )

    with USER_REPOSITORY_PATH.open("r", encoding="utf-8") as fp:
        data = json.load(fp)

    if not isinstance(data, list):
        raise AppError(
            status_code=500,
            error="agent_error",
            message="User repository must contain a list.",
        )

    users: list[dict[str, Any]] = []
    for index, user in enumerate(data):
        if not isinstance(user, dict):
            raise AppError(
                status_code=500,
                error="agent_error",
                message=f"User repository entry at index {index} must be an object.",
            )
        users.append(dict(user))

    return users


def _get_users() -> list[dict[str, Any]]:
    global _USER_REPOSITORY

    with _USER_REPOSITORY_LOCK:
        if _USER_REPOSITORY is None:
            _USER_REPOSITORY = _read_users_from_disk()
        return _USER_REPOSITORY


def _serialize_json(payload: Any) -> str:
    return json.dumps(payload, ensure_ascii=True)


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _validate_user_payload(user: Any) -> dict[str, Any]:
    if not isinstance(user, dict):
        raise AppError(
            status_code=400,
            error="invalid_request",
            message="User must be provided as a JSON object.",
        )

    normalized_user = dict(user)
    email = str(normalized_user.get("email", "")).strip()
    if not email:
        raise AppError(
            status_code=400,
            error="invalid_request",
            message="User email is required.",
        )

    normalized_user["email"] = email
    return normalized_user


def _find_user_index_by_email(email: str, users: list[dict[str, Any]]) -> int:
    normalized_email = _normalize_email(email)
    for index, user in enumerate(users):
        if _normalize_email(str(user.get("email", ""))) == normalized_email:
            return index

    raise AppError(
        status_code=404,
        error="invalid_request",
        message=f"User not found for email: {email}",
    )


@tool
def list_all_users() -> str:
    """List all users currently loaded in the in-memory repository as JSON."""
    with _USER_REPOSITORY_LOCK:
        return _serialize_json(_get_users())


@tool
def search_users_by_first_name(first_name: str) -> str:
    """Search local users by first name and return matching records as JSON."""
    with _USER_REPOSITORY_LOCK:
        users = _get_users()
        normalized_first_name = first_name.strip().lower()
        matches = [
            user
            for user in users
            if str(user.get("first_name", "")).strip().lower() == normalized_first_name
        ]
        return _serialize_json(matches)


@tool
def create_user(user: dict[str, Any]) -> str:
    """Create a new user in the in-memory repository and return the created record as JSON."""
    with _USER_REPOSITORY_LOCK:
        users = _get_users()
        new_user = _validate_user_payload(user)

        normalized_email = _normalize_email(new_user["email"])
        if any(
            _normalize_email(str(existing_user.get("email", ""))) == normalized_email
            for existing_user in users
        ):
            raise AppError(
                status_code=400,
                error="invalid_request",
                message=f"User already exists for email: {new_user['email']}",
            )

        users.append(new_user)
        return _serialize_json(new_user)


@tool
def delete_user_by_email(email: str) -> str:
    """Delete a user from the in-memory repository by email and return the deleted record as JSON."""
    with _USER_REPOSITORY_LOCK:
        users = _get_users()
        user_index = _find_user_index_by_email(email, users)
        deleted_user = users.pop(user_index)
        return _serialize_json(deleted_user)


@tool
def update_user_by_email(email: str, user: dict[str, Any]) -> str:
    """Update a user in the in-memory repository by email and return the updated record as JSON."""
    with _USER_REPOSITORY_LOCK:
        users = _get_users()
        user_index = _find_user_index_by_email(email, users)
        updated_user = _validate_user_payload(user)
        normalized_updated_email = _normalize_email(updated_user["email"])

        for index, existing_user in enumerate(users):
            if index == user_index:
                continue
            if _normalize_email(str(existing_user.get("email", ""))) == normalized_updated_email:
                raise AppError(
                    status_code=400,
                    error="invalid_request",
                    message=f"User already exists for email: {updated_user['email']}",
                )

        users[user_index] = updated_user
        return _serialize_json(updated_user)


@tool
def shell(command: str) -> str:
    """
    Run shell commands only. This tool should only be invoked to execute shell commands and not for any other purpose such as retrieving weather details or unrelated queries.
    """
    command_text = command.strip()
    if not command_text:
        raise ValueError("Command must not be empty.")

    completed = subprocess.run(
        ["bash", "-lc", command_text],
        cwd=str(MODULE_DIR),
        capture_output=True,
        text=True,
        check=False,
    )
    return (
        f"exit_code: {completed.returncode}\n"
        f"stdout:\n{completed.stdout}\n"
        f"stderr:\n{completed.stderr}"
    )


TOOLS = [
    list_all_users,
    search_users_by_first_name,
    create_user,
    delete_user_by_email,
    update_user_by_email,
    shell,
]
