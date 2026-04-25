from __future__ import annotations

from config import Settings
from storage.base import UserRepository
from storage.file_repo import FileUserRepository
from storage.postgres_repo import PostgresUserRepository


def build_repository(settings: Settings) -> UserRepository:
    if settings.user_backend == "postgres":
        return PostgresUserRepository(
            dsn=settings.pg_dsn,
            auto_migrate=settings.pg_auto_migrate,
        )
    return FileUserRepository(file_path=settings.users_file)
