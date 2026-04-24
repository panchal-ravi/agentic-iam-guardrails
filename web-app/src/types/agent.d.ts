export type ChatRole = 'user' | 'assistant';

export interface ChatMessage {
  role: ChatRole;
  content: string;
}

export interface AgentTokens {
  actor_token: string;
  obo_token: string;
}

export interface AgentReply {
  response: string;
  obo_token?: string;
}
