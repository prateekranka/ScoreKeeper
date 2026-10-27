import { beforeEach, test } from '@e2e-dev/mobile';
import { expect, type Locator, type Screen } from 'e2e';
import { captureState, tapNativeControl, tapTab } from './handwriting-helpers';
import { assertClearOfIsland } from './handwriting-duo-input';

const bundleId = 'com.icequeen.scorekeeper';
const baseArguments = ['-in-memory-store', '-force-light-theme'];

beforeEach(async ({ device }) => {
  await device.installApp();
});

async function revealContent(screen: Screen, restore: Locator): Promise<void> {
  const scroll = screen.getByTestId('paywall_content_scroll');
  await scroll.scrollUntilVisible(restore);
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const viewport = await scroll.boundingBox();
    const control = await restore.boundingBox();
    if (!viewport || !control) throw new Error('Paywall legal controls have no current frame');
    const overflow = control.y + control.height - viewport.y - viewport.height + 8;
    const topOverflow = viewport.y + 8 - control.y;
    if (topOverflow <= 0 && overflow <= 0) return;
    const distance = Math.min(120, Math.max(24, topOverflow > 0 ? topOverflow : overflow));
    const startY = topOverflow > 0 ? viewport.y + 16 : viewport.y + viewport.height - 16;
    await screen.swipe({
      from: { x: viewport.x + 8, y: startY },
      to: { x: viewport.x + 8, y: startY + (topOverflow > 0 ? distance : -distance) },
      duration: 500,
    });
  }
  throw new Error('Paywall content remained clipped inside the scroll viewport');
}

async function revealRestore(screen: Screen): Promise<void> {
  await revealContent(screen, screen.getByTestId('paywall_restore_button'));
}

