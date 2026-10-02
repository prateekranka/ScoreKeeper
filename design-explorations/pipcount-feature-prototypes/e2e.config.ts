import type { E2EConfig } from 'e2e';
import { web } from '@e2e-dev/web';

export default {
  tests: 'tests/**/*.e2e.ts',
  workers: 1,
  retries: 0,
  cache: 'off',
  trace: 'off',
  targets: [{
    name: 'bauhaus',
    engine: web({ viewport: { width: 1640, height: 800 } }),
    app: {
      url: process.env.APP_URL ?? 'http://127.0.0.1:8147',
    },
  }],
} satisfies E2EConfig;
