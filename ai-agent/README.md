# AI Agent

This service is a FastAPI-based AI agent runtime. It accepts chat messages, validates a bearer token, exchanges that token for an on-behalf-of (OBO) token, optionally invokes local tools through LangChain, and streams plain-text responses back to the caller. For test environments, an env flag can bypass the incoming bearer-token requirement and skip OBO token exchange entirely.

## Current project structure

```text
ai-agent/
├── agent_api.py           # FastAPI app, middleware, exception handlers, route wiring
├── agent_runtime.py       # LangChain orchestration and streaming response handling
├── config.py              # Environment-driven settings
├── identity.py            # Actor token loading, OBO exchange, in-memory cache
├── security.py            # Bearer token extraction and lightweight JWT validation
├── tools.py               # Local tools exposed to the agent
├── models.py              # Request models
├── logging_utils.py       # Structured logging helpers
├── errors.py              # Application error type
├── users_repository.json  # Local user dataset used by the search tool
├── test_agent_api.py      # API and token flow tests
├── pyproject.toml         # uv project definition
├── uv.lock                # Locked dependencies for uv
├── requirements.txt       # Legacy dependency list
├── Dockerfile             # Container build
└── SPEC.md                # Product and behavior notes
```

## Architecture

The application has two public endpoints:

- `POST /v1/agent/query`
- `GET /v1/agent/tokens`

High-level request flow:

1. FastAPI receives the request and assigns a request ID.
2. The `Authorization: Bearer ...` header is validated unless bypass mode is enabled.
3. The actor token is read from `ACTOR_TOKEN_PATH`.
4. The service exchanges the incoming bearer token for an OBO token through `TOKEN_EXCHANGE_URL`, unless bypass mode is enabled.
5. OBO tokens are cached in memory until expiry.
6. LangChain binds the available tools and runs the agent flow.
7. The response is streamed back as `text/plain`.

The token lookup endpoint validates the incoming `Authorization: Bearer ...` header, derives the same cache key from the access token and configured role name, and returns both the cached OBO token and the agent actor token without triggering a new token exchange.

`GET /v1/agent/tokens` returns JSON in this shape:

```json
{
  "obo_token": "eyJ...",
  "actor_token": "eyJ..."
}
```

## Available tools

The agent currently exposes two tools:

- `search_users_by_first_name`: reads `users_repository.json` and returns matching users as JSON
- `shell`: executes shell commands from the application directory

## Configuration

The service reads environment variables from the process environment and also loads a local `.env` file if present.

| Variable | Default | Purpose |
| --- | --- | --- |
| `LANGCHAIN_MODEL` | `openai:gpt-5-mini` | Provider-qualified chat model string passed to LangChain, for example `openai:gpt-5-mini` |
| `OPENAI_API_KEY` | none | OpenAI API key when using an OpenAI-backed `LANGCHAIN_MODEL` |
| `ACTOR_TOKEN_PATH` | `/vault/secrets/actor-token` | Filesystem path to the actor token |
| `TOKEN_EXCHANGE_URL` | `http://localhost:8080/v1/identity/obo-token` | OBO token exchange endpoint |
| `TOKEN_EXCHANGE_TIMEOUT_SECONDS` | `10` | Token exchange timeout |
| `OBO_ROLE_NAME` | `agent-runtime` | Cache key input for OBO token reuse |
| `BYPASS_AUTH_TOKEN_EXCHANGE` | `false` | When `true`, `/v1/agent/query` does not require `Authorization` and skips OBO token exchange; `/v1/agent/tokens` will not return cached tokens |
| `HOST` | `0.0.0.0` | Bind host |
| `PORT` | `8000` | Bind port |
| `LOG_LEVEL` | `INFO` | Logging level |

`BYPASS_AUTH_TOKEN_EXCHANGE` is intended for local or test environments where the Agent API should run without security integration. When set to `true`, `POST /v1/agent/query` accepts requests without an `Authorization: Bearer ...` header, skips bearer-token validation, and does not call the token-exchange service. In the same mode, `GET /v1/agent/tokens` returns `404` because no OBO token is exchanged or cached. The default is `false`, which preserves the normal secure flow.

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

## Start the application directly

1. Create an actor token file:

```bash
mkdir -p .local
printf 'actor-token\n' > .local/actor-token
```

2. Export the required environment variables:

```bash
export OPENAI_API_KEY="your-openai-api-key"
export ACTOR_TOKEN_PATH="$(pwd)/.local/actor-token"
export TOKEN_EXCHANGE_URL="http://localhost:8080/v1/identity/obo-token"
export BYPASS_AUTH_TOKEN_EXCHANGE="false"
export HOST="0.0.0.0"
export PORT="8000"
```

3. Start the service:

```bash
uv run uvicorn agent_api:app --host 0.0.0.0 --port 8000
```

## Build the container

The Dockerfile works with both regular `docker build` and `docker buildx` multi-architecture builds. Docker selects the requested platform automatically, so the file does not need explicit `--platform=$TARGETPLATFORM` directives.

From the `ai-agent` directory, a normal local build still works:

```bash
docker build -t agentguard-ai-agent .
```

To build a specific architecture locally with Buildx and load it into your local Docker image store:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t agentguard-ai-agent:amd64 \
  --load \
  .
```

To build and publish a multi-architecture image manifest for both `linux/amd64` and `linux/arm64`:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t your-registry/agentguard-ai-agent:latest \
  --push \
  .
```

Use `--push` for true multi-architecture output. Docker cannot `--load` multiple architectures into the local image store in one command.

## Start the application in a container

1. Create an actor token file on the host:

```bash
mkdir -p .local
printf 'actor-token\n' > .local/actor-token
```

2. Run the container:

```bash
docker run --rm \
  -p 8000:8000 \
  -e OPENAI_API_KEY="your-openai-api-key" \
  -e TOKEN_EXCHANGE_URL="http://host.docker.internal:8080/v1/identity/obo-token" \
  -e ACTOR_TOKEN_PATH="/run/secrets/actor-token" \
  -e BYPASS_AUTH_TOKEN_EXCHANGE="false" \
  -v "$(pwd)/.local/actor-token:/run/secrets/actor-token:ro" \
  agentguard-ai-agent
```

If `host.docker.internal` is not available on your platform, point `TOKEN_EXCHANGE_URL` at a reachable host or service name instead.

If you built an architecture-specific image with Buildx, you can also select the runtime platform explicitly:

```bash
docker run --rm --platform linux/amd64 -p 8000:8000 agentguard-ai-agent:amd64
```

## Deploy on Kubernetes

The container is already configured to listen on port `8000`. For Kubernetes, you need:

- an image pushed to a registry that your cluster can pull from
- a Secret generated from an env file that contains the runtime configuration
- a Deployment that mounts that Secret as a `.env` file inside the container

### 1. Create the secret data

Create a namespace if needed:

```bash
kubectl create namespace ai-agent
```

Create an env file such as `.env.k8s`:

```bash
cat > .env.k8s <<'EOF'
OPENAI_API_KEY=your-openai-api-key
LANGCHAIN_MODEL=openai:gpt-5-mini
TOKEN_EXCHANGE_URL=http://identity-service.ai-agent.svc.cluster.local:8080/v1/identity/obo-token
TOKEN_EXCHANGE_TIMEOUT_SECONDS=10
OBO_ROLE_NAME=agent-runtime
BYPASS_AUTH_TOKEN_EXCHANGE=false
HOST=0.0.0.0
PORT=8000
LOG_LEVEL=INFO
EOF
```

Create a Secret from that env file:

```bash
kubectl -n ai-agent create secret generic ai-agent-env \
  --from-file=.env=.env.k8s
```

### 2. Apply the Kubernetes manifests

Update `image:` and `TOKEN_EXCHANGE_URL` before applying:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-agent
  namespace: ai-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ai-agent
  template:
    metadata:
      labels:
        app: ai-agent
    spec:
      containers:
        - name: ai-agent
          image: your-registry/ai-agent:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8000
          env:
            - name: TOKEN_EXCHANGE_URL
              value: http://identity-service.ai-agent.svc.cluster.local:8080/v1/identity/obo-token
          volumeMounts:
            - name: app-env
              mountPath: /app/.env
              subPath: .env
              readOnly: true
      volumes:
        - name: app-env
          secret:
            secretName: ai-agent-env
            items:
              - key: .env
                path: .env
---
apiVersion: v1
kind: Service
metadata:
  name: ai-agent
  namespace: ai-agent
spec:
  selector:
    app: ai-agent
  ports:
    - name: http
      port: 8000
      targetPort: 8000
```

Save the manifest to a file such as `ai-agent-k8s.yaml`, then apply it:

```bash
kubectl apply -f ai-agent-k8s.yaml
```

### 3. Verify the deployment

Check that the pod is running:

```bash
kubectl -n ai-agent get pods
kubectl -n ai-agent get svc
```

If you want to test locally through the cluster service:

```bash
kubectl -n ai-agent port-forward svc/ai-agent 8000:8000
```

Notes:

- The application loads `/app/.env` automatically, so mounting the Secret as that file is enough.
- Kubernetes `env` entries override values loaded from `.env`, so `TOKEN_EXCHANGE_URL` can be set per environment without rebuilding the Secret.
- `kubectl create secret generic --from-file=.env=.env.k8s` stores the file as a single Secret entry named `.env`, which maps cleanly to `/app/.env`.
- The `users_repository.json` file is already baked into the image, so it does not need a separate volume mount.
- Set `TOKEN_EXCHANGE_URL` in the Deployment to the in-cluster DNS name or external URL of your real token exchange service.

## Manual test steps

You need three things for a successful end-to-end test:

- a valid-looking bearer token with a future `exp`
- an actor token file
- a token exchange endpoint that returns an OBO token

### Happy-path request

Send a request that should stream a plain-text answer:

```bash
curl -N \
  -X POST http://localhost:8000/v1/agent/query \
  -H "Authorization: Bearer ${TEST_BEARER_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {
        "role": "user",
        "content": "Find users with first name Ravi"
      }
    ]
  }'
```

### Retrieve cached agent tokens

After a successful `POST /v1/agent/query` call for the same bearer token, fetch the cached OBO token together with the actor token:

```bash
curl http://localhost:8000/v1/agent/tokens \
  -H "Authorization: Bearer ${TEST_BEARER_TOKEN}"
```

Expected result: `200` with a JSON body containing both `obo_token` and `actor_token`.

### Manual negative tests

Missing bearer token:

```bash
curl -X POST http://localhost:8000/v1/agent/query \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"hello"}]}'
```

Expected result: `401` with `Authorization bearer token is required.`

Cache miss on the token lookup endpoint:

```bash
curl http://localhost:8000/v1/agent/tokens \
  -H "Authorization: Bearer ${TEST_BEARER_TOKEN}"
```

Expected result: `404` with `No cached OBO token found for the provided bearer token.`

Expired bearer token:

```bash
curl -X POST http://localhost:8000/v1/agent/query \
  -H "Authorization: Bearer ${EXPIRED_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"hello"}]}'
```

Expected result: `401` with `Bearer token has expired.`