test('fresh install shows onboarding, main paywall, one exit gift, then Home', async ({ app, screen, device }) => {
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-fresh-install'] });
  const onboarding = screen.getByTestId('onboarding_primary_button');
  await expect(onboarding).toBeVisible();
  for (let page = 0; page < 3; page += 1) {
    await captureState(app, `paywall-onboarding-${page}`, 'Full-width onboarding in the current device pose');
    await tapNativeControl(screen, onboarding);
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
  await tapNativeControl(screen, screen.getByTestId('paywall_close_button'));
  await expect(screen.getByTestId('paywall_gift')).toBeVisible();
  await captureState(app, 'paywall-gift-at-presentation', 'Gift chrome immediately after closing the main offer');
  await expect(screen.getByTestId('paywall_main')).not.toBeVisible();
  await expect(screen.getByTestId('paywall_close_button')).toBeVisible();
  await expect(screen.getByTestId(/^paywall_(primary|retry)_button$/)).toBeEnabled({ timeout: 30_000 });
  expect(await screen.getByTestId('paywall_close_button').boundingBox()).toEqual(mainCloseFrame);
  if (await screen.getByTestId('paywall_retry_button').isVisible()) {
    await expect(screen.getByText(/unavailable right now|Unable to load PipCount Pro right now/)).toBeVisible();
  }
  await captureState(app, 'paywall-loaded-gift', 'Full-width gift paywall with purchase or retry');
  await tapNativeControl(screen, screen.getByTestId('paywall_close_button'));
  const start = screen.getByTestId('new_game_button');
  await expect(start).toBeVisible();
  if (await screen.getByTestId('navigation_island').isVisible()) await assertClearOfIsland(screen, start);
  await captureState(app, 'paywall-home-at-rest', 'Home primary action clears the navigation island without scrolling');
  await tapNativeControl(screen, start);
  await expect(screen.getByTestId('paywall_main')).toBeVisible();
  await tapNativeControl(screen, screen.getByTestId('paywall_close_button'));
  await expect(start).toBeVisible();
  await expect(screen.getByTestId('paywall_gift')).toBeHidden();
  await tapTab(screen, 'More');
  await expect(screen.getByTestId('theme_light_button')).toBeVisible();
  await expect(screen.getByTestId('more_upgrade_button')).toBeVisible();
  await expect(screen.getByText(/^\d+ free games? left$/)).toBeHidden();
  await captureState(app, 'paywall-fresh-more', 'Fresh users see the upgrade offer without any free-game count');
  await tapNativeControl(screen, screen.getByTestId('theme_dark_button'));
  await expect(screen.getByTestId('more_upgrade_button')).toBeVisible();
  await expect(screen.getByText(/^\d+ free games? left$/)).toBeHidden();
  await captureState(app, 'paywall-fresh-more-dark', 'Fresh users see no free-game count in dark appearance');
});

test('converted user can start a game without a paywall', async ({ app, screen, device }) => {
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-unlock-pro'] });
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
  await expect(screen.getByTestId('paywall_main')).toBeHidden();
  await tapTab(screen, 'More');
  await expect(screen.getByTestId('theme_light_button')).toBeVisible();
  await expect(screen.getByTestId('more_upgrade_button')).toBeHidden();
  await expect(screen.getByTestId('pro_unlocked_status')).toBeHidden();
  await expect(screen.getByText('PipCount Pro', { exact: true })).toBeHidden();
  await expect(screen.getByText(/^\d+ free games? left$/)).toBeHidden();
  await captureState(app, 'paywall-pro-more', 'Legacy Pro users see no upgrade or subscription-management row');
  await tapTab(screen, 'Home');
  await tapNativeControl(screen, screen.getByTestId('new_game_button'));
  const tile = screen.getByTestId('game_tile_generic');
  await screen.scrollUntilVisible(tile);
  await expect(tile).toBeVisible();
  await expect(screen.getByTestId('paywall_main')).toBeHidden();
});

test('grandfathered user keeps remaining starts and exhausted user keeps Home', async ({ screen, device }) => {
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-grandfathered', '24'] });
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
  await tapNativeControl(screen, screen.getByTestId('new_game_button'));
  await screen.scrollUntilVisible(screen.getByTestId('game_tile_generic'));
  await expect(screen.getByTestId('game_tile_generic')).toBeVisible();
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-grandfathered', '25', '-exit-offer-seen'] });
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
  await tapNativeControl(screen, screen.getByTestId('new_game_button'));
  await expect(screen.getByTestId('paywall_main')).toBeVisible();
  await tapNativeControl(screen, screen.getByTestId('paywall_close_button'));
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
});

test('More shows free-game counts only at the grandfathered three-game threshold', async ({ app, screen, device }) => {
  for (const started of [21, 22, 24, 25]) {
    await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-grandfathered', String(started)] });
    await expect(screen.getByTestId('new_game_button')).toBeVisible();
    await tapTab(screen, 'More');
    await expect(screen.getByTestId('theme_light_button')).toBeVisible();
    await expect(screen.getByTestId('more_upgrade_button')).toBeVisible();
    const count = screen.getByText(/^\d+ free games? left$/);
    const remaining = 25 - started;
    if (remaining <= 3) {
      await expect(count).toHaveText(`${remaining} free ${remaining === 1 ? 'game' : 'games'} left`);
    } else {
      await expect(count).toBeHidden();
    }
    await captureState(app, `paywall-grandfathered-more-${remaining}`, 'Only grandfathered users with three or fewer free games see a count');
  }
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-grandfathered', '25', '-unlock-pro'] });
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
  await tapTab(screen, 'More');
  await expect(screen.getByTestId('theme_light_button')).toBeVisible();
  await expect(screen.getByTestId('more_upgrade_button')).toBeHidden();
  await expect(screen.getByText(/^\d+ free games? left$/)).toBeHidden();
});

test('active trial grants access and gift launch opens only the gift paywall', async ({ app, screen, device }) => {
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-trial-active'] });
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
  await expect(screen.getByTestId('paywall_main')).toBeHidden();
  await tapTab(screen, 'More');
  await expect(screen.getByTestId('theme_light_button')).toBeVisible();
  await expect(screen.getByTestId('more_upgrade_button')).toBeHidden();
  await expect(screen.getByText('PipCount Pro', { exact: true })).toBeHidden();
  await expect(screen.getByText(/^\d+ free games? left$/)).toBeHidden();
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-open-gift'] });
  await expect(screen.getByTestId('paywall_gift')).toBeVisible();
  const restore = screen.getByTestId('paywall_restore_button');
  await revealRestore(screen);
  await expect(restore).toBeVisible();
  await expect(screen.getByTestId('paywall_close_button')).toBeVisible();
  console.log('Gift close frame', await screen.getByTestId('paywall_close_button').boundingBox());
  await captureState(app, 'paywall-gift-direct-launch', 'Gift paywall opened directly in the current pose');
  await tapNativeControl(screen, screen.getByTestId('paywall_close_button'));
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
  const benefit = screen.getByText('Stats & history', { exact: true });
  const scroll = screen.getByTestId('paywall_content_scroll');
  await revealContent(screen, benefit);
  const benefitFrame = await benefit.boundingBox();
  const viewport = await scroll.boundingBox();
  if (!benefitFrame || !viewport) throw new Error('Paywall benefit has no current frame');
  expect(benefitFrame.x + benefitFrame.width).toBeLessThanOrEqual(viewport.x + viewport.width);
  expect(benefitFrame.y).toBeGreaterThanOrEqual(viewport.y);
  expect(benefitFrame.y + benefitFrame.height).toBeLessThanOrEqual(viewport.y + viewport.height);
  await captureState(app, 'paywall-largest-benefits', 'Wrapped benefits remain inside the scroll viewport below the status capsule');
  const lifetime = screen.getByTestId('paywall_plan_lifetime');
  await scroll.scrollUntilVisible(screen.getByTestId(/^paywall_(plan_lifetime|retry_button)$/));
  if (await lifetime.isVisible()) {
    await scroll.scrollUntilVisible(lifetime);
    await tapNativeControl(screen, lifetime);
  }
  const restore = screen.getByTestId('paywall_restore_button');
  await revealRestore(screen);
  await expect(restore).toBeVisible();
  await expect.poll(async () => await primary.isVisible() || await retry.isVisible()).toBe(true);
  if (await primary.isVisible()) {
    await revealContent(screen, primary);
    const action = await primary.boundingBox();
    const legal = await screen.getByTestId('paywall_legal_text').boundingBox();
    if (!action || !legal) throw new Error('Purchase action or legal text has no current frame');
    expect(action.y).toBeGreaterThanOrEqual(viewport.y);
    expect(action.y + action.height).toBeLessThanOrEqual(legal.y);
    expect(legal.y + legal.height).toBeLessThanOrEqual((await restore.boundingBox())!.y);
  }
  await expect(screen.getByTestId('paywall_close_button')).toBeVisible();
  await captureState(app, 'paywall-largest-text', 'Primary action, Close and Restore remain reachable at largest Dynamic Type');
  await tapNativeControl(screen, screen.getByTestId('paywall_close_button'));
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
});
