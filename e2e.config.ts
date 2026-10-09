import type { E2EConfig } from 'e2e';
import { mobile } from '@e2e-dev/mobile';

// Pin a booted simulator. This suite never erases an app or device.
export default {
  tests: ['tests/native-glass-*.e2e.ts'],
  targets: [{
    name: 'ios',
    engine: mobile({
      platform: 'ios',
      device: process.env.PIPCOUNT_DEVICE ?? 'E00E0899-9FCB-49BE-9D05-E469A89371EA',
      session: process.env.PIPCOUNT_SESSION ?? 'pipcount-release',
      transition: 1200,
      settle: 250,
    }),
    app: {
      bundleId: 'com.icequeen.scorekeeper',
      appPath: process.env.PIPCOUNT_APP ?? '.build/native-glass-final15/Build/Products/Debug-iphonesimulator/ScoreKeeper.app',
      launchArguments: ['-in-memory-store', '-force-light-theme'],
    },
  }],
  workers: 1,
  retries: 0,
  timeout: 240_000,
  launchTimeout: 120_000,
  actionTimeout: 45_000,
  assertionTimeout: 10_000,
  cleanupTimeout: 60_000,
  cache: 'off',
  trace: 'off',
} satisfies E2EConfig;
