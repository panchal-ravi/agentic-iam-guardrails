from __future__ import annotations

import logging
from typing import Any

import asyncpg

from errors import AppError
from logging_utils import log_event
from models import UserRecord
from storage.base import UserRepository

LOGGER = logging.getLogger("user_mcp.storage.postgres")

_COLUMNS = (
    "email",
    "first_name",
    "last_name",
    "ssn",
    "phone",
    "credit_card_number",
    "ip_address",
)
_SELECT = ", ".join(_COLUMNS)

_DDL = (
    """
    CREATE TABLE IF NOT EXISTS users (
        email              TEXT PRIMARY KEY,
        first_name         TEXT,
        last_name          TEXT,
        ssn                TEXT,
        phone              TEXT,
        credit_card_number TEXT,
        ip_address         TEXT,
        created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
        updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    """,
    "CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_uidx ON users (lower(email));",
    "CREATE INDEX IF NOT EXISTS users_first_name_lower_idx ON users (lower(first_name));",
)


class PostgresUserRepository(UserRepository):
    def __init__(self, dsn: str, auto_migrate: bool = True):
        if not dsn:
            raise AppError(
                500,
                "configuration_error",
                "USER_MCP_PG_DSN is required when USER_BACKEND=postgres.",
            )
        self._dsn = dsn
        self._auto_migrate = auto_migrate
        self._pool: asyncpg.Pool | None = None

    async def startup(self) -> None:
        log_event(
            LOGGER,
            "postgres_pool_init",
            message="Initializing Postgres connection pool",
        )
        self._pool = await asyncpg.create_pool(
            dsn=self._dsn,
            min_size=1,
            max_size=10,
        )
        if self._auto_migrate:
            async with self._pool.acquire() as conn:
                async with conn.transaction():
                    for statement in _DDL:
                        await conn.execute(statement)

    async def shutdown(self) -> None:
        if self._pool is not None:
            log_event(
                LOGGER,
                "postgres_pool_close",
                message="Closing Postgres connection pool",
            )
            await self._pool.close()
            self._pool = None

    def _require_pool(self) -> asyncpg.Pool:
        if self._pool is None:
            raise AppError(500, "agent_error", "Postgres pool not initialized.")
        return self._pool

    async def list_all(self) -> list[UserRecord]:
        pool = self._require_pool()
        rows = await pool.fetch(f"SELECT {_SELECT} FROM users ORDER BY email")
        return [UserRecord.model_validate(_row_to_dict(r)) for r in rows]

    async def search_by_first_name(self, first_name: str) -> list[UserRecord]:
        pool = self._require_pool()
        rows = await pool.fetch(
            f"SELECT {_SELECT} FROM users WHERE lower(first_name) = lower($1) ORDER BY email",
            first_name.strip(),
        )
        return [UserRecord.model_validate(_row_to_dict(r)) for r in rows]

    async def create(self, user: UserRecord) -> UserRecord:
        pool = self._require_pool()
        params = _user_to_params(user)
        try:
            row = await pool.fetchrow(
                f"""
                INSERT INTO users ({_SELECT})
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                RETURNING {_SELECT}
                """,
                *params,
            )
        except asyncpg.UniqueViolationError as exc:
            raise AppError(
                400,
                "invalid_request",
                f"User already exists for email: {user.email}",
            ) from exc
        return UserRecord.model_validate(_row_to_dict(row))

    async def delete_by_email(self, email: str) -> UserRecord:
        pool = self._require_pool()
        row = await pool.fetchrow(
            f"DELETE FROM users WHERE lower(email) = lower($1) RETURNING {_SELECT}",
            email.strip(),
        )
        if row is None:
            raise AppError(404, "invalid_request", f"User not found for email: {email}")
        return UserRecord.model_validate(_row_to_dict(row))

    async def update_by_email(self, email: str, user: UserRecord) -> UserRecord:
        pool = self._require_pool()
        params = _user_to_params(user)
        try:
            row = await pool.fetchrow(
                f"""
                UPDATE users SET
                    email              = $2,
                    first_name         = $3,
                    last_name          = $4,
                    ssn                = $5,
                    phone              = $6,
                    credit_card_number = $7,
                    ip_address         = $8,
                    updated_at         = now()
                WHERE lower(email) = lower($1)
                RETURNING {_SELECT}
                """,
                email.strip(),
                *params,
            )
        except asyncpg.UniqueViolationError as exc:
            raise AppError(
                400,
                "invalid_request",
                f"User already exists for email: {user.email}",
            ) from exc
        if row is None:
            raise AppError(404, "invalid_request", f"User not found for email: {email}")
        return UserRecord.model_validate(_row_to_dict(row))


def _user_to_params(user: UserRecord) -> tuple[Any, ...]:
    return (
        user.email,
        user.first_name,
        user.last_name,
        user.ssn,
        user.phone,
        user.credit_card_number,
        user.ip_address,
    )


def _row_to_dict(row: asyncpg.Record) -> dict[str, Any]:
    return {col: row[col] for col in _COLUMNS}
