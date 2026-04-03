import base64
import json
import logging
import os
import time
import uuid

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("OPENAI_API_KEY", "test-key")
os.environ.setdefault("LANGCHAIN_MODEL", "openai:gpt-5-mini")

import agent_api
import identity
import agent_runtime
from agent_runtime import AgentRuntime
from identity import OboTokenService


class FakeChunk:
    def __init__(self, content: str):
        self.content = content


class FakeAssistantResponse:
    def __init__(self, tool_calls=None, content=""):
        self.tool_calls = tool_calls or []
        self.content = content


class FakeToolBoundLLM:
    def __init__(self, response=None):
        self.response = response or FakeAssistantResponse()

    def invoke(self, messages):
        return self.response


class FakeStreamingLLM:
    def __init__(self, chunks=None):
        self.chunks = chunks or [FakeChunk("streamed output")]
        self.last_messages = None

    def stream(self, messages):
        self.last_messages = list(messages)
        return iter(self.chunks)


class FakeTool:
    def __init__(self, output: str):
        self.output = output

    def invoke(self, args):
        return self.output


class FakeBoundLLM(FakeStreamingLLM):
    def bind_tools(self, tools):
        return FakeToolBoundLLM()


def _jwt_with_expiry(offset_seconds: int) -> str:
    header = base64.urlsafe_b64encode(
        json.dumps({"alg": "none", "typ": "JWT"}, separators=(",", ":")).encode(
            "utf-8"
        )
    ).rstrip(b"=")
    payload = base64.urlsafe_b64encode(
        json.dumps(
            {"sub": "user-123", "exp": int(time.time()) + offset_seconds},
            separators=(",", ":"),
        ).encode("utf-8")
    ).rstrip(b"=")
    signature = b"signature"
    return b".".join([header, payload, signature]).decode("utf-8")


def _structured_log_records(caplog, logger_name: str):
    structured_logs = []
    for record in caplog.records:
        if record.name != logger_name:
            continue
        try:
            structured_logs.append(json.loads(record.getMessage()))
        except json.JSONDecodeError:
            continue
    return structured_logs


@pytest.fixture(autouse=True)
def isolate_runtime(tmp_path, monkeypatch):
    actor_token_path = tmp_path / "actor-token"
    actor_token_path.write_text("actor-token", encoding="utf-8")

    monkeypatch.setattr(agent_api.SETTINGS, "actor_token_path", actor_token_path)
    monkeypatch.setattr(agent_api.SETTINGS, "token_exchange_url", "http://token-exchange.local/obo")
    monkeypatch.setattr(agent_api.SETTINGS, "obo_role_name", "test-role")
    monkeypatch.setattr(agent_api.SETTINGS, "bypass_auth_token_exchange", False)

    agent_api.app.state.settings = agent_api.SETTINGS
    agent_api.app.state.agent_runtime = AgentRuntime(
        llm=FakeStreamingLLM(),
        llm_with_tools=FakeToolBoundLLM(),
        logger=agent_api.LOGGER,
    )
    agent_api.app.state.token_service = OboTokenService(
        settings=agent_api.SETTINGS,
        logger=agent_api.LOGGER,
    )
    agent_api.app.state.token_service.clear_cache()


def test_missing_bearer_token_is_rejected():
    client = TestClient(agent_api.app)

    response = client.post(
        "/v1/agent/query",
        json={"messages": [{"role": "user", "content": "hello"}]},
    )

    assert response.status_code == 401
    assert response.json() == {
        "error": "invalid_request",
        "message": "Authorization bearer token is required.",
    }


def test_expired_bearer_token_is_rejected(monkeypatch):
    client = TestClient(agent_api.app)
    expired_token = _jwt_with_expiry(-30)

    def fail_exchange(*args, **kwargs):
        raise AssertionError("Token exchange should not run for expired access tokens.")

    monkeypatch.setattr(agent_api.app.state.token_service, "perform_token_exchange", fail_exchange)

    response = client.post(
        "/v1/agent/query",
        headers={"Authorization": f"Bearer {expired_token}"},
        json={"messages": [{"role": "user", "content": "hello"}]},
    )

    assert response.status_code == 401
    assert response.json() == {
        "error": "invalid_token",
        "message": "Bearer token has expired.",
    }


