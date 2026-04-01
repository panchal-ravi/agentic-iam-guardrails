"""Remote AI agent HTTP client."""

from collections.abc import Iterator

import requests

from config import AI_AGENT_API_URL
from observability import build_outbound_headers, get_logger

_LOGGER = get_logger("services.agent_api")
_AGENT_BASE_URL = AI_AGENT_API_URL
_AGENT_URL = f"{_AGENT_BASE_URL}/v1/agent/query"


def _build_headers(access_token: str) -> dict[str, str]:
    """Build outbound headers for the agent request."""
    return build_outbound_headers(
        {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }
    )


def _build_payload(message: str, history: list, stream: bool) -> dict:
    """Build the agent request payload."""
    return {
        "messages": [*history, {"role": "user", "content": message}],
        "stream": stream,
    }


def _extract_agent_response(response: requests.Response) -> dict:
    """Normalize JSON and plain-text agent responses into the UI contract."""
    try:
        data = response.json()
    except requests.JSONDecodeError:
        response_text = response.text.strip()
        if not response_text:
            raise RuntimeError("Agent API returned an empty response.")

        _LOGGER.warning(
            "Agent API returned non-JSON content-type=%s",
            response.headers.get("Content-Type", "<missing>"),
        )
        return {"response": response_text, "obo_token": ""}

    if isinstance(data, dict):
        response_text = (
            data.get("response")
            or data.get("response_text")
            or data.get("result")
            or data.get("message")
            or ""
        )
        if not response_text:
            response_text = str(data)
        return {"response": response_text, "obo_token": data.get("obo_token", "")}

    return {"response": str(data), "obo_token": ""}


def _extract_error_body(response: requests.Response) -> str:
    """Extract a readable error message from JSON or plain-text responses."""
    content_type = response.headers.get("Content-Type", "")

    if "application/json" in content_type.lower():
        try:
            data = response.json()
        except requests.JSONDecodeError:
            data = None

        if isinstance(data, dict):
            for key in ("error_description", "detail", "message", "error", "response"):
                value = data.get(key)
                if value:
                    return str(value).strip()

            return str(data).strip()

        if data is not None:
            return str(data).strip()

    return response.text.strip()


def _raise_agent_http_error(response: requests.Response, log_message: str) -> None:
    """Raise a RuntimeError that includes the response body when available."""
    error_body = _extract_error_body(response)
    _LOGGER.error(log_message, response.status_code)

    if error_body:
        raise RuntimeError(f"Agent API error {response.status_code}: {error_body}")

    raise RuntimeError(f"Agent API error {response.status_code}")


def invoke_agent(message: str, history: list, access_token: str = "") -> dict:
    """
    Send a message to the remote AI agent and return the full response payload.

    Args:
        message:      The user's latest message.
        history:      Conversation history as list of {"role": ..., "content": ...} dicts.
        access_token: The user's IBM Verify access token (sent as Bearer token in Authorization header).

    Returns:
        A dict with keys:
          - "response"  (str): The agent's reply text.
          - "obo_token" (str): On-Behalf-Of JWT returned by the agent (may be empty string).

    Raises:
        RuntimeError: If the API call fails or is not configured.
    """
    if not _AGENT_BASE_URL:
        raise RuntimeError("AI_AGENT_API_URL is not configured.")

    headers = _build_headers(access_token)
    payload = _build_payload(message, history, stream=False)

    try:
        _LOGGER.info("Invoking agent API at %s", _AGENT_URL)
        response = requests.post(_AGENT_URL, json=payload, headers=headers, timeout=60)
        if not response.ok:
            _raise_agent_http_error(response, "Agent API returned HTTP %s")
        _LOGGER.info("Agent API completed with status %s", response.status_code)
        return _extract_agent_response(response)
    except requests.RequestException as exc:
        _LOGGER.error("Agent API request failed: %s", exc)
        raise RuntimeError(f"Agent API request failed: {exc}") from exc


def stream_agent_response(
    message: str, history: list, access_token: str = ""
) -> Iterator[str]:
    """Stream the agent response as plain-text chunks with JSON fallback support."""
    if not _AGENT_BASE_URL:
        raise RuntimeError("AI_AGENT_API_URL is not configured.")

    headers = _build_headers(access_token)
    payload = _build_payload(message, history, stream=True)

    try:
        _LOGGER.info("Invoking streaming agent API at %s", _AGENT_URL)
        with requests.post(
            _AGENT_URL,
            json=payload,
            headers=headers,
            timeout=(10, 300),
            stream=True,
        ) as response:
            if not response.ok:
                _raise_agent_http_error(response, "Streaming agent API returned HTTP %s")
            content_type = response.headers.get("Content-Type", "")

            if "application/json" in content_type.lower():
                yield _extract_agent_response(response)["response"]
                return

            for chunk in response.iter_content(chunk_size=None, decode_unicode=True):
                if chunk:
                    yield chunk
    except requests.RequestException as exc:
        _LOGGER.error("Streaming agent API request failed: %s", exc)
        raise RuntimeError(f"Agent API request failed: {exc}") from exc
