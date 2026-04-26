declare namespace NodeJS {
  interface ProcessEnv {
    IBM_VERIFY_CLIENT_ID: string;
    IBM_VERIFY_CLIENT_SECRET: string;
    IBM_VERIFY_TENANT_URL: string;
    IBM_VERIFY_REDIRECT_URI: string;
    IBM_VERIFY_SCOPES?: string;
    AI_AGENT_API_URL?: string;
    AI_AGENT_DNS_RETRY_ATTEMPTS?: string;
    AI_AGENT_DNS_RETRY_BASE_DELAY_MS?: string;
    AI_AGENT_DNS_RETRY_MAX_DELAY_MS?: string;
    LOG_LEVEL?: string;
    LOG_SERVICE_NAME?: string;
    LOG_ENVIRONMENT?: string;
    SESSION_PASSWORD: string;
    NODE_ENV: 'development' | 'production' | 'test';
  }
}
