'use client';

import { useCallback, useRef, useState } from 'react';
import { HeroPanel } from '@/components/chat/hero-panel';
import { MessageLog, type DisplayMessage } from '@/components/chat/message-log';
import { Composer } from '@/components/chat/composer';
import { TokenInspector } from '@/components/inspector/token-inspector';
import { streamAgent } from '@/components/chat/stream-client';
import type { ChatMessage } from '@/types/agent';

interface Props {
  username: string;
}

export function ChatWorkspace({ username }: Props) {
  const [messages, setMessages] = useState<DisplayMessage[]>([]);
  const [pending, setPending] = useState<{ role: 'agent'; text: string; isTyping: boolean } | null>(
    null,
  );
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const [agentTokensRefreshKey, setAgentTokensRefreshKey] = useState(0);
  const composerRef = useRef<HTMLTextAreaElement | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  const focusComposer = useCallback(() => {
    composerRef.current?.focus();
  }, []);

  const handleSend = useCallback(async () => {
    const text = input.trim();
    if (!text || sending) return;

    const history: ChatMessage[] = messages.map((m) => ({
      role: m.role === 'user' ? 'user' : 'assistant',
      content: m.text,
    }));

    setMessages((prev) => [...prev, { role: 'user', text }]);
    setInput('');
    setPending({ role: 'agent', text: '', isTyping: true });
    setSending(true);

    const ac = new AbortController();
    abortRef.current = ac;

    let acc = '';
    await streamAgent(text, history, ac.signal, {
      onChunk: (chunk) => {
        acc += chunk;
        setPending({ role: 'agent', text: acc, isTyping: false });
      },
      onDone: () => {
        setMessages((prev) => [...prev, { role: 'agent', text: acc || '(empty response)' }]);
        setPending(null);
        setSending(false);
        setAgentTokensRefreshKey((n) => n + 1);
      },
      onError: (err) => {
        setMessages((prev) => [
          ...prev,
          { role: 'agent', text: acc ? `${acc}\n\n_${err.message}_` : `_${err.message}_` },
        ]);
        setPending(null);
        setSending(false);
      },
    });
  }, [input, messages, sending]);

  const handleClear = useCallback(() => {
    abortRef.current?.abort();
    abortRef.current = null;
    setMessages([]);
    setPending(null);
    setSending(false);
    setInput('');
  }, []);

  return (
    <div className="workspace-root">
      <div className="workspace-grid">
        <HeroPanel username={username} msgCount={messages.length} onStart={focusComposer} />
        <MessageLog messages={messages} pending={pending} />
        <div className="workspace-grid__composer">
          <Composer
            textareaRef={composerRef}
            value={input}
            onChange={setInput}
            onSend={handleSend}
            onClear={handleClear}
            disabled={sending}
          />
        </div>
        <TokenInspector refreshKey={agentTokensRefreshKey} />
      </div>
    </div>
  );
}
