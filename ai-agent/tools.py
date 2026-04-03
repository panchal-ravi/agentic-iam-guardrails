from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

from langchain_core.tools import tool

from errors import AppError

MODULE_DIR = Path(__file__).resolve().parent
USER_REPOSITORY_PATH = MODULE_DIR / "users_repository.json"


def _load_users() -> list[dict[str, Any]]:
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

    return data


@tool
def search_users_by_first_name(first_name: str) -> str:
    """Search local users by first name and return matching records as JSON."""
    users = _load_users()
    normalized_first_name = first_name.strip().lower()
    matches = [
        user
        for user in users
        if isinstance(user, dict)
        and str(user.get("first_name", "")).strip().lower() == normalized_first_name
    ]
    return json.dumps(matches, ensure_ascii=True)


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


TOOLS = [search_users_by_first_name, shell]