def test_bypass_mode_allows_request_without_authorization(monkeypatch):
    client = TestClient(agent_api.app)
    monkeypatch.setattr(agent_api.app.state.settings, "bypass_auth_token_exchange", True)

    def fail_exchange(*args, **kwargs):
        raise AssertionError("Token exchange should not run when bypass mode is enabled.")

    monkeypatch.setattr(agent_api.app.state.token_service, "resolve_token", fail_exchange)

    response = client.post(
        "/v1/agent/query",
        json={"messages": [{"role": "user", "content": "hello"}]},
    )

    assert response.status_code == 200
    assert response.text == "streamed output"


def test_bypass_mode_ignores_invalid_authorization_header(monkeypatch):
    client = TestClient(agent_api.app)
    monkeypatch.setattr(agent_api.app.state.settings, "bypass_auth_token_exchange", True)

    def fail_exchange(*args, **kwargs):
        raise AssertionError("Token exchange should not run when bypass mode is enabled.")

    monkeypatch.setattr(agent_api.app.state.token_service, "resolve_token", fail_exchange)

    response = client.post(
        "/v1/agent/query",
        headers={"Authorization": "Basic not-a-bearer-token"},
        json={"messages": [{"role": "user", "content": "hello"}]},
    )

    assert response.status_code == 200
    assert response.text == "streamed output"


def test_old_chat_route_is_removed():
    client = TestClient(agent_api.app)

    response = client.post("/chat", json={"messages": []})

    assert response.status_code == 404


def test_request_id_header_is_preserved_and_propagated(monkeypatch):
    client = TestClient(agent_api.app)
    access_token = _jwt_with_expiry(300)
    obo_token = _jwt_with_expiry(600)
    request_id = "request-from-header"
    exchange_calls = []

    def fake_exchange(subject_token, actor_token, request_id):
        exchange_calls.append(request_id)
        return obo_token, time.time() + 600

    monkeypatch.setattr(agent_api.app.state.token_service, "perform_token_exchange", fake_exchange)

    response = client.post(
        "/v1/agent/query",
        headers={
            "Authorization": f"Bearer {access_token}",
            "X-Request-ID": request_id,
        },
        json={"messages": [{"role": "user", "content": "hello"}]},
    )

    assert response.status_code == 200
    assert response.headers["X-Request-ID"] == request_id
    assert exchange_calls == [request_id]


def test_request_id_is_generated_when_header_is_missing(monkeypatch):
    client = TestClient(agent_api.app)
    access_token = _jwt_with_expiry(300)

    monkeypatch.setattr(
        agent_api.app.state.token_service,
        "perform_token_exchange",
        lambda subject_token, actor_token, request_id: (_jwt_with_expiry(600), time.time() + 600),
    )

    response = client.post(
        "/v1/agent/query",
        headers={"Authorization": f"Bearer {access_token}"},
        json={"messages": [{"role": "user", "content": "hello"}]},
    )

    assert response.status_code == 200
    assert response.headers["X-Request-ID"]
    assert str(uuid.UUID(response.headers["X-Request-ID"])) == response.headers["X-Request-ID"]


def test_obo_token_is_cached_between_requests(monkeypatch):
    client = TestClient(agent_api.app)
    access_token = _jwt_with_expiry(300)
    obo_token = _jwt_with_expiry(600)
    exchange_calls = []

    def fake_exchange(subject_token, actor_token, request_id):
        exchange_calls.append(
            {
                "subject_token": subject_token,
                "actor_token": actor_token,
                "request_id": request_id,
            }
        )
        return obo_token, time.time() + 600

    monkeypatch.setattr(agent_api.app.state.token_service, "perform_token_exchange", fake_exchange)

    first_response = client.post(
        "/v1/agent/query",
        headers={"Authorization": f"Bearer {access_token}"},
        json={"messages": [{"role": "user", "content": "hello"}]},
    )
    second_response = client.post(
        "/v1/agent/query",
        headers={"Authorization": f"Bearer {access_token}"},
        json={"messages": [{"role": "user", "content": "hello again"}]},
    )

    assert first_response.status_code == 200
    assert second_response.status_code == 200
    assert first_response.text == "streamed output"
    assert second_response.text == "streamed output"
    assert len(exchange_calls) == 1


