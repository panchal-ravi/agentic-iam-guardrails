from __future__ import annotations

import base64
import binascii
import json
import time
from typing import Any

from fastapi import Request

from errors import AppError


def extract_bearer_token(request: Request) -> str:
    authorization_header = request.headers.get("Authorization")
    if authorization_header is None:
        raise AppError(
            status_code=401,
            error="invalid_request",
            message="Authorization bearer token is required.",
        )

    scheme, _, token = authorization_header.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise AppError(
            status_code=401,
            error="invalid_request",
            message="Authorization header must use the Bearer scheme.",
        )

    return token.strip()


def decode_jwt_payload(token: str, token_label: str) -> dict[str, Any]:
    segments = token.split(".")
    if len(segments) != 3:
        raise AppError(
            status_code=401,
            error="invalid_token",
            message=f"{token_label} is not a valid JWT.",
        )

    payload_segment = segments[1]
    padding = "=" * (-len(payload_segment) % 4)
    try:
        decoded_payload = base64.urlsafe_b64decode(payload_segment + padding)
        payload = json.loads(decoded_payload.decode("utf-8"))
    except (ValueError, UnicodeDecodeError, binascii.Error) as exc:
        raise AppError(
            status_code=401,
            error="invalid_token",
            message=f"{token_label} is not a valid JWT.",
        ) from exc

    if not isinstance(payload, dict):
        raise AppError(
            status_code=401,
            error="invalid_token",
            message=f"{token_label} is not a valid JWT.",
        )

    return payload


def validate_access_token(access_token: str) -> dict[str, Any]:
    payload = decode_jwt_payload(access_token, "Bearer token")
    now = time.time()

    exp = payload.get("exp")
    if not isinstance(exp, (int, float)):
        raise AppError(
            status_code=401,
            error="invalid_token",
            message="Bearer token is missing exp claim.",
        )
    if float(exp) <= now:
        raise AppError(
            status_code=401,
            error="invalid_token",
            message="Bearer token has expired.",
        )

    nbf = payload.get("nbf")
    if isinstance(nbf, (int, float)) and float(nbf) > now:
        raise AppError(
            status_code=401,
            error="invalid_token",
            message="Bearer token is not yet valid.",
        )

    return payload
