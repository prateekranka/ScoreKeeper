import { test } from '@e2e-dev/mobile';
import { expect } from 'e2e';

const bundleId = 'com.icequeen.scorekeeper';
const baseArguments = ['-in-memory-store', '-force-light-theme'];

test('fresh install shows onboarding, main paywall, one exit gift, then Home', async ({ screen, device }) => {
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-fresh-install'] });
  const onboarding = screen.getByTestId('onboarding_primary_button');
  await expect(onboarding).toBeVisible();
  for (let page = 0; page < 3; page += 1) await onboarding.tap();
  await expect(screen.getByTestId('paywall_main')).toBeVisible();
  await expect(screen.getByTestId('paywall_primary_button')).toBeVisible();
  await screen.getByTestId('paywall_close_button').tap();
  await expect(screen.getByTestId('paywall_gift')).toBeVisible();
  await screen.getByTestId('paywall_close_button').tap();
  const start = screen.getByTestId('new_game_button');
  await expect(start).toBeVisible();
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

test('active trial grants access and gift launch opens only the gift paywall', async ({ screen, device }) => {
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-trial-active'] });
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
  await expect(screen.getByTestId('paywall_main')).toBeHidden();
  await device.openApp(bundleId, { relaunch: true, launchArguments: [...baseArguments, '-open-gift'] });
  await expect(screen.getByTestId('paywall_gift')).toBeVisible();
  const restore = screen.getByTestId('paywall_restore_button');
  await screen.getByTestId('paywall_legal_scroll').scrollUntilVisible(restore);
  await expect(restore).toBeVisible();
  await screen.getByTestId('paywall_close_button').tap();
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
});

test('largest Dynamic Type keeps paywall primary, close and restore reachable', async ({ screen, device }) => {
  await device.openApp(bundleId, {
    relaunch: true,
    launchArguments: [...baseArguments, '-exit-offer-seen', '-UIPreferredContentSizeCategoryName', 'UICTContentSizeCategoryAccessibilityXXXL'],
  });
  await expect(screen.getByTestId('paywall_main')).toBeVisible();
  await expect(screen.getByTestId('paywall_primary_button')).toBeVisible();
  const lifetime = screen.getByTestId('paywall_plan_lifetime');
  await screen.getByTestId('paywall_content_scroll').scrollUntilVisible(lifetime);
  await lifetime.tap();
  const restore = screen.getByTestId('paywall_restore_button');
  await screen.getByTestId('paywall_legal_scroll').scrollUntilVisible(restore);
  await expect(restore).toBeVisible();
  await expect(screen.getByTestId('paywall_primary_button')).toBeVisible();
  await expect(screen.getByTestId('paywall_close_button')).toBeVisible();
  await screen.getByTestId('paywall_close_button').tap();
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
});