def test_cached_tokens_can_be_retrieved_via_endpoint(monkeypatch):
    client = TestClient(agent_api.app)
    access_token = _jwt_with_expiry(300)
    obo_token = _jwt_with_expiry(600)
    exchange_calls = []

    def fake_exchange(subject_token, actor_token, request_id):
        exchange_calls.append(
            {
                "subject_token": subject_token,
                "actor_token": actor_token,
                "request_id": request_id,
            }
        )
        return obo_token, time.time() + 600

    monkeypatch.setattr(agent_api.app.state.token_service, "perform_token_exchange", fake_exchange)

    query_response = client.post(
        "/v1/agent/query",
        headers={"Authorization": f"Bearer {access_token}"},
        json={"messages": [{"role": "user", "content": "hello"}]},
    )
    token_response = client.get(
        "/v1/agent/tokens",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert query_response.status_code == 200
    assert token_response.status_code == 200
    assert token_response.json() == {
        "obo_token": obo_token,
        "actor_token": "actor-token",
    }
    assert len(exchange_calls) == 1


def test_tokens_endpoint_returns_404_on_cache_miss(monkeypatch):
    client = TestClient(agent_api.app)
    access_token = _jwt_with_expiry(300)

    def fail_exchange(*args, **kwargs):
        raise AssertionError("Token exchange should not run for cache lookup endpoint.")

    monkeypatch.setattr(agent_api.app.state.token_service, "perform_token_exchange", fail_exchange)

    response = client.get(
        "/v1/agent/tokens",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 404
    assert response.json() == {
        "error": "token_not_found",
        "message": "No cached OBO token found for the provided bearer token.",
    }


def test_token_exchange_posts_subject_and_actor_tokens(monkeypatch, caplog):
    access_token = _jwt_with_expiry(300)
    captured = {}

    class FakeHTTPResponse:
        def __init__(self, body: str):
            self.body = body.encode("utf-8")

        def read(self):
            return self.body

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_urlopen(request, timeout):
        captured["url"] = request.full_url
        captured["payload"] = json.loads(request.data.decode("utf-8"))
        captured["headers"] = {key.lower(): value for key, value in request.header_items()}
        captured["timeout"] = timeout
        return FakeHTTPResponse(
            json.dumps({"access_token": _jwt_with_expiry(300), "expires_in": 300})
        )

    monkeypatch.setattr(identity.urllib.request, "urlopen", fake_urlopen)

    with caplog.at_level(logging.INFO, logger="agent_api"):
        obo_token, expiry_time = identity.perform_token_exchange(
            subject_token=access_token,
            actor_token="actor-token",
            settings=agent_api.SETTINGS,
            logger=agent_api.LOGGER,
            request_id="request-1",
        )

    assert obo_token
    assert expiry_time > time.time()
    assert captured == {
        "url": agent_api.SETTINGS.token_exchange_url,
        "payload": {
            "subject_token": access_token,
            "actor_token": "actor-token",
        },
        "headers": {
            "accept": "application/json",
            "content-type": "application/json",
            "x-request-id": "request-1",
        },
        "timeout": agent_api.SETTINGS.token_exchange_timeout_seconds,
    }
    completion_logs = [
        payload
        for payload in _structured_log_records(caplog, "agent_api")
        if payload.get("event") == "obo_token_exchange_completed"
    ]
    assert completion_logs
    assert completion_logs[-1]["obo_token_present"] is True
    assert "obo_token" not in completion_logs[-1]


def test_read_request_does_not_trigger_fallback_shell(monkeypatch):
    client = TestClient(agent_api.app)
    access_token = _jwt_with_expiry(300)
    streaming_llm = FakeStreamingLLM()
    agent_api.app.state.agent_runtime = AgentRuntime(
        llm=streaming_llm,
        llm_with_tools=FakeToolBoundLLM(),
        logger=agent_api.LOGGER,
    )

    monkeypatch.setattr(
        agent_api.app.state.token_service,
        "perform_token_exchange",
        lambda subject_token, actor_token, request_id: (_jwt_with_expiry(600), time.time() + 600),
    )

    response = client.post(
        "/v1/agent/query",
        headers={"Authorization": f"Bearer {access_token}"},
        json={"messages": [{"role": "user", "content": "read /tmp/example.txt"}]},
    )

    assert response.status_code == 200
    assert response.text == "streamed output"
    assert streaming_llm.last_messages is not None
    assert len(streaming_llm.last_messages) == 2


def test_streaming_response_is_logged_with_agent_text(monkeypatch, caplog):
    client = TestClient(agent_api.app)
    access_token = _jwt_with_expiry(300)

    monkeypatch.setattr(
        agent_api.app.state.token_service,
        "perform_token_exchange",
        lambda subject_token, actor_token, request_id: (_jwt_with_expiry(600), time.time() + 600),
    )

    with caplog.at_level(logging.INFO, logger="agent_api"):
        response = client.post(
            "/v1/agent/query",
            headers={"Authorization": f"Bearer {access_token}"},
            json={"messages": [{"role": "user", "content": "hello"}]},
        )

    assert response.status_code == 200
    assert response.text == "streamed output"

    response_logs = [
        payload
        for payload in _structured_log_records(caplog, "agent_api")
        if payload.get("event") == "response_sent"
    ]
    assert response_logs
    assert response_logs[-1]["response_text"] == "streamed output"
    assert response_logs[-1]["level"] == "INFO"
    assert response_logs[-1]["logger"] == "agent_api"
    assert response_logs[-1]["hostname"]
    assert "host_ip" in response_logs[-1]
    assert response_logs[-1]["module"] == "agent_runtime"
    assert response_logs[-1]["function"] == "_stream_text_chunks"
    assert response_logs[-1]["method_name"] == "_stream_text_chunks"
    assert isinstance(response_logs[-1]["line_number"], int)
    assert response_logs[-1]["http_method"] == "POST"
    assert response_logs[-1]["client_ip"] == "testclient"


def test_shell_tool_result_is_logged(monkeypatch, caplog):
    client = TestClient(agent_api.app)
    access_token = _jwt_with_expiry(300)
    agent_api.app.state.agent_runtime = AgentRuntime(
        llm=FakeStreamingLLM(),
        llm_with_tools=FakeToolBoundLLM(
            FakeAssistantResponse(
                tool_calls=[
                    {
                        "id": "call_shell_1",
                        "name": "shell",
                        "args": {"command": "ls -l agent_runtime.py"},
                    }
                ]
            )
        ),
        logger=agent_api.LOGGER,
    )

    monkeypatch.setattr(
        agent_api.app.state.token_service,
        "perform_token_exchange",
        lambda subject_token, actor_token, request_id: (_jwt_with_expiry(600), time.time() + 600),
    )
    monkeypatch.setattr(
        agent_runtime,
        "shell",
        FakeTool("exit_code: 0\nstdout:\n-rw-r--r-- agent_runtime.py\nstderr:\n"),
    )

    with caplog.at_level(logging.INFO, logger="agent_api"):
        response = client.post(
            "/v1/agent/query",
            headers={"Authorization": f"Bearer {access_token}"},
            json={"messages": [{"role": "user", "content": "show me the file details"}]},
        )

    assert response.status_code == 200

    tool_result_logs = [
        payload
        for payload in _structured_log_records(caplog, "agent_api")
        if payload.get("stage") == "tool_result"
    ]
    assert tool_result_logs
    assert tool_result_logs[-1]["tool_name"] == "shell"
    assert tool_result_logs[-1]["exit_code"] == 0
    assert tool_result_logs[-1]["stdout_length"] > 0
    assert tool_result_logs[-1]["stderr_length"] == 0
    assert tool_result_logs[-1]["request_id"]
    assert tool_result_logs[-1]["http_method"] == "POST"
    assert tool_result_logs[-1]["client_ip"] == "testclient"


def test_create_app_builds_runtime_from_configured_model(monkeypatch):
    captured = {}

    def fake_init_chat_model(model, **kwargs):
        captured["model"] = model
        captured["kwargs"] = kwargs
        return FakeBoundLLM()

    monkeypatch.setattr(agent_api, "init_chat_model", fake_init_chat_model)

    app = agent_api.create_app(
        settings=agent_api.Settings(
            model="openai:gpt-5.4-mini",
            actor_token_path=agent_api.SETTINGS.actor_token_path,
            token_exchange_url=agent_api.SETTINGS.token_exchange_url,
            token_exchange_timeout_seconds=agent_api.SETTINGS.token_exchange_timeout_seconds,
            obo_role_name=agent_api.SETTINGS.obo_role_name,
            bypass_auth_token_exchange=agent_api.SETTINGS.bypass_auth_token_exchange,
            host=agent_api.SETTINGS.host,
            port=agent_api.SETTINGS.port,
            log_level=agent_api.SETTINGS.log_level,
        )
    )

    assert captured == {
        "model": "openai:gpt-5.4-mini",
        "kwargs": {"streaming": True},
    }
    assert isinstance(app.state.agent_runtime, AgentRuntime)
