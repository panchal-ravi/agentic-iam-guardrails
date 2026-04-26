import { describe, it, expect } from 'vitest';
import {
  decodeEscapedPlaintext,
  normalizeMessageContent,
  normalizeAgentTokensPayload,
} from '@/lib/agent/normalize';

describe('decodeEscapedPlaintext', () => {
  it('returns content unchanged when no escape markers', () => {
    expect(decodeEscapedPlaintext('hello world')).toBe('hello world');
  });

  it('decodes escaped multiline newlines', () => {
    expect(decodeEscapedPlaintext('line one\\nline two')).toBe('line one\nline two');
  });

  it('decodes wrapped + escaped-quote payload', () => {
    expect(decodeEscapedPlaintext('"he said \\"hi\\""')).toBe('he said "hi"');
  });

  it('unwraps a JSON-style wrapped string and decodes content', () => {
    expect(decodeEscapedPlaintext('"hello\\nworld"')).toBe('hello\nworld');
  });

  it('preserves leading/trailing whitespace', () => {
    expect(decodeEscapedPlaintext('  hello\\nworld  ')).toBe('  hello\nworld  ');
  });
});

describe('normalizeMessageContent', () => {
  it('returns plain text unchanged', () => {
    expect(normalizeMessageContent('plain reply')).toBe('plain reply');
  });

  it('extracts response_text from JSON envelope', () => {
    expect(normalizeMessageContent('{"response_text": "hi there"}')).toBe('hi there');
  });

  it('extracts response from JSON envelope', () => {
    expect(normalizeMessageContent('{"response": "hi response"}')).toBe('hi response');
  });

  it('extracts result from JSON envelope', () => {
    expect(normalizeMessageContent('{"result": "hi result"}')).toBe('hi result');
  });

  it('extracts message from JSON envelope', () => {
    expect(normalizeMessageContent('{"message": "hi message"}')).toBe('hi message');
  });

  it('falls back to escaped-plaintext decode when JSON parse fails', () => {
    expect(normalizeMessageContent('{not json\\nbroken')).toBe('{not json\nbroken');
  });

  it('handles JSON with escaped multiline value', () => {
    expect(normalizeMessageContent('{"response_text": "a\\nb"}')).toBe('a\nb');
  });
});

describe('normalizeAgentTokensPayload', () => {
  it('reads direct shape', () => {
    expect(normalizeAgentTokensPayload({ actor_token: 'A', obo_token: 'O' })).toEqual({
      actor_token: 'A',
      obo_token: 'O',
    });
  });

  it('coerces missing OBO token to null and empty actor to empty string', () => {
    expect(normalizeAgentTokensPayload({ actor_token: 'A' })).toEqual({
      actor_token: 'A',
      obo_token: null,
    });
    expect(normalizeAgentTokensPayload({ actor_token: 'A', obo_token: null })).toEqual({
      actor_token: 'A',
      obo_token: null,
    });
  });

  it('reads nested under data', () => {
    expect(
      normalizeAgentTokensPayload({ data: { actor_token: 'A', obo_token: 'O' } }),
    ).toEqual({ actor_token: 'A', obo_token: 'O' });
  });

  it('reads nested under result/response/payload/body', () => {
    for (const key of ['result', 'response', 'payload', 'body']) {
      expect(
        normalizeAgentTokensPayload({ [key]: { actor_token: 'A', obo_token: 'O' } }),
      ).toEqual({ actor_token: 'A', obo_token: 'O' });
    }
  });

  it('parses stringified JSON', () => {
    expect(normalizeAgentTokensPayload('{"actor_token":"A","obo_token":"O"}')).toEqual({
      actor_token: 'A',
      obo_token: 'O',
    });
  });

  it('returns null for unknown shapes', () => {
    expect(normalizeAgentTokensPayload(null)).toBeNull();
    expect(normalizeAgentTokensPayload(123)).toBeNull();
    expect(normalizeAgentTokensPayload({})).toBeNull();
    expect(normalizeAgentTokensPayload({ foo: 'bar' })).toBeNull();
  });
});
