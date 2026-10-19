import type { E2EConfig } from 'e2e'
import { web } from '@e2e-dev/web'
import { join } from 'node:path'

export default {
  targets: [{
    name: 'preview',
    engine: web({ viewport: { width: 402, height: 874 }, locale: 'en-GB' }),
    app: {
      url: 'http://127.0.0.1:0',
      command: {
        executable: join(process.cwd(), '.runtime/digits-env/bin/python'),
        args: ['-u', 'server/preview.py', '--port', '{port}'],
        env: { PIPCOUNT_HANDWRITING_DIR: join(process.env.PIPCOUNT_STRESS_EVIDENCE ?? join(process.cwd(), '.local-qa'), 'qa-data'), PIPCOUNT_PUBLIC_ORIGIN: 'https://preview.example.invalid' },
        log: '.local-preview-artifacts/server.log',
      },
    },
  }],
  workers: 1,
  retries: 0,
  cache: 'off',
  trace: 'retain-on-failure',
  output: '.local-preview-artifacts',
  actionTimeout: 15000,
  launchTimeout: 90000,
} satisfies E2EConfig
