import base64
import binascii
import json
import logging
import os
import uuid

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, Response

from pydantic import BaseModel

from pii_masking import mask_pii_text
from realtime_detections import evaluate_text_metrics

load_dotenv()
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO").upper(),
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)
THRESHOLD = 0.5
logger = logging.getLogger(__name__)

app = FastAPI(title="Combined Guardrails API")


class GuardRailResponse(BaseModel):
    is_blocked: bool
    filters: str
    text: str


def decode_base64_text(encoded_text: str) -> str:
    try:
        decoded_bytes = base64.b64decode(encoded_text, validate=True)
        return decoded_bytes.decode("utf-8")
    except (binascii.Error, UnicodeDecodeError) as exc:
        raise ValueError(
            "The text field must contain valid base64-encoded UTF-8."
        ) from exc


def parse_encoded_text_payload(body: bytes) -> str:
    try:
        payload = body.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError("Request body must be valid UTF-8.") from exc

    if not payload.strip():
        raise ValueError("Request body must contain a base64-encoded UTF-8 string.")

    try:
        parsed_payload = json.loads(payload)
    except json.JSONDecodeError:
        return payload.strip()

    if not isinstance(parsed_payload, str):
        raise ValueError("Request body must contain a base64-encoded UTF-8 string.")

    return parsed_payload.strip()


def guardrail_response(text: str, request_id: str, client_ip: str) -> GuardRailResponse:
    metric_scores = evaluate_text_metrics(text)
    logger.info(
        "Evaluated metrics for request_id=%s client_ip=%s scores=%s",
        request_id,
        client_ip,
        metric_scores,
    )
    triggered_filters = [
        metric_name
        for metric_name, metric_value in metric_scores.items()
        if metric_value > THRESHOLD
    ]

    is_blocked = any(f != "pii" for f in triggered_filters)

    result = GuardRailResponse(
        is_blocked=is_blocked,
        filters=",".join(triggered_filters),
        text=text,
    )
    logger.info(
        "GuardRailResponse generated request_id=%s client_ip=%s payload=%s",
        request_id,
        client_ip,
        result.model_dump(),
    )
    return result


@app.post("/evaluate")
async def evaluate(
    response: Response,
    http_request: Request,
):
    request_id = http_request.headers.get("x-request-id", str(uuid.uuid4()))
    response.headers["x-request-id"] = request_id
    forwarded_for = http_request.headers.get("x-forwarded-for")
    client_ip = (
        forwarded_for.split(",")[0].strip()
        if forwarded_for
        else (http_request.client.host if http_request.client else "unknown")
    )
    logger.info("Received /evaluate request_id=%s client_ip=%s", request_id, client_ip)
    try:
        encoded_text = parse_encoded_text_payload(await http_request.body())
        decoded_text = decode_base64_text(encoded_text)
    except ValueError as exc:
        logger.warning(
            "Invalid base64 input request_id=%s client_ip=%s", request_id, client_ip
        )
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    try:
        result = guardrail_response(
            decoded_text, request_id=request_id, client_ip=client_ip
        )
        if result.is_blocked:
            response.status_code = 400
            logger.info(
                "Request blocked request_id=%s client_ip=%s filters=%s",
                request_id,
                client_ip,
                result.filters,
            )
            return os.getenv("BLOCKED_CONTENT_MESSAGE", "This content was blocked.")
        logger.info("Request allowed request_id=%s client_ip=%s", request_id, client_ip)
        return result.text
    except RuntimeError as exc:
        logger.exception(
            "Guardrail evaluation failed request_id=%s client_ip=%s",
            request_id,
            client_ip,
        )
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@app.post("/mask")
async def mask(
    http_request: Request,
):
    request_id = http_request.headers.get("x-request-id", str(uuid.uuid4()))
    forwarded_for = http_request.headers.get("x-forwarded-for")
    client_ip = (
        forwarded_for.split(",")[0].strip()
        if forwarded_for
        else (http_request.client.host if http_request.client else "unknown")
    )
    logger.info("Received /mask request_id=%s client_ip=%s", request_id, client_ip)

    try:
        encoded_text = parse_encoded_text_payload(await http_request.body())
        decoded_text = decode_base64_text(encoded_text)
        masked_text = mask_pii_text(decoded_text)
        return masked_text
    except ValueError as exc:
        logger.warning(
            "Invalid base64 input request_id=%s client_ip=%s", request_id, client_ip
        )
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        logger.exception(
            "PII masking failed request_id=%s client_ip=%s",
            request_id,
            client_ip,
        )
        raise HTTPException(status_code=502, detail=str(exc)) from exc
