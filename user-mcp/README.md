# User MCP

This service is a FastMCP-based Model Context Protocol server that exposes user-management tools (`list_all_users`, `search_users_by_first_name`, `create_user`, `delete_user_by_email`, `update_user_by_email`) over **streamable HTTP**. It is consumed by [`ai-agent`](../ai-agent/) via [`langchain-mcp-adapters`](https://github.com/langchain-ai/langchain-mcp-adapters), which forwards the OBO bearer token issued by `token-exchange`. Every request is authenticated by validating the OBO JWT against IBM Verify's JWKS — signature, audience, issuer, and expiry are all enforced before any tool runs. The data layer is pluggable: a `file` backend serves the in-memory JSON list (dev) and a `postgres` backend uses asyncpg (target deployment).

## Current project structure

```text
user-mcp/
├── server.py                 # ASGI entrypoint (uvicorn server:app)
├── mcp_app.py                # FastMCP server + lifespan that owns the repo lifecycle
├── config.py                 # pydantic-settings, USER_MCP_* env vars
├── logging_utils.py          # Structured JSON logging + identity context binding
├── errors.py                 # AppError type
├── models.py                 # UserRecord (pydantic, extra=allow)
├── auth/
│   └── jwt_validator.py      # PyJWT + PyJWKClient + ASGI JwtAuthMiddleware
├── tools/
│   └── users.py              # @mcp.tool() definitions, async wrappers around repo
├── storage/
│   ├── base.py               # UserRepository ABC + email normalization
│   ├── file_repo.py          # FileUserRepository (asyncio.Lock, in-memory)
│   ├── postgres_repo.py      # PostgresUserRepository (asyncpg pool)
│   └── factory.py            # build_repository(settings)
├── tests/
│   ├── conftest.py
│   ├── test_jwt_validator.py
│   ├── test_file_repo.py
│   └── test_tools_e2e.py     # FastMCP in-memory Client end-to-end checks
├── pyproject.toml            # uv project definition
├── Dockerfile                # 2-stage uv container (mirrors token-exchange)
├── .env.example
├── users_repository.json     # Seed data for the file backend
└── README.md
```

## Architecture

The application exposes a single MCP endpoint over streamable HTTP:

- `POST {USER_MCP_PATH}` — JSON-RPC over streamable HTTP (default path `/mcp`).

High-level request flow:

1. The Starlette ASGI app receives a streamable-HTTP POST.
2. `JwtAuthMiddleware` extracts the `Authorization: Bearer …` header. The OBO JWT is validated against IBM Verify's JWKS (signature, `aud`, `iss`, `exp`, `iat`) using `PyJWKClient` with a configurable cache TTL.
3. Validated identity (`preferred_username`, `agent_id`, `scope`, `sub`) is attached to the request scope and bound into the structured-logging context, so every subsequent log line is prefixed with `[user=<preferred_username> agent=<agent_id>]`.
4. The FastMCP server dispatches the JSON-RPC call to the appropriate tool.
5. The tool delegates to the configured `UserRepository` (file or Postgres) and returns a typed `UserRecord` (or list).
6. Application errors raised by the repo layer are translated to FastMCP `ToolError` with stable codes (400 `invalid_request`, 404 `invalid_request`, 500 `agent_error`).

If the OBO JWT is missing or invalid the middleware short-circuits with a JSON 401 (`invalid_request`, `invalid_token`, `expired_token`, `invalid_audience`, `invalid_issuer`) — the tool layer is never reached.

## Available tools

| Tool | Inputs | Output | Description |
| --- | --- | --- | --- |
| `list_all_users` | — | `UserRecord[]` | All users currently stored. |
| `search_users_by_first_name` | `first_name: str` | `UserRecord[]` | Exact, case-insensitive first-name match. |
| `create_user` | `user: UserRecord` | `UserRecord` | Create a new user. Email must be unique. Errors 400 on duplicate email. |
| `update_user_by_email` | `email: str`, `user: UserRecord` | `UserRecord` | Replace the user identified by `email`. Errors 404 if missing, 400 on email collision. |
| `delete_user_by_email` | `email: str` | `UserRecord` | Delete by email. Errors 404 if missing. |

`UserRecord` accepts `email` (required, RFC-validated) plus optional `first_name`, `last_name`, `ssn`, `phone`, `credit_card_number`, `ip_address`, and arbitrary additional fields (`extra="allow"`).

## Storage backends

Selected by `USER_BACKEND`:

- `file` (default) — loads `USER_MCP_USERS_FILE` once at startup into an in-memory list guarded by an `asyncio.Lock`. Mutations are **not** written back to disk and are lost on restart. Intended for local dev.
- `postgres` — connects to `USER_MCP_PG_DSN` via an asyncpg pool. With `USER_MCP_AUTO_MIGRATE=true`, idempotent DDL creates the `users` table and supporting indexes on startup. Email uniqueness is enforced by a unique index on `lower(email)`.

In this phase the Postgres backend uses a static DSN. The next phase replaces that with short-lived credentials minted by HashiCorp Vault using the OBO JWT — see [Next phase: Vault integration](#next-phase-vault-integration).

## Configuration

The service reads environment variables from the process environment and also loads a local `.env` file if present.

| Variable | Default | Purpose |
| --- | --- | --- |
| `USER_MCP_HOST` | `0.0.0.0` | Bind host. |
| `USER_MCP_PORT` | `8090` | Bind port. |
| `USER_MCP_PATH` | `/mcp` | Path the streamable-HTTP transport is mounted at. |
| `USER_MCP_LOG_LEVEL` | `INFO` | Logging level. |
| `USER_MCP_VERIFY_BASE_URL` | (unset) | IBM Verify issuer base URL, e.g. `https://tenant.verify.ibm.com`. JWKS URL is derived as `{base}/oauth2/jwks` unless overridden. Also used as the default `iss` value. |
| `USER_MCP_VERIFY_JWKS_URL` | (unset) | Explicit JWKS URL override. |
| `USER_MCP_AUDIENCE` | (unset) | Required `aud` claim value. The MCP server's identifier in IBM Verify. |
| `USER_MCP_ISSUER` | (unset) | Required `iss` claim value. Defaults to `USER_MCP_VERIFY_BASE_URL`. |
| `USER_MCP_JWKS_CACHE_SECONDS` | `3600` | JWKS cache lifespan for `PyJWKClient`. |
| `USER_MCP_BYPASS_AUTH` | `false` | When `true`, skip JWT validation and accept all requests with placeholder identity. Dev only. |
| `USER_BACKEND` | `file` | Storage backend: `file` or `postgres`. |
| `USER_MCP_USERS_FILE` | `./users_repository.json` | Seed file used when `USER_BACKEND=file`. |
| `USER_MCP_PG_DSN` | (unset) | Postgres DSN, e.g. `postgresql://user:pass@host:5432/users`. Required for `USER_BACKEND=postgres`. |
| `USER_MCP_AUTO_MIGRATE` | `true` | When `true`, run idempotent CREATE TABLE / INDEX statements at startup. |

Logs are emitted as JSON to stderr with the same field shape as `ai-agent` (`timestamp`, `level`, `logger`, `hostname`, `host_ip`, `process_id`, `module`, `function`, `method_name`, `line_number`, `message`, plus per-request `request_id`, `preferred_username`, `actor_agent_id`, `auth_scope`). Tool entry/failure are logged at INFO; tool success and JWKS cache hits are at DEBUG.

## Local development with uv

Create and sync the environment:

```bash
uv venv .venv
source .venv/bin/activate
uv sync --dev
```

Run tests:

```bash
python -m pytest -q
```

The Postgres tests are marked `@pytest.mark.integration` and skipped by default. To run them, point `USER_MCP_PG_DSN` at a local Postgres and run:

```bash
USER_MCP_PG_DSN=postgresql://user:pass@localhost:5432/users \
  python -m pytest -q -m integration
```

## Start the application directly

1. Copy and edit `.env`:

```bash
cp .env.example .env
# For first-time smoke testing, set USER_MCP_BYPASS_AUTH=true to skip JWT.
```

2. Start the service:

```bash
uv run uvicorn server:app --host 0.0.0.0 --port 8090
```

The streamable-HTTP endpoint is `http://localhost:8090/mcp`.

## Build the container

The Dockerfile works with both regular `docker build` and `docker buildx` multi-architecture builds.

From the `user-mcp` directory:

```bash
docker build -t agentguard-user-mcp .
```

Build a specific architecture and load it into the local Docker image store:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t agentguard-user-mcp:amd64 \
  --load \
  .
```

Build and publish a multi-architecture image:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t your-registry/agentguard-user-mcp:latest \
  --push \
  .
```

## Start the application in a container

```bash
docker run --rm \
  -p 8090:8090 \
  --env-file .env \
  agentguard-user-mcp
```

For the Postgres backend, point `USER_MCP_PG_DSN` at a reachable host (`host.docker.internal` on macOS/Windows, the cluster service name on Kubernetes).

## Deploy on Kubernetes

The container is configured to listen on port `8090`. For Kubernetes, you need:

- an image pushed to a registry that your cluster can pull from
- a Secret generated from an env file containing the runtime configuration (`USER_MCP_*` and `USER_BACKEND`-specific entries)
- a Deployment that mounts that Secret as `.env` inside the container and a Service exposing port `8090`

Once the manifests land in `deploy-k8s/user-mcp.yaml` and `deploy-k8s/user-mcp.env`, deployment follows the same pattern documented in [`deploy-k8s/README.md`](../deploy-k8s/README.md):

```bash
kubectl create namespace user-mcp
kubectl create secret generic user-mcp-env \
  --from-env-file=deploy-k8s/user-mcp.env \
  -n user-mcp
kubectl apply -f deploy-k8s/user-mcp.yaml -n user-mcp
```

## Manual test steps

### 1. Smoke-test with `USER_MCP_BYPASS_AUTH=true`

```bash
# In .env: USER_MCP_BYPASS_AUTH=true, USER_BACKEND=file
uv run uvicorn server:app --port 8090
```

In another terminal, drive the server with the MCP Inspector:

```bash
npx @modelcontextprotocol/inspector --transport streamable-http http://localhost:8090/mcp
```

In the inspector, run `tools/list` (you should see all five tools), then call `list_all_users` with `{}`, and verify the seed data comes back.

Or with raw `curl`:

```bash
curl -N -X POST http://localhost:8090/mcp \
  -H 'Accept: application/json, text/event-stream' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer dummy' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

### 2. Validate JWT enforcement (BYPASS off)

Disable bypass in `.env`, restart the server, and confirm 401 on a bad token:

```bash
curl -i -X POST http://localhost:8090/mcp \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer not-a-jwt' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
# expect: HTTP/1.1 401  {"error":"invalid_token","message":"..."}
```

Then run with a real OBO token issued by `token-exchange` and confirm 200.

### 3. End-to-end via `ai-agent`

```bash
# Terminal 1
cd user-mcp && uv run uvicorn server:app --port 8090
# Terminal 2 — ai-agent/.env: USER_MCP_URL=http://localhost:8090/mcp
cd ai-agent && uv run uvicorn agent_api:app --port 8000
# Terminal 3
curl -N -X POST http://localhost:8000/v1/agent/query \
  -H "Authorization: Bearer ${BEARER_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"List all users"}]}'
```

In `user-mcp` logs you should see a JSON line per tool invocation with `event: tool_invoked`, `tool: list_all_users`, and the `[user=<preferred_username> agent=<agent_id>]` prefix on `message`.

Exercise each tool with natural-language prompts:

- "List all users" → `list_all_users`
- "Find users named Noah" → `search_users_by_first_name`
- "Create a user with email demo@example.com, first name Demo" → `create_user`
- "Update demo@example.com to last name X" → `update_user_by_email`
- "Delete demo@example.com" → `delete_user_by_email`

## Next phase: Vault integration

The current phase ships with **static** Postgres credentials in `USER_MCP_PG_DSN`. The next phase replaces them with short-lived credentials minted by HashiCorp Vault using the OBO JWT, so every database connection is bound to the validated user/agent identity. The application code change is small (the asyncpg pool is rebuilt on credential refresh); the bulk of the work is Vault configuration:

1. **Enable the JWT auth method** in Vault and bind it to IBM Verify's discovery URL:

   ```bash
   vault auth enable -path=auth/jwt-user-mcp jwt
   vault write auth/jwt-user-mcp/config \
     oidc_discovery_url="$USER_MCP_VERIFY_BASE_URL" \
     bound_issuer="$USER_MCP_VERIFY_BASE_URL"
   ```

2. **Create a Vault role** that scopes who may exchange an OBO for DB credentials. The role binds on the `aud` and `scope` claims, so only OBO tokens issued for `user-mcp` with the right scope can mint DB creds:

   ```bash
   vault write auth/jwt-user-mcp/role/user-mcp-app \
     role_type=jwt \
     user_claim=preferred_username \
     bound_audiences=user-mcp \
     bound_claims='{"scope":"users.read users.write"}' \
     token_policies=user-mcp-db-creds \
     ttl=5m max_ttl=15m
   ```

3. **Enable the database secrets engine** and configure a connection that uses a Vault-only admin DB user, then create a role that issues short-lived DML-only credentials:

   ```bash
   vault secrets enable database
   vault write database/config/users-db \
     plugin_name=postgresql-database-plugin \
     allowed_roles="user-mcp-app-role" \
     connection_url='postgresql://{{username}}:{{password}}@<host>:5432/users?sslmode=disable' \
     username="vault-admin" \
     password="<rotated-out-of-band>"
   vault write database/roles/user-mcp-app-role \
     db_name=users-db \
     creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
       GRANT INSERT, SELECT, UPDATE, DELETE ON users TO \"{{name}}\";" \
     default_ttl=1h max_ttl=24h
   ```

4. **Write a Vault policy** that allows only reading those credentials (no other Vault paths):

   ```hcl
   path "database/creds/user-mcp-app-role" {
     capabilities = ["read"]
   }
   ```

   ```bash
   vault policy write user-mcp-db-creds policy.hcl
   ```

5. **Wire the application** to authenticate to Vault with the same OBO it just validated, then exchange for DB credentials:

   ```text
   POST {VAULT_ADDR}/v1/auth/jwt-user-mcp/login   { role: "user-mcp-app", jwt: "<obo>" }
   GET  {VAULT_ADDR}/v1/database/creds/user-mcp-app-role
   ```

   Build the asyncpg pool with the returned `username`/`password`. Refresh on lease expiry. New env vars: `USER_MCP_VAULT_ADDR`, `USER_MCP_VAULT_JWT_ROLE` (`user-mcp-app`), `USER_MCP_VAULT_DB_ROLE` (`user-mcp-app-role`). Drop `USER_MCP_PG_DSN` once wired.

This pattern keeps secrets off disk, bounds DB access to validated identity + scope, and produces short-lived, auditable credentials.
