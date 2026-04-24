'use client';

import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { AgentIcon, UserIcon } from '@/components/icons';
import { TypingIndicator } from '@/components/chat/typing-indicator';

export type MessageRole = 'user' | 'agent';

interface Props {
  role: MessageRole;
  text: string;
  showTyping?: boolean;
}

export function MessageBubble({ role, text, showTyping }: Props) {
  const label = role === 'user' ? 'You' : 'Agent';
  const Icon = role === 'user' ? UserIcon : AgentIcon;
  return (
    <div className={`msg msg--${role}`}>
      <div className="msg__meta">
        <span className="msg__icon">
          <Icon size={16} />
        </span>
        <span className="msg__label">{label}</span>
      </div>
      <div className="msg__text">
        {showTyping ? (
          <TypingIndicator />
        ) : role === 'agent' ? (
          <ReactMarkdown remarkPlugins={[remarkGfm]}>{text}</ReactMarkdown>
        ) : (
          text
        )}
      </div>
    </div>
  );
}
