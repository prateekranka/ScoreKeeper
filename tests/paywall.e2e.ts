import { beforeEach, test } from '@e2e-dev/mobile';
import { expect, type Screen } from 'e2e';
import { captureState } from './handwriting-helpers';
import { assertClearOfIsland } from './handwriting-duo-input';

const bundleId = 'com.icequeen.scorekeeper';
const baseArguments = ['-in-memory-store', '-force-light-theme'];

beforeEach(async ({ device }) => {
  await device.installApp();
});

async function revealRestore(screen: Screen): Promise<void> {
  const scroll = screen.getByTestId('paywall_legal_scroll');
  const restore = screen.getByTestId('paywall_restore_button');
  await scroll.scrollUntilVisible(restore);
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const viewport = await scroll.boundingBox();
    const control = await restore.boundingBox();
    if (!viewport || !control) throw new Error('Paywall legal controls have no current frame');
    const overflow = control.y + control.height - viewport.y - viewport.height + 8;
    if (control.y >= viewport.y && overflow <= 0) return;
    const distance = Math.min(120, Math.max(24, overflow));
    await screen.swipe({
      from: { x: viewport.x + 8, y: viewport.y + viewport.height - 8 },
      to: { x: viewport.x + 8, y: viewport.y + viewport.height - 8 - distance },
      duration: 500,
    });
  }
  throw new Error('Restore remained clipped inside the legal scroll view');
}

test('fresh install shows onboarding, main paywall, one exit gift, then Home', async ({ app, screen, device }) => {
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-fresh-install'] });
  const onboarding = screen.getByTestId('onboarding_primary_button');
  await expect(onboarding).toBeVisible();
  for (let page = 0; page < 3; page += 1) {
    await captureState(app, `paywall-onboarding-${page}`, 'Full-width onboarding in the current device pose');
    await onboarding.tap();
  }
  await expect(screen.getByTestId('paywall_main')).toBeVisible();
  const primary = screen.getByTestId('paywall_primary_button');
  await expect(screen.getByTestId(/^paywall_(primary|retry)_button$/)).toBeEnabled({ timeout: 30_000 });
  if (await primary.isVisible()) {
    const yearly = screen.getByTestId('paywall_plan_yearly');
    const lifetime = screen.getByTestId('paywall_plan_lifetime');
    if (await yearly.isVisible()) await expect(yearly).toBeSelected();
    else {
      await expect(lifetime).toBeSelected();
      await expect(primary).toHaveText('Buy Lifetime');
    }
  } else {
    await expect(screen.getByTestId('paywall_plan_yearly')).toBeHidden();
    await expect(screen.getByTestId('paywall_plan_lifetime')).toBeHidden();
    await expect(screen.getByTestId('paywall_legal_text')).toBeHidden();
  }
  await expect(screen.getByText(/Price unavailable/)).toBeHidden();
  await captureState(app, 'paywall-loaded-main', 'Only loaded products are offered; the first available plan is selected');
  const mainCloseFrame = await screen.getByTestId('paywall_close_button').boundingBox();
  await screen.getByTestId('paywall_close_button').tap();
  await expect(screen.getByTestId('paywall_gift')).toBeVisible();
  await captureState(app, 'paywall-gift-at-presentation', 'Gift chrome immediately after closing the main offer');
  await expect(screen.getByTestId('paywall_main')).not.toBeVisible();
  await expect(screen.getByTestId('paywall_close_button')).toBeVisible();
  await expect(screen.getByTestId(/^paywall_(primary|retry)_button$/)).toBeEnabled({ timeout: 30_000 });
  expect(await screen.getByTestId('paywall_close_button').boundingBox()).toEqual(mainCloseFrame);
  await captureState(app, 'paywall-loaded-gift', 'Full-width gift paywall with purchase or retry');
  await screen.getByTestId('paywall_close_button').tap();
  const start = screen.getByTestId('new_game_button');
  await expect(start).toBeVisible();
  if (await screen.getByTestId('navigation_island').isVisible()) await assertClearOfIsland(screen, start);
  await captureState(app, 'paywall-home-at-rest', 'Home primary action clears the navigation island without scrolling');
  await start.tap();
  await expect(screen.getByTestId('paywall_main')).toBeVisible();
  await screen.getByTestId('paywall_close_button').tap();
  await expect(start).toBeVisible();
  await expect(screen.getByTestId('paywall_gift')).toBeHidden();
});

test('converted user can start a game without a paywall', async ({ screen, device }) => {
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-unlock-pro'] });
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
  await expect(screen.getByTestId('paywall_main')).toBeHidden();
  await screen.getByTestId('new_game_button').tap();
  const tile = screen.getByTestId('game_tile_generic');
  await screen.scrollUntilVisible(tile);
  await expect(tile).toBeVisible();
  await expect(screen.getByTestId('paywall_main')).toBeHidden();
});

test('grandfathered user keeps remaining starts and exhausted user keeps Home', async ({ screen, device }) => {
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-grandfathered', '24'] });
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
  await screen.getByTestId('new_game_button').tap();
  await screen.scrollUntilVisible(screen.getByTestId('game_tile_generic'));
  await expect(screen.getByTestId('game_tile_generic')).toBeVisible();
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-grandfathered', '25', '-exit-offer-seen'] });
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
  await screen.getByTestId('new_game_button').tap();
  await expect(screen.getByTestId('paywall_main')).toBeVisible();
  await screen.getByTestId('paywall_close_button').tap();
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
});

test('active trial grants access and gift launch opens only the gift paywall', async ({ app, screen, device }) => {
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-trial-active'] });
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
  await expect(screen.getByTestId('paywall_main')).toBeHidden();
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-open-gift'] });
  await expect(screen.getByTestId('paywall_gift')).toBeVisible();
  const restore = screen.getByTestId('paywall_restore_button');
  await revealRestore(screen);
  await expect(restore).toBeVisible();
  await expect(screen.getByTestId('paywall_close_button')).toBeVisible();
  console.log('Gift close frame', await screen.getByTestId('paywall_close_button').boundingBox());
  await captureState(app, 'paywall-gift-direct-launch', 'Gift paywall opened directly in the current pose');
  await screen.getByTestId('paywall_close_button').tap();
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
});

test('largest Dynamic Type keeps paywall primary, close and restore reachable', async ({ app, screen, device }) => {
  await device.openApp(bundleId, {
    relaunch: true,
    launchArguments: [...baseArguments, '-exit-offer-seen', '-UIPreferredContentSizeCategoryName', 'UICTContentSizeCategoryAccessibilityXXXL'],
  });
  await expect(screen.getByTestId('paywall_main')).toBeVisible();
  const primary = screen.getByTestId('paywall_primary_button');
  const retry = screen.getByTestId('paywall_retry_button');
  await expect.poll(async () => await primary.isVisible() || await retry.isVisible()).toBe(true);
  const lifetime = screen.getByTestId('paywall_plan_lifetime');
  if (await primary.isVisible()) {
    await screen.getByTestId('paywall_content_scroll').scrollUntilVisible(lifetime);
    await lifetime.tap();
  }
  const restore = screen.getByTestId('paywall_restore_button');
  await revealRestore(screen);
  await expect(restore).toBeVisible();
  await expect.poll(async () => await primary.isVisible() || await retry.isVisible()).toBe(true);
  await expect(screen.getByTestId('paywall_close_button')).toBeVisible();
  await captureState(app, 'paywall-largest-text', 'Primary action, Close and Restore remain reachable at largest Dynamic Type');
  await screen.getByTestId('paywall_close_button').tap();
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
});
