import { test } from '@e2e-dev/mobile';
import { expect } from 'e2e';
import { captureState, scrollControlAboveTabDock } from './handwriting-helpers';

test('paywall close, restore and the start gate survive portrait and landscape', async ({ app, screen, device }) => {
  await device.installApp();
  await device.openApp('com.icequeen.scorekeeper', {
    relaunch: true,
    launchArguments: ['-in-memory-store', '-force-light-theme', '-exit-offer-seen'],
  });
  try {
    for (const orientation of ['portrait', 'landscape-left'] as const) {
      await device.setOrientation(orientation);
      await expect(screen.getByTestId('paywall_main')).toBeVisible();
      const close = screen.getByTestId('paywall_close_button');
      await expect(close).toBeVisible();
      const frame = await close.boundingBox();
      if (!frame) throw new Error('Paywall Close has no frame');
      expect(frame.width).toBeGreaterThanOrEqual(44);
      expect(frame.height).toBeGreaterThanOrEqual(44);
      const restore = screen.getByTestId('paywall_restore_button');
      await screen.getByTestId('paywall_content_scroll').scrollUntilVisible(restore);
      await expect(restore).toBeVisible();
      await expect(close).toBeVisible();
      await expect.poll(async () => {
        const viewport = await screen.getByTestId('paywall_main').boundingBox();
        if (!viewport || viewport.width <= 0 || viewport.height <= 0) return false;
        return orientation === 'portrait'
          ? viewport.height > viewport.width
          : viewport.width > viewport.height;
      }).toBe(true);
      await captureState(app, `reconcile-paywall-${orientation}`, 'The measured app frame has the requested orientation and paywall controls remain reachable');
      await close.tap();
      const start = screen.getByTestId('new_game_button');
      await scrollControlAboveTabDock(screen, start, 'tab_home', 'Start new game after rotation');
      await expect(start).toBeVisible();
      await start.tap();
      await expect(screen.getByTestId('paywall_main')).toBeVisible();
    }
  } finally {
    await device.setOrientation('portrait');
  }
});
