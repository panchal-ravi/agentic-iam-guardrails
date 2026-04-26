'use client';

import { useEffect, useState } from 'react';
import { ChevronRightIcon } from '@/components/icons';
import { TokenClaims } from '@/components/inspector/token-claims';
import { decodeJwtPayload } from '@/lib/jwt-decode';

type TokenId = 'subject' | 'actor' | 'obo';

interface SubjectData {
  token: string;
  claims: Record<string, unknown>;
}

interface AgentTokenData {
  actor_token: string;
  obo_token: string | null;
}

interface Props {
  refreshKey: number;
}

export function TokenInspector({ refreshKey }: Props) {
  const [openId, setOpenId] = useState<TokenId | null>('subject');
  const [subject, setSubject] = useState<SubjectData | null>(null);
  const [subjectError, setSubjectError] = useState<string | null>(null);
  const [agentTokens, setAgentTokens] = useState<AgentTokenData | null>(null);
  const [agentTokensError, setAgentTokensError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const res = await fetch('/api/auth/claims');
        if (!res.ok) throw new Error(`status ${res.status}`);
        const data = (await res.json()) as SubjectData;
        if (!cancelled) {
          setSubject(data);
          setSubjectError(null);
        }
      } catch (err) {
        if (!cancelled) setSubjectError(`Failed to load subject token: ${String(err)}`);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (refreshKey === 0) return;
    let cancelled = false;
    async function load() {
      try {
        const res = await fetch('/api/agent/tokens');
        if (!res.ok) {
          let detail = '';
          try {
            const data = await res.json();
            detail = typeof data.detail === 'string' ? data.detail : JSON.stringify(data);
          } catch {
            detail = await res.text().catch(() => '');
          }
          throw new Error(`status ${res.status}: ${detail || 'agent tokens unavailable'}`);
        }
        const data = (await res.json()) as AgentTokenData;
        if (!cancelled) {
          setAgentTokens(data);
          setAgentTokensError(null);
        }
      } catch (err) {
        if (!cancelled) setAgentTokensError(String(err));
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [refreshKey]);

  const actorClaims = agentTokens?.actor_token ? decodeJwtPayload(agentTokens.actor_token) : null;
  const oboClaims = agentTokens?.obo_token ? decodeJwtPayload(agentTokens.obo_token) : null;
  // Distinguish "no response yet" (loading / error) from "broker returned no
  // OBO yet" (200 with obo_token=null) — only the latter renders the
  // explicit "Not available" hint in the OBO accordion.
  const oboUnavailable =
    !agentTokensError && agentTokens != null && !agentTokens.obo_token;

  const items: Array<{
    id: TokenId;
    title: string;
    subtitle: string;
    body: React.ReactNode;
  }> = [
    {
      id: 'subject',
      title: 'Subject token',
      subtitle: 'OAuth 2.0 JWT Access Token',
      body: subjectError ? (
        <p className="inspector__error">{subjectError}</p>
      ) : (
        <TokenClaims claims={subject?.claims ?? null} rawToken={subject?.token} showRawToken />
      ),
    },
    {
      id: 'actor',
      title: 'Agent — actor token',
      subtitle: 'act.sub · delegated',
      body: agentTokensError ? (
        <p className="inspector__error">{agentTokensError}</p>
      ) : (
        <TokenClaims claims={actorClaims} rawToken={agentTokens?.actor_token} showRawToken />
      ),
    },
    {
      id: 'obo',
      title: 'Agent — OBO token',
      subtitle: 'on-behalf-of exchange',
      body: agentTokensError ? (
        <p className="inspector__error">{agentTokensError}</p>
      ) : oboUnavailable ? (
        <p className="inspector__placeholder">Not available</p>
      ) : (
        <TokenClaims
          claims={oboClaims}
          rawToken={agentTokens?.obo_token ?? undefined}
          showRawToken
        />
      ),
    },
  ];

  return (
    <aside className="inspector" aria-label="Identity inspector">
      <div className="eyebrow">Identity inspector</div>
      <h2 className="inspector__title">Token context</h2>
      <p className="inspector__sub">
        Inspect the subject token and the delegated agent tokens without leaving the workspace.
      </p>
      <ul className="inspector__list">
        {items.map((t) => {
          const open = openId === t.id;
          return (
            <li key={t.id} className="inspector__item">
              <button
                type="button"
                className="inspector__heading"
                onClick={() => setOpenId(open ? null : t.id)}
                aria-expanded={open}
              >
                <span className={`inspector__caret ${open ? 'is-open' : ''}`}>
                  <ChevronRightIcon size={16} />
                </span>
                <span className="inspector__heading-title">{t.title}</span>
              </button>
              <div
                className={`inspector__content ${open ? 'is-open' : ''}`}
                aria-hidden={!open}
              >
                <div className="inspector__inner">
                  <div className="inspector__subtitle">{t.subtitle}</div>
                  {t.body}
                </div>
              </div>
            </li>
          );
        })}
      </ul>
    </aside>
  );
}
