import { test } from '@e2e-dev/mobile';
import { expect, type Locator, type Screen } from 'e2e';
import { captureState, finishOnboarding, tapTab } from './handwriting-helpers';
import { assertClearOfIsland } from './handwriting-duo-input';
import { finishCurrentGame, startGameFromHome, openRoundDeck, scoreManualRound } from './native-glass-flows';

const bundle = 'com.icequeen.scorekeeper';

async function aboveIsland(screen: Screen, control: Locator): Promise<void> {
  await assertClearOfIsland(screen, control);
  const frame = await control.boundingBox();
  const island = await screen.getByTestId('navigation_island').boundingBox();
  if (!frame || !island) throw new Error('Content or island has no current frame');
  expect(frame.y + frame.height).toBeLessThanOrEqual(island.y);
}

async function revealSheetControl(screen: Screen, control: Locator): Promise<void> {
  const scroll = screen.getByTestId('scoring_tool_content_scroll');
  await scroll.scrollUntilVisible(control);
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const viewport = await scroll.boundingBox();
    const frame = await control.boundingBox();
    if (!viewport || !frame) throw new Error('Sheet content has no current frame');
    const overflow = frame.y + frame.height - viewport.y - viewport.height + 8;
    if (frame.y >= viewport.y && overflow <= 0) return;
    const distance = Math.min(viewport.height / 2, Math.max(24, overflow));
    await screen.swipe({ from: { x: viewport.x + 8, y: viewport.y + viewport.height - 8 }, to: { x: viewport.x + 8, y: viewport.y + viewport.height - 8 - distance } });
  }
  throw new Error('Sheet content remains clipped');
}

for (const appearance of ['light', 'dark'] as const) {
  test(`Duo at-rest rows, timer and results stay clear in ${appearance}`, { timeout: 420_000 }, async ({ app, screen, device }) => {
    await device.installApp();
    await device.setAppearance(appearance);
    try {
      await device.openApp(bundle, { relaunch: true, launchArguments: ['-in-memory-store', '-unlock-pro', '-themeMode', 'system', '-hasSeenScoreDeckTutorial', 'YES', '-UIPreferredContentSizeCategoryName', 'UICTContentSizeCategoryL'] });
      await finishOnboarding(app, screen);
      await expect(screen.getByTestId('new_game_button')).toBeVisible();
      await captureState(app, `review-${appearance}-home-empty`, 'Home before a game in the open Duo rail layout');
      const names = ['Maya', 'Leo'] as const;
      await startGameFromHome(app, screen, 'generic', names, `review-${appearance}-game`);
      await openRoundDeck(app, screen, names, `review-${appearance}-deck`);
      await scoreManualRound(app, screen, names, { maya: 7, leo: 9 }, `review-${appearance}-round`);
      await expect(screen.getByTestId('running_total_maya')).toHaveText('7');
      await expect(screen.getByTestId('running_total_leo')).toHaveText('9');
      await aboveIsland(screen, screen.getByTestId('round_history_1_card'));
      await expect(screen.getByText(/no score last round|last round \+|submitted|2 PLAYERS/)).toBeHidden();
      await captureState(app, `review-${appearance}-scoring`, 'Scores and the complete round card stay above the island at rest');
      await screen.getByTestId('scoring_tools_button').tap();
      await screen.getByRole('button', 'timer', { exact: true }).tap();
      await expect(screen.getByTestId('scoring_tool_done_button')).toBeVisible();
      const preset = screen.getByRole('button', '2m', { exact: true });
      const reset = screen.getByRole('button', 'reset', { exact: true });
      await revealSheetControl(screen, reset);
      await aboveIsland(screen, preset);
      await aboveIsland(screen, reset);
      const resetFrame = await reset.boundingBox();
      const closeFrame = await screen.getByTestId('scoring_tool_done_button').boundingBox();
      if (!resetFrame || !closeFrame) throw new Error('Timer controls have no current frame');
      expect(resetFrame.x + resetFrame.width).toBeLessThanOrEqual(closeFrame.x + closeFrame.width + 16);
      await preset.tap();
      await expect(screen.getByText('2:00', { exact: true })).toBeVisible();
      await reset.tap();
      await expect(screen.getByText('1:00', { exact: true })).toBeVisible();
      await captureState(app, `review-${appearance}-timer`, 'Timer presets and Reset are complete and clear of Close');
      await screen.getByTestId('scoring_tool_done_button').tap();
      await finishCurrentGame(app, screen, 'leo', `review-${appearance}`);
      await aboveIsland(screen, screen.getByLabel(/leo.*best round \+9.*9/));
      await captureState(app, `review-${appearance}-game-over-at-rest`, 'The first final-score row stays above the island at rest');
      await screen.getByTestId('home_button').tap();
      await aboveIsland(screen, screen.getByRole('button', 'learn about undo', { exact: true }));
      await captureState(app, `review-${appearance}-home-complete`, 'Game night tools remain above the root island');
      await tapTab(screen, 'Players');
      await aboveIsland(screen, screen.getByTestId('head_to_head_button'));
      await captureState(app, `review-${appearance}-players`, 'Head to head stays clear of the island at rest');
      await tapTab(screen, 'More');
      await expect(screen.getByTestId('more_upgrade_button')).toBeHidden();
      await aboveIsland(screen, screen.getByTestId('privacy_policy_link'));
      await expect(screen.getByText('FINAL', { exact: true })).toBeHidden();
      await captureState(app, `review-${appearance}-more`, 'Privacy policy is above the island and recent games have no FINAL stamp');
    } finally {
      await device.setAppearance('light');
    }
  });
}

test('empty Home has no zero statistics or floating upgrade and dark paywall is readable', async ({ app, screen, device }) => {
  await device.installApp();
  await device.setAppearance('dark');
  try {
    await device.openApp(bundle, { relaunch: true, launchArguments: ['-in-memory-store', '-exit-offer-seen', '-themeMode', 'system', '-UIPreferredContentSizeCategoryName', 'UICTContentSizeCategoryL'] });
    await expect(screen.getByTestId('paywall_main')).toBeVisible();
    await screen.getByTestId('paywall_close_button').tap();
    await expect(screen.getByTestId('new_game_button')).toBeVisible();
    await expect(screen.getByText('games', { exact: true })).toBeHidden();
    await expect(screen.getByText('active', { exact: true })).toBeHidden();
    await expect(screen.getByTestId('home_upgrade_button')).toBeHidden();
    await aboveIsland(screen, screen.getByRole('button', 'learn about undo', { exact: true }));
    await captureState(app, 'review-dark-home-empty', 'Empty Home hides the zero metrics and floating upgrade label');
    await tapTab(screen, 'More');
    await expect(screen.getByTestId('more_upgrade_button')).toHaveCount(1);
    await expect(screen.getByText(/^\d+ free games? left$/)).toBeHidden();
    await captureState(app, 'review-dark-upgrade-row', 'One high-contrast upgrade row in More for new non-Pro users, without a free-game count');
    await screen.getByTestId('more_upgrade_button').tap();
    await expect(screen.getByTestId(/^paywall_(primary|retry)_button$/)).toBeEnabled({ timeout: 30_000 });
    await captureState(app, 'review-dark-main-paywall', 'Main paywall in dark appearance on the open Duo');
  } finally {
    await device.setAppearance('light');
  }
});
