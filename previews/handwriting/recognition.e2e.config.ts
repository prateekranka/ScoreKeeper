import type { E2EConfig } from 'e2e'

export default {
  targets: [{ name: 'local', platform: 'local' }],
  workers: 1,
  retries: 0,
  cache: 'off',
  trace: 'off',
  output: '.local-recognition-artifacts',
} satisfies E2EConfig
