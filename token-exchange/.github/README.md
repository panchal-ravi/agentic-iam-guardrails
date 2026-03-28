# Identity Broker

A Python-based identity broker that:
1. Exchanges a **HashiCorp Vault token** for a **Vault-signed OIDC Identity JWT**.
2. Performs an **IBM Verify on-behalf-of (OBO) token exchange** — takes a `subject_token` + `actor_token` (Vault Identity JWT) and returns an IBM Verify access token on behalf of the subject.

Exposes both flows as a FastAPI REST service with in-memory TTL caching.

## Architecture

```
Client Application
      │
      │ REST API
      ▼
Identity Broker API  (FastAPI + Uvicorn)
      │
      ├── POST /v1/identity/token ──────► VaultIdentityBroker ──► HashiCorp Vault
      │
      └── POST /v1/identity/obo-token ──► OBOBroker ──────────► IBM Verify
```

## Prerequisites

- Python 3.12+
- [uv](https://docs.astral.sh/uv/) package manager
- A running HashiCorp Vault instance with OIDC identity configured
- An IBM Verify tenant (for the OBO flow)
- Docker with [Buildx](https://docs.docker.com/buildx/working-with-buildx/) plugin (for multi-platform builds)

## Installation

```bash
# Install dependencies
uv sync

# Install with dev dependencies (for testing)
uv sync --group dev
```

## Configuration

All settings use the `IDENTITY_BROKER_` prefix and can be set as environment variables:

### Vault settings

| Variable | Default | Description |
|---|---|---|
| `IDENTITY_BROKER_VAULT_ADDR` | `https://127.0.0.1:8200` | Vault server address |
| `IDENTITY_BROKER_VAULT_TLS_VERIFY` | `true` | Enable TLS verification |
| `IDENTITY_BROKER_VAULT_CA_BUNDLE` | _(unset)_ | Path to a PEM CA bundle for a self-signed or private CA. When set, TLS verification uses this bundle instead of the default roots. |

### IBM Verify OBO settings

| Variable | Default | Description |
|---|---|---|
| `IDENTITY_BROKER_VERIFY_BASE_URL` | _(unset)_ | IBM Verify tenant base URL, e.g. `https://tenant.verify.ibm.com` |
| `IDENTITY_BROKER_OBO_CLIENT_ID` | _(unset)_ | Client ID for the OBO token exchange (public client) |

### Cache and service settings

| Variable | Default | Description |
|---|---|---|
| `IDENTITY_BROKER_CACHE_TTL` | `3600` | Cache TTL in seconds |
| `IDENTITY_BROKER_CACHE_MAXSIZE` | `1024` | Maximum cached tokens |
| `IDENTITY_BROKER_LOG_LEVEL` | `INFO` | Log level |

Uvicorn server settings:

| Variable | Default | Description |
|---|---|---|
| `UVICORN_HOST` | `0.0.0.0` | Interface to bind |
| `UVICORN_PORT` | `8080` | Port to listen on |

Example:

```bash
export IDENTITY_BROKER_VAULT_ADDR="https://vault.example.com:8200"
export IDENTITY_BROKER_VAULT_TLS_VERIFY="true"

# When Vault uses a self-signed or private CA certificate:
# export IDENTITY_BROKER_VAULT_CA_BUNDLE="/etc/ssl/certs/vault-ca.pem"

# IBM Verify OBO settings:
export IDENTITY_BROKER_VERIFY_BASE_URL="https://tenant.verify.ibm.com"
export IDENTITY_BROKER_OBO_CLIENT_ID="<redacted-obo-client-id>"

export UVICORN_HOST=0.0.0.0
export UVICORN_PORT=9090
```

## Running the Service

### Local (uv)

The server reads `UVICORN_HOST` and `UVICORN_PORT` from the environment (defaults: `0.0.0.0` and `8080`). Do **not** pass `--host`/`--port` flags — they override env vars.

```bash
# Use defaults (0.0.0.0:8080)
uv run uvicorn api.main:app

# Override host/port via env vars
export UVICORN_HOST=127.0.0.1
export UVICORN_PORT=9090
uv run uvicorn api.main:app
```

### Docker

The image sets `UVICORN_HOST=0.0.0.0` and `UVICORN_PORT=8080` as defaults. Override them with `-e` at runtime.

The Docker build installs only third-party dependencies into `/app/.venv` in the builder stage via `uv sync --no-install-project`, then copies that dependency-only virtualenv into the runtime image alongside the source tree. That keeps the runtime image offline-friendly and avoids reinstalling dependencies in the final stage.

#### Single-platform build (local development)

```bash
# Build for the current host platform
docker build -t identity-broker .

# Run with Vault token exchange only
docker run -p 8080:8080 \
  -e IDENTITY_BROKER_VAULT_ADDR="https://vault.example.com:8200" \
  identity-broker

# Run with both Vault and IBM Verify OBO exchange enabled
docker run -p 8080:8080 \
  -e IDENTITY_BROKER_VAULT_ADDR="https://vault.example.com:8200" \
  -e IDENTITY_BROKER_VAULT_TLS_VERIFY="false" \
  -e IDENTITY_BROKER_VERIFY_BASE_URL="https://tenant.verify.ibm.com" \
  -e IDENTITY_BROKER_OBO_CLIENT_ID="<redacted-obo-client-id>" \
  identity-broker

# Override host/port
docker run -p 9090:9090 \
  -e UVICORN_HOST=0.0.0.0 \
  -e UVICORN_PORT=9090 \
  -e IDENTITY_BROKER_VAULT_ADDR="https://vault.example.com:8200" \
  -e IDENTITY_BROKER_VAULT_TLS_VERIFY="false" \
  -e IDENTITY_BROKER_VERIFY_BASE_URL="https://tenant.verify.ibm.com" \
  -e IDENTITY_BROKER_OBO_CLIENT_ID="<redacted-obo-client-id>" \
  identity-broker
```

#### Multi-platform build (arm64 + amd64)

Requires [Docker Buildx](https://docs.docker.com/buildx/working-with-buildx/) and a builder that supports multi-platform builds.

```bash
# Create and activate a multi-platform builder (one-time setup)
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap

# Build and push a multi-arch image to a registry
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t <registry>/<image>:<tag> \
  --push .

# Build locally for a specific target platform (no push)
docker buildx build \
  --platform linux/arm64 \
  -t identity-broker:arm64 \
  --load .
```

## API Reference

### POST /v1/identity/token

Exchange a Vault token for a Vault-signed OIDC Identity JWT.

**Request body:**

| Field | Type | Description |
|---|---|---|
| `vault_token` | string | Vault authentication token (e.g. `hvs.xxxx`) |
| `role_name` | string | Vault OIDC role name |

**Response body:**

| Field | Type | Description |
|---|---|---|
| `identity_token` | string | Vault-signed OIDC JWT |
| `expires_at` | integer | Token expiry as Unix timestamp |
| `cached` | boolean | Whether the token was served from cache |

**HTTP status codes:**

| Code | Description |
|---|---|
| `200` | Success |
| `400` | Invalid request body |
| `401` | Vault authentication failure (invalid/expired token) |
| `500` | Internal service error |
| `503` | Vault unavailable |

### GET /healthz

Liveness probe — returns `{"status": "ok"}`.

---

### POST /v1/identity/obo-token

Exchange a `subject_token` + `actor_token` for an IBM Verify access token on behalf of the subject (RFC 8693 token exchange).

**Request body:**

| Field | Type | Description |
|---|---|---|
| `subject_token` | string | Caller's access token (JWT) — the identity to act on behalf of |
| `actor_token` | string | Vault Identity JWT — identifies the acting service |

**Response body:**

| Field | Type | Description |
|---|---|---|
| `access_token` | string | IBM Verify access token issued for the subject |
| `cached` | boolean | Whether the token was served from cache |

**HTTP status codes:**

| Code | Description |
|---|---|
| `200` | Success |
| `400` | Invalid request body |
| `401` | IBM Verify authentication failure |
| `500` | Token exchange error |
| `503` | IBM Verify unreachable |

---

## Testing the API

### Using curl

#### Exchange a Vault token

```bash
curl -X POST http://localhost:8080/v1/identity/token \
  -H "Content-Type: application/json" \
  -d '{
    "vault_token": "hvs.XXXXXXXXXXXXXXXXXXXX",
    "role_name": "payments-api"
  }'
```

**Expected response (200 OK):**

```json
{
  "identity_token": "<redacted-identity-token>",
  "expires_at": 1700000000,
  "cached": false
}
```

#### Sending the same request again (cache hit)

```bash
curl -X POST http://localhost:8080/v1/identity/token \
  -H "Content-Type: application/json" \
  -d '{
    "vault_token": "hvs.XXXXXXXXXXXXXXXXXXXX",
    "role_name": "payments-api"
  }'
```

**Expected response — note `cached: true`:**

```json
{
  "identity_token": "<redacted-identity-token>",
  "expires_at": 1700000000,
  "cached": true
}
```

#### Pass a correlation ID for tracing

```bash
curl -X POST http://localhost:8080/v1/identity/token \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: my-trace-id-123" \
  -d '{
    "vault_token": "hvs.XXXXXXXXXXXXXXXXXXXX",
    "role_name": "payments-api"
  }'
```

The response will echo back `X-Request-ID: my-trace-id-123` as a header.

#### Health check

```bash
curl http://localhost:8080/healthz
```

**Expected response:**

```json
{"status": "ok"}
```

#### OBO token exchange

```bash
curl -X POST http://localhost:8080/v1/identity/obo-token \
  -H "Content-Type: application/json" \
  -d '{
    "subject_token": "<redacted-subject-token>",
    "actor_token": "<redacted-actor-token>"
  }'
```

**Expected response (200 OK):**

```json
{
  "access_token": "<redacted-access-token>",
  "cached": false
}
```

#### View interactive API docs (Swagger UI)

```bash
open http://localhost:8080/docs
```

---

### Using Postman

#### Step 1 — Create a new request

1. Open Postman and click **New → HTTP Request**.
2. Set the method to **POST**.
3. Enter the URL: `http://localhost:8080/v1/identity/token`

#### Step 2 — Set the request body

1. Click the **Body** tab.
2. Select **raw** and choose **JSON** from the format dropdown.
3. Paste the following:

```json
{
  "vault_token": "hvs.XXXXXXXXXXXXXXXXXXXX",
  "role_name": "payments-api"
}
```

#### Step 3 — (Optional) Add a correlation header

1. Click the **Headers** tab.
2. Add: `X-Request-ID` → `my-trace-id-123`

#### Step 4 — Send the request

Click **Send**. You should receive a `200 OK` with the identity token in the response body.

#### Step 5 — Health check

1. Create a new **GET** request.
2. URL: `http://localhost:8080/healthz`
3. Click **Send** — expect `{"status": "ok"}`.

---

### Error scenarios

#### Invalid Vault token (401)

```bash
curl -X POST http://localhost:8080/v1/identity/token \
  -H "Content-Type: application/json" \
  -d '{
    "vault_token": "hvs.INVALID",
    "role_name": "payments-api"
  }'
```

```json
{"detail": "Invalid or expired Vault token"}
```

#### Missing required field (400)

```bash
curl -X POST http://localhost:8080/v1/identity/token \
  -H "Content-Type: application/json" \
  -d '{
    "vault_token": "hvs.XXXXXXXXXXXXXXXXXXXX"
  }'
```

```json
{"detail": [{"msg": "Field required", "loc": ["body", "role_name"]}]}
```

#### Vault unreachable (503)

```json
{"detail": "Vault is unavailable"}
```

---

## Running Tests

```bash
uv run pytest
```

```bash
# With verbose output
uv run pytest -v

# Run a specific test file
uv run pytest tests/test_routes.py -v
```

## Project Structure

```
.
├── api/
│   ├── main.py         # FastAPI app, middleware, lifespan
│   └── routes.py       # POST /v1/identity/token, POST /v1/identity/obo-token, GET /healthz
├── broker/
│   ├── broker.py       # VaultIdentityBroker (get_signed_identity_token)
│   ├── cache.py        # TTLCache wrapper with JWT expiry validation
│   └── vault_client.py # hvac.Client wrapper
├── verify/
│   ├── verify_client.py # IBMVerifyClient (HTTP OBO token exchange)
│   └── obo_broker.py    # OBOBroker (exchange_obo_token)
├── models/
│   └── schemas.py      # TokenRequest/TokenResponse, OBOTokenRequest/OBOTokenResponse
├── app_logging/
│   └── logger.py       # structlog structured JSON logger
├── exceptions/
│   └── errors.py       # VaultBrokerError + VerifyOBOError hierarchies
└── config/
    └── settings.py     # Pydantic settings (env vars)
```

`app_logging/` is intentionally named to avoid shadowing Python's standard-library `logging` module now that the source packages live at the repository root.

## Security Notes

- **TLS verification** is enabled by default — never disable it in production.
- When Vault uses a **self-signed or private CA**, set `IDENTITY_BROKER_VAULT_CA_BUNDLE` to your PEM bundle path instead of setting `VAULT_TLS_VERIFY=false`. This keeps full TLS verification while trusting your CA.
- Vault tokens, JWTs, and IBM Verify access tokens are **never logged**.
- Cache keys are hashed — `sha256(vault_token + role_name)` for Vault tokens and `sha256(subject_token + actor_token)` for OBO tokens — raw tokens are never stored as keys.
- The Vault policy should grant access to `identity/oidc/token/<role_name>` only.
- `IDENTITY_BROKER_VERIFY_BASE_URL` and `IDENTITY_BROKER_OBO_CLIENT_ID` must be set before starting the service if the OBO endpoint will be used.
