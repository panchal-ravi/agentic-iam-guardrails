declare namespace NodeJS {
  interface ProcessEnv {
    IBM_VERIFY_CLIENT_ID: string;
    IBM_VERIFY_CLIENT_SECRET: string;
    IBM_VERIFY_TENANT_URL: string;
    IBM_VERIFY_REDIRECT_URI: string;
    IBM_VERIFY_SCOPES?: string;
    AI_AGENT_API_URL?: string;
    LOG_LEVEL?: string;
    LOG_SERVICE_NAME?: string;
    LOG_ENVIRONMENT?: string;
    SESSION_PASSWORD: string;
    NODE_ENV: 'development' | 'production' | 'test';
  }
}
