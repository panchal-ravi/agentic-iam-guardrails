import { z } from 'zod';

const schema = z.object({
  IBM_VERIFY_CLIENT_ID: z.string().min(1, 'IBM_VERIFY_CLIENT_ID is required'),
  IBM_VERIFY_CLIENT_SECRET: z.string().min(1, 'IBM_VERIFY_CLIENT_SECRET is required'),
  IBM_VERIFY_TENANT_URL: z
    .string()
    .url('IBM_VERIFY_TENANT_URL must be a valid URL')
    .transform((s) => s.replace(/\/$/, '')),
  IBM_VERIFY_REDIRECT_URI: z.string().url('IBM_VERIFY_REDIRECT_URI must be a valid URL'),
  IBM_VERIFY_SCOPES: z.string().default('openid profile email Agent.Invoke'),
  AI_AGENT_API_URL: z
    .string()
    .default('')
    .transform((s) => s.replace(/\/$/, '')),
  LOG_LEVEL: z
    .string()
    .default('info')
    .transform((s) => s.toLowerCase()),
  LOG_SERVICE_NAME: z.string().default('verify-vault-web-app'),
  LOG_ENVIRONMENT: z.string().default('development'),
  SESSION_PASSWORD: z
    .string()
    .min(32, 'SESSION_PASSWORD must be at least 32 characters'),
});

function parseConfig() {
  // During `next build`, route modules are imported to collect page data before
  // deploy-time env vars exist. Substitute placeholders so validation defers to
  // the runtime server process, which re-evaluates this file with real env.
  if (process.env.NEXT_PHASE === 'phase-production-build') {
    return schema.parse({
      ...process.env,
      IBM_VERIFY_CLIENT_ID: process.env.IBM_VERIFY_CLIENT_ID || 'build-placeholder',
      IBM_VERIFY_CLIENT_SECRET: process.env.IBM_VERIFY_CLIENT_SECRET || 'build-placeholder',
      IBM_VERIFY_TENANT_URL: process.env.IBM_VERIFY_TENANT_URL || 'https://build.placeholder',
      IBM_VERIFY_REDIRECT_URI:
        process.env.IBM_VERIFY_REDIRECT_URI || 'https://build.placeholder/callback',
      SESSION_PASSWORD: process.env.SESSION_PASSWORD || 'x'.repeat(32),
    });
  }
  const result = schema.safeParse(process.env);
  if (!result.success) {
    const issues = result.error.issues
      .map((i) => `  - ${i.path.join('.')}: ${i.message}`)
      .join('\n');
    throw new Error(`Invalid environment configuration:\n${issues}`);
  }
  return result.data;
}

export const config = parseConfig();

export const oidc = {
  base: `${config.IBM_VERIFY_TENANT_URL}/oidc/endpoint/default`,
  authorizeUrl: `${config.IBM_VERIFY_TENANT_URL}/oidc/endpoint/default/authorize`,
  tokenUrl: `${config.IBM_VERIFY_TENANT_URL}/oidc/endpoint/default/token`,
  jwksUrl: `${config.IBM_VERIFY_TENANT_URL}/oidc/endpoint/default/jwks`,
  logoutUrl: `${config.IBM_VERIFY_TENANT_URL}/oidc/endpoint/default/logout`,
} as const;

export const agent = {
  baseUrl: config.AI_AGENT_API_URL,
  queryUrl: config.AI_AGENT_API_URL ? `${config.AI_AGENT_API_URL}/v1/agent/query` : '',
  tokensUrl: config.AI_AGENT_API_URL ? `${config.AI_AGENT_API_URL}/v1/agent/tokens` : '',
} as const;
