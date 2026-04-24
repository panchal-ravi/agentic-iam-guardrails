import { agent } from '@/lib/config';
import { buildOutboundHeaders } from '@/lib/log/outbound';
import { getLogger } from '@/lib/log/logger';
import type { ChatMessage } from '@/types/agent';
import {
  normalizeAgentTokensPayload,
  normalizeMessageContent,
} from '@/lib/agent/normalize';
import { splitStreamBuffer } from '@/lib/agent/stream';

const log = getLogger('services.agent_api');

function ensureConfigured(): void {
  if (!agent.baseUrl) throw new Error('AI_AGENT_API_URL is not configured.');
}

function describeFetchError(err: unknown, url: string): string {
  const root = extractRootCause(err);
  const rootStr = root ? String(root) : '';
  const msg = String(err);

  if (rootStr.includes('ERR_SSL_PACKET_LENGTH_TOO_LONG') || rootStr.includes('packet length too long')) {
    return (
      `Agent request failed with a TLS protocol error at ${url}. ` +
      `This usually means the URL uses "https://" but the agent service is plain HTTP. ` +
      `Verify AI_AGENT_API_URL in your .env matches the agent's actual scheme (http vs https) and port. ` +
      `Underlying error: ${rootStr}`
    );
  }
  if (rootStr.includes('ECONNREFUSED')) {
    return `Agent service refused the connection at ${url}. Check that AI_AGENT_API_URL points to a running service. Underlying error: ${rootStr}`;
  }
  if (rootStr.includes('ENOTFOUND') || rootStr.includes('EAI_AGAIN')) {
    return `Agent hostname in ${url} could not be resolved. Check AI_AGENT_API_URL. Underlying error: ${rootStr}`;
  }
  if (msg.includes('timed out') || msg.includes('TimeoutError')) {
    return `Agent request timed out against ${url}.`;
  }
  return rootStr ? `Agent request failed at ${url}: ${rootStr}` : `Agent request failed at ${url}: ${msg}`;
}

function extractRootCause(err: unknown): unknown {
  let current: unknown = err;
  const seen = new Set<unknown>();
  while (current && typeof current === 'object' && !seen.has(current)) {
    seen.add(current);
    const cause = (current as { cause?: unknown }).cause;
    if (cause === undefined) break;
    current = cause;
  }
  return current;
}

function buildHeaders(accessToken: string): Record<string, string> {
  return buildOutboundHeaders({
    Authorization: `Bearer ${accessToken}`,
    'Content-Type': 'application/json',
    Accept: 'text/plain, application/json;q=0.9',
  });
}

function buildPayload(message: string, history: ChatMessage[], stream: boolean) {
  return {
    messages: [...history, { role: 'user', content: message }],
    stream,
  };
}

async function extractErrorBody(res: Response): Promise<string> {
  const ct = res.headers.get('Content-Type') ?? '';
  if (ct.toLowerCase().includes('application/json')) {
    try {
      const data = await res.json();
      if (data && typeof data === 'object') {
        const obj = data as Record<string, unknown>;
        for (const key of ['error_description', 'detail', 'message', 'error', 'response']) {
          const v = obj[key];
          if (v) return String(v).trim();
        }
        return JSON.stringify(data);
      }
      return String(data ?? '').trim();
    } catch {
      // fall through
    }
  }
  try {
    return (await res.text()).trim();
  } catch {
    return '';
  }
}

export async function getAgentTokens(
  accessToken: string,
): Promise<{ actor_token: string; obo_token: string }> {
  ensureConfigured();
  log.debug({ url: agent.tokensUrl }, 'Fetching agent tokens');

  let res: Response;
  try {
    res = await fetch(agent.tokensUrl, {
      method: 'GET',
      headers: buildHeaders(accessToken),
      signal: AbortSignal.timeout(30_000),
    });
  } catch (err) {
    const rootCause = extractRootCause(err);
    log.error(
      { err: String(err), rootCause: rootCause ? String(rootCause) : undefined, url: agent.tokensUrl },
      'Agent tokens request failed',
    );
    throw new Error(describeFetchError(err, agent.tokensUrl));
  }

  if (!res.ok) {
    const body = await extractErrorBody(res);
    log.error({ status: res.status }, 'Agent tokens API returned HTTP error');
    throw new Error(`Agent tokens API error ${res.status}${body ? `: ${body}` : ''}`);
  }

  let data: unknown = null;
  try {
    data = await res.clone().json();
  } catch {
    data = null;
  }

  const normalized = normalizeAgentTokensPayload(data);
  if (normalized) return normalized;

  const text = await res.text().catch(() => '');
  const fromText = normalizeAgentTokensPayload(text);
  if (fromText) return fromText;

  throw new Error('Agent tokens API returned an unexpected response shape.');
}

export interface InvokeStreamOptions {
  message: string;
  history: ChatMessage[];
  accessToken: string;
}

export function invokeStream({
  message,
  history,
  accessToken,
}: InvokeStreamOptions): ReadableStream<Uint8Array> {
  ensureConfigured();
  const payload = buildPayload(message, history, true);

  return new ReadableStream<Uint8Array>({
    async start(controller) {
      const encoder = new TextEncoder();

      try {
        const res = await fetch(agent.queryUrl, {
          method: 'POST',
          headers: buildHeaders(accessToken),
          body: JSON.stringify(payload),
          signal: AbortSignal.timeout(310_000),
        });

        if (!res.ok) {
          const body = await extractErrorBody(res);
          throw new Error(`Agent API error ${res.status}${body ? `: ${body}` : ''}`);
        }

        const ct = (res.headers.get('Content-Type') ?? '').toLowerCase();

        if (ct.includes('application/json')) {
          const json = (await res.json()) as Record<string, unknown>;
          const candidate =
            (typeof json.response === 'string' && json.response) ||
            (typeof json.response_text === 'string' && json.response_text) ||
            (typeof json.result === 'string' && json.result) ||
            (typeof json.message === 'string' && json.message) ||
            JSON.stringify(json);
          controller.enqueue(encoder.encode(normalizeMessageContent(String(candidate))));
          controller.close();
          return;
        }

        if (!res.body) {
          controller.close();
          return;
        }

        const decoder = new TextDecoder('utf-8');
        const reader = res.body.getReader();
        let pending = '';
        let streamedChunks = 0;

        try {
          for (;;) {
            const { done, value } = await reader.read();
            if (done) break;
            if (!value || value.length === 0) continue;
            streamedChunks++;
            const chunk = decoder.decode(value, { stream: true });
            pending += chunk;
            const [decodable, leftover] = splitStreamBuffer(pending);
            pending = leftover;
            if (decodable) controller.enqueue(encoder.encode(normalizeMessageContent(decodable)));
          }
          const tail = decoder.decode();
          if (tail) pending += tail;
          if (pending) controller.enqueue(encoder.encode(normalizeMessageContent(pending)));
          controller.close();
        } catch (err) {
          if (streamedChunks > 0) {
            log.warn(
              { err: String(err), streamedChunks },
              'Streaming agent API ended prematurely; preserving received content',
            );
            if (pending) controller.enqueue(encoder.encode(normalizeMessageContent(pending)));
            controller.close();
            return;
          }
          throw err;
        }
      } catch (err) {
        const rootCause = extractRootCause(err);
        log.error(
          { err: String(err), rootCause: rootCause ? String(rootCause) : undefined, url: agent.queryUrl },
          'Agent stream failed',
        );
        controller.error(new Error(describeFetchError(err, agent.queryUrl)));
      }
    },
  });
}
