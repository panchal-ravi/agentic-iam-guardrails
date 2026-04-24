import '@testing-library/jest-dom/vitest';

// Required env for any module that imports @/lib/config
process.env.IBM_VERIFY_CLIENT_ID ||= 'test-client-id';
process.env.IBM_VERIFY_CLIENT_SECRET ||= 'test-client-secret';
process.env.IBM_VERIFY_TENANT_URL ||= 'https://verify.example.com';
process.env.IBM_VERIFY_REDIRECT_URI ||= 'http://localhost:8501/api/auth/callback';
process.env.IBM_VERIFY_SCOPES ||= 'openid profile email Agent.Invoke';
process.env.AI_AGENT_API_URL ||= 'https://agent.example.com';
process.env.LOG_LEVEL ||= 'silent';
process.env.LOG_SERVICE_NAME ||= 'verify-vault-web-app-test';
process.env.LOG_ENVIRONMENT ||= 'test';
process.env.SESSION_PASSWORD ||= 'a'.repeat(48);
