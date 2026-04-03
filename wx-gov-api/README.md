# watsonx Governance Guardrails API

This project exposes a FastAPI service in `ai_guardrails_api.py` that:

- runs realtime detection metrics against base64-decoded input text
- blocks when any metric score is greater than `0.5`

The API exposes two endpoints:

- `POST /evaluate`: Evaluates text for guardrails. Returns original text if allowed (does NOT mask PII).
- `POST /mask`: Masks PII in the input text.

The `/evaluate` response shape is:

```json
{
  "is_blocked": true,
  "filters": "pii,hap",
  "text": "original text"
}
```

## Required environment variables

Copy `.env.example` to `.env` and fill in the IBM values:

```bash
cp .env.example .env
```

These variables are used by the API:

- `IBM_CLOUD_APIKEY`: IBM Cloud API key.
- `IBM_CLOUD_REGION` or `WATSONX_REGION`: IBM Cloud region. Defaults to `us-south` when omitted.
- `WXG_SERVICE_INSTANCE_ID`: optional if service instance auto-discovery is sufficient.
- `INVENTORY_ID`: required for custom guardrail enforcement.
- `CUSTOM_GUARDRAIL_POLICY_ID`: required custom guardrail policy id used for PII masking.
- `SERVICE_INSTANCE_ID`: optional alternate service instance id; can reuse `WXG_SERVICE_INSTANCE_ID`.
- `GUARDRAIL_SYSTEM_PROMPT`: optional, only needed for prompt-based detectors.
- `GUARDRAIL_BASE_URL`: optional override for the guardrails base URL.
- `VERIFY_SSL`: optional SSL verification toggle. Leave as `true` unless you intentionally need otherwise.
- `LOG_LEVEL`: optional log level for JSON logs. Defaults to `INFO`.
- `LOG_SERVICE_NAME` or `OTEL_SERVICE_NAME`: optional override for the `service` field in structured logs.
- `HOST_IP`: optional override for the `host_ip` field in structured logs when automatic resolution is not suitable.
- `PORT`: optional API server port. Defaults to `8000`.

## Run without Docker

Install dependencies:

```bash
uv sync
```

Start the API:

```bash
export PORT=8000
uv run uvicorn ai_guardrails_api:app --host 0.0.0.0 --port "${PORT}"
```

The API emits structured JSON logs to stdout. Application logs and Uvicorn lifecycle/access logs share the same JSON envelope so they can be shipped directly to Loki. Each log includes at least:

- `level`
- `request_id`
- `event`
- `timestamp`
- `message`

Request IDs are accepted from `X-Request-ID` when provided, or generated automatically and returned in the response headers.

For Loki-friendly aggregation, every log record also includes standard runtime metadata:

- `level` and `severity`: normalized log level
- `service`: service name, defaulting to `wx-gov-api`
- `logger`: Python logger name
- `host_name`: container or node hostname
- `host_ip`: resolved host IPv4 address when available
- `module`: Python module emitting the log
- `function`: Python function/method emitting the log
- `line`: source line number
- `process_id`: OS process id
- `thread_name`: Python thread name

For request-scoped application logs, the standard fields are:

- `timestamp`: UTC RFC3339 timestamp with millisecond precision
- `request_id`: incoming `X-Request-ID` value or a generated UUID
- `event`: stable machine-readable event name such as `http.request.completed`
- `message`: human-readable summary
- `method`: HTTP method when a request context exists
- `path`: request path when a request context exists
- `client_ip`: originating client IP when available

Completion and error events also include:

- `status_code`: HTTP status returned or surfaced by the handler
- `duration_ms`: total request processing time in milliseconds for request lifecycle logs

Uvicorn access logs also include:

- `client_ip`: client address reported by Uvicorn
- `method`: HTTP method
- `path`: request path as logged by Uvicorn
- `http_version`: negotiated HTTP version
- `status_code`: response status code

## Run with Docker

Build the image from the `watsonx_governance` directory:

```bash
docker build -t watsonx-governance-api .
```

Run the container with your environment file:

```bash
docker run --rm \
  --env-file .env \
  -e PORT=8000 \
  -p 8000:8000 \
  panchalravi/watsonx-governance-api:latest
```

To run on a different port, keep the container port and `PORT` value aligned:

```bash
docker run --rm \
  --env-file .env \
  -e PORT=9000 \
  -p 9000:9000 \
  watsonx-governance-api
```

## Multi-arch image build

The project Dockerfile uses the multi-arch `python:3.12-slim` base image, so you can build for multiple targets with Docker Buildx:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t panchalravi/watsonx-governance-api:latest \
  --push \
  .
```

## API usage

### Evaluate Text

Send the base64-encoded UTF-8 text as a raw JSON string body to `POST /evaluate`:

```bash
TEXT_B64=$(printf 'My email is abc@gmail.com' | base64)

curl -v -X POST http://localhost:8000/evaluate \
  -H "Content-Type: application/json" \
  -d "\"${TEXT_B64}\""
```

Example response:

```json
{
  "is_blocked": true,
  "filters": "pii",
  "text": "My email is abc@gmail.com"
}
```

### Mask PII

Send the base64-encoded UTF-8 text as a raw JSON string body to `POST /mask`:

```bash
TEXT_B64=$(printf 'My email is abc@gmail.com' | base64)

curl -v -X POST http://localhost:8000/mask \
  -H "Content-Type: application/json" \
  -d "\"${TEXT_B64}\""
```

Example response (returns a plain text string; if no PII is detected, the original text is returned unchanged):

```text
"My email is <EMAIL_ADDRESS>"
```

In other words, the request body is:

```json
"TXkgZW1haWwgaXMgYWJjQGdtYWlsLmNvbQ=="
```

not:

```json
{
  "text": "TXkgZW1haWwgaXMgYWJjQGdtYWlsLmNvbQ=="
}
```

## References

- [watsonx.governance v2 API](https://cloud.ibm.com/apidocs/ai-openscale#textdetection)
- [watsonx.governance samples](https://github.com/IBM/ibm-watsonx-gov/tree/samples/notebooks)
- [Configuring AI Guardrails](https://dataplatform.cloud.ibm.com/docs/content/wsj/analyze-data/guardrails-inventories.html?context=wx&audience=wdp)
