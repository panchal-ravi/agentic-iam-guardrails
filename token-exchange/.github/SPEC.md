Below is the **updated specification** that includes exposing the library functionality through a **high-performance API service** while preserving the original **Python library design**.

---

# Specification: Vault Identity Broker Library and API (Python)

## 1. Overview

### 1.1 Purpose

Build a **Python-based identity broker** that:

1. Exchanges a **Vault token** for a **Vault-signed Identity JWT (OIDC ID Token)**.
2. Implements **in-memory caching** to reuse valid identity tokens.
3. Exposes the functionality via a **high-performance API service** for external consumers.
4. Implements production-grade engineering practices:

   * security
   * logging
   * resilience
   * observability

The service acts as an **identity brokering layer** for internal services.

Primary identity provider:

* **HashiCorp Vault**

Additionally, the system implements an **on-behalf-of (OBO) token exchange flow** with **IBM Verify**:

5. Accepts a `subject_token` (caller's access token) and an `actor_token` (Vault Identity JWT).
6. Performs an RFC 8693 Token Exchange against IBM Verify to obtain a new access token on behalf of the subject.
7. Caches the resulting OBO access token with JWT-expiry-aware validation.

---

# 2. System Architecture

## 2.1 High-Level Architecture

```
Client Application
        │
        │ REST API
        ▼
Identity Broker API
(FastAPI Service)
        │
        ├── POST /v1/identity/token ──────► VaultIdentityBroker Library ──► HashiCorp Vault
        │
        └── POST /v1/identity/obo-token ──► OBOBroker Library ──────────► IBM Verify
```

Components:

1. **Identity Broker API**
2. **Vault Identity Broker Library**
3. **OBO Broker Library**
4. **In-memory cache** (shared)
5. **Vault integration**
6. **IBM Verify integration**

---

# 3. Technology Stack

## 3.1 Core Libraries

| Concern            | Library    |
| ------------------ | ---------- |
| API Framework      | FastAPI    |
| ASGI Server        | Uvicorn    |
| Vault SDK          | hvac       |
| HTTP client        | requests   |
| Caching            | cachetools |
| JWT parsing        | PyJWT      |
| Retry handling     | tenacity   |
| Logging            | structlog  |
| Validation         | pydantic   |

## 3.2 Dependency Management

Dependency manager: **uv**

* Dependencies declared in `pyproject.toml` under `[project].dependencies`
* Dev dependencies (pytest, httpx) declared under `[dependency-groups].dev`
* Lockfile: `uv.lock` (committed to version control)
* Install: `uv sync`
* Run commands: `uv run <command>` (e.g. `uv run pytest`, `uv run uvicorn api.main:app`)

Recommended API framework:

* **FastAPI**

Chosen because it provides:

* High performance (ASGI)
* Native async support
* Automatic OpenAPI generation
* Strong request validation

---

# 4. Functional Requirements

## 4.1 Identity Exchange

The system must:

1. Accept a Vault token and role name.
2. Call Vault Identity API.
3. Return a **Vault signed identity JWT**.

Vault method reference:

```
identity.generate_signed_id_token
```

Documentation:
[https://python-hvac.org/en/stable/usage/secrets_engines/identity.html#generate-signed-id-token](https://python-hvac.org/en/stable/usage/secrets_engines/identity.html#generate-signed-id-token)

---

## 4.2 On-Behalf-Of (OBO) Token Exchange

The system must:

1. Accept a `subject_token` (caller's access token, JWT) and an `actor_token` (Vault Identity JWT).
2. Perform an RFC 8693 token exchange against the IBM Verify token endpoint.
3. Return the IBM Verify **access token** issued on behalf of the subject.

IBM Verify token endpoint:

```
POST <VERIFY_BASE_URL>/oauth2/token
```

Reference curl:

```bash
curl -s -X POST https://tenant.verify.ibm.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$OBO_CLIENT_ID" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
  -d "requested_token_type=urn:ietf:params:oauth:token-type:access_token" \
  -d "subject_token_type=urn:ietf:params:oauth:token-type:access_token" \
  -d "subject_token=$access_token" \
  -d "actor_token_type=urn:demo:token-type:vault-identity-jwt" \
  -d "actor_token=$actor_token"
```

---

# 5. API Specification

## 5.1 Endpoint

```
POST /v1/identity/token
```

---

## 5.2 Request Body

```json
{
  "vault_token": "hvs.xxxxxx",
  "role_name": "payments-api"
}
```

### Fields

| Field       | Type   | Description                |
| ----------- | ------ | -------------------------- |
| vault_token | string | Vault authentication token |
| role_name   | string | Vault OIDC role            |

---

## 5.3 Response

```json
{
  "identity_token": "<redacted-identity-token>",
  "expires_at": 1700000000,
  "cached": true
}
```

### Fields

| Field          | Description                   |
| -------------- | ----------------------------- |
| identity_token | Vault signed identity JWT     |
| expires_at     | Unix timestamp                |
| cached         | Whether token came from cache |

---

## 5.4 HTTP Status Codes

| Code | Description                  |
| ---- | ---------------------------- |
| 200  | Success                      |
| 400  | Invalid request              |
| 401  | Vault authentication failure |
| 500  | Internal service error       |
| 503  | Vault unavailable            |

---

# 5a. OBO API Specification

## 5a.1 Endpoint

```
POST /v1/identity/obo-token
```

---

## 5a.2 Request Body

```json
{
  "subject_token": "<redacted-subject-token>",
  "actor_token": "<redacted-actor-token>"
}
```

### Fields

| Field         | Type   | Description                                              |
| ------------- | ------ | -------------------------------------------------------- |
| subject_token | string | Caller's access token (JWT) — the identity to act on behalf of |
| actor_token   | string | Vault Identity JWT — identifies the actor performing the exchange |

---

## 5a.3 Response

```json
{
  "access_token": "<redacted-access-token>",
  "cached": false
}
```

### Fields

| Field        | Description                               |
| ------------ | ----------------------------------------- |
| access_token | IBM Verify access token issued for subject |
| cached       | Whether the token was served from cache   |

---

## 5a.4 HTTP Status Codes

| Code | Description                         |
| ---- | ----------------------------------- |
| 200  | Success                             |
| 400  | Invalid request                     |
| 401  | IBM Verify authentication failure   |
| 500  | Token exchange error                |
| 503  | IBM Verify unreachable              |

---



## 6.1 Public Method

```python
get_signed_identity_token(
    vault_token: str,
    role_name: str
) -> str
```

### Inputs

| Parameter   | Type |
| ----------- | ---- |
| vault_token | str  |
| role_name   | str  |

### Output

Returns:

```
Vault signed JWT token
```

---

# 6a. OBO Library Specification

## 6a.1 Public Method

```python
exchange_obo_token(
    subject_token: str,
    actor_token: str,
) -> OBOTokenResult
```

### Inputs

| Parameter     | Type |
| ------------- | ---- |
| subject_token | str  |
| actor_token   | str  |

### Output

Returns:

```
OBOTokenResult(access_token, cached)
```

---



## 7.1 Cache Type

* In-memory
* thread-safe
* TTL aware

Recommended implementation:

```
cachetools.TTLCache
```

---

## 7.2 Cache Key

Cache key for Vault identity tokens derived from:

```
vault_token + role_name
```

Cache key for OBO tokens derived from:

```
subject_token + actor_token
```

Both are hashed to prevent token exposure.

Example:

```
sha256(vault_token + role_name)
sha256(subject_token + actor_token)
```

---

## 7.3 Cache Validation

Before returning cached token:

1. Decode JWT.
2. Extract `exp` claim.
3. Check expiration.

```
if current_time < exp - safety_buffer
    return cached token
else
    refresh token
```

---

## 7.4 Expiration Safety Buffer

```
SAFETY_BUFFER = 30 seconds
```

Prevents edge expiration failures.

---

# 8. API Layer Design

## 8.1 FastAPI Router

Example endpoint design:

```
POST /v1/identity/token
```

Handler flow:

```
validate request
     │
     ▼
call VaultIdentityBroker
     │
     ▼
return identity token
```

---

## 8.2 Request Model

Using **Pydantic**:

```python
class TokenRequest(BaseModel):
    vault_token: str
    role_name: str
```

---

## 8.3 Response Model

```python
class TokenResponse(BaseModel):
    identity_token: str
    expires_at: int
    cached: bool
```

---

# 9. Module Structure

```
.
│
├── api/
│   ├── main.py
│   └── routes.py
│
├── broker/
│   ├── broker.py
│   ├── cache.py
│   └── vault_client.py
│
├── verify/
│   ├── __init__.py
│   ├── verify_client.py
│   └── obo_broker.py
│
├── models/
│   └── schemas.py
│
├── app_logging/
│   └── logger.py
│
├── exceptions/
│   └── errors.py
│
└── config/
    └── settings.py
```

Notes:

* Source packages live directly at the repository root; there is no extra top-level `identity_broker/` package directory.
* The logging package is named `app_logging/` to avoid colliding with Python's standard-library `logging` module.

---

# 10. Vault Integration

Vault SDK:

```
hvac.Client
```

Token exchange:

```python
client.secrets.identity.generate_signed_id_token(
    name=role_name
)
```

Authentication:

```
client.token = vault_token
```

---

# 11. Error Handling

## 11.1 Custom Exceptions

```
VaultBrokerError
VaultAuthenticationError
VaultTokenGenerationError
CacheError
VerifyOBOError
VerifyAuthenticationError
VerifyTokenExchangeError
```

---

## 11.2 API Error Mapping

| Exception                 | HTTP Response |
| ------------------------- | ------------- |
| VaultAuthenticationError  | 401           |
| VaultTokenGenerationError | 500           |
| CacheError                | 500           |
| VerifyAuthenticationError | 401           |
| VerifyTokenExchangeError  | 500           |

---

# 12. Retry Strategy

Use **tenacity**.

Retry when:

* Vault network failure
* 5xx errors

Policy:

```
max_attempts = 3
exponential backoff
```

---

# 13. Logging

Logging requirements:

* structured JSON logs
* correlation IDs
* no secrets

Example log:

```json
{
  "event": "vault_token_exchange",
  "role_name": "payments-api",
  "cache_hit": true,
  "duration_ms": 25
}
```

Never log:

* vault tokens
* JWT tokens

---

# 14. Security Requirements

## 14.1 Transport Security

* HTTPS required
* TLS verification enabled by default (`IDENTITY_BROKER_VAULT_TLS_VERIFY=true`)
* When Vault uses a **self-signed or private CA certificate**, set `IDENTITY_BROKER_VAULT_CA_BUNDLE` to the path of a PEM CA bundle instead of disabling TLS verification. The bundle may contain a single private CA certificate or a concatenation of multiple CA certificates (e.g. existing root CAs with the private CA appended).

```
# Example — trust a self-signed Vault CA while keeping TLS verification on
IDENTITY_BROKER_VAULT_TLS_VERIFY=true
IDENTITY_BROKER_VAULT_CA_BUNDLE=/etc/ssl/certs/vault-ca.pem
```

The `verify` parameter passed to `hvac.Client` resolves as follows:

| `VAULT_CA_BUNDLE` | `VAULT_TLS_VERIFY` | Effective `verify` |
| --- | --- | --- |
| set (path) | any | path string — TLS on, custom CA trusted |
| unset | `true` | `True` — standard TLS verification |
| unset | `false` | `False` — **not recommended in production** |

---

## 14.2 Sensitive Data Handling

Never log:

```
vault_token
jwt
vault responses
```

---

## 14.3 Vault Permissions

Vault policy must allow:

```
identity/oidc/token/<role_name>
```

Only.

## 14.4 IBM Verify OBO Configuration

Environment variables required for the OBO token exchange:

| Variable                            | Description                                          | Required |
| ----------------------------------- | ---------------------------------------------------- | -------- |
| `IDENTITY_BROKER_VERIFY_BASE_URL`   | IBM Verify tenant base URL (no trailing `/`)         | Yes      |
| `IDENTITY_BROKER_OBO_CLIENT_ID`     | Client ID for the OBO token exchange (public client) | Yes      |

Example:

```
IDENTITY_BROKER_VERIFY_BASE_URL=https://tenant.verify.ibm.com
IDENTITY_BROKER_OBO_CLIENT_ID=<redacted-obo-client-id>
```

These must be set before starting the service. Missing values will cause a startup configuration error.

---



| Metric             | Target            |
| ------------------ | ----------------- |
| Cache hit latency  | <2ms              |
| API response       | <50ms (cache hit) |
| Vault call latency | <200ms            |

---

# 16. Concurrency

Service must support:

* multi-threaded execution
* async request handling
* safe cache access

FastAPI with **Uvicorn workers** recommended.

---

# 17. Observability

Metrics to expose:

* cache_hits
* cache_misses
* vault_requests
* vault_failures
* request_latency

Optional integration:

* Prometheus
* OpenTelemetry

---

# 18. Deployment

Recommended container deployment.

Example:

```
Docker
Kubernetes
```

Typical stack:

```
FastAPI
Uvicorn
Gunicorn (optional)
```

Container image guidance:

* Use a multi-stage Docker build.
* Install production dependencies in the builder stage with `uv sync --frozen --no-dev --no-install-project`.
* Copy the resulting dependency-only virtualenv into the runtime image together with the source directories. This is acceptable when the builder and runtime stages use the same Python base image and avoids reinstalling dependencies in the final stage.

---

# 19. Example API Call

Request:

```
POST /v1/identity/token
```

```
curl -X POST http://localhost:8080/v1/identity/token \
 -H "Content-Type: application/json" \
 -d '{
   "vault_token": "hvs.xxxx",
   "role_name": "payments-api"
 }'
```

---

# 20. Future Enhancements

Potential improvements:

* Redis distributed cache
* mTLS authentication
* rate limiting
* service-to-service authentication
* JWT signature verification
* async Vault client
* async HTTP client for IBM Verify (httpx)

---

# Summary

This system provides:

* A **Python identity broker library**
* A **high-performance REST API**
* **Vault token → Identity JWT exchange**
* **IBM Verify on-behalf-of (OBO) token exchange**
* **Smart in-memory caching**
* **production-grade resilience and security**

Powered by:

* **HashiCorp Vault**
* **IBM Verify**
* **FastAPI**

---
