import type { E2EConfig } from 'e2e'
import { web } from '@e2e-dev/web'

export default {
  targets: [{
    name: 'preview',
    engine: web({ viewport: { width: Number(process.env.PIPCOUNT_PREVIEW_WIDTH ?? 402), height: Number(process.env.PIPCOUNT_PREVIEW_HEIGHT ?? 874) }, locale: 'en-GB' }),
    app: { url: process.env.PIPCOUNT_PREVIEW_URL ?? 'http://127.0.0.1:4179' },
  }],
  workers: 1,
  retries: 0,
  cache: 'off',
  trace: 'off',
  output: '.capture-artifacts',
  actionTimeout: 15000,
  launchTimeout: 90000,
} satisfies E2EConfig
