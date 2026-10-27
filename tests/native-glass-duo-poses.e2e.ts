import { readFile } from 'node:fs/promises';
import { test } from '@e2e-dev/mobile';
import { expect } from 'e2e';
import { captureState, enterKeyboardText, finishOnboarding, tapNativeControl, visibleDeckPlayer } from './handwriting-helpers';
import { assertClearOfIsland, screenshotPath } from './handwriting-duo-input';

test(process.env.PIPCOUNT_PREPARED_DUO_POSE
  ? `Duo exposes the prepared ${process.env.PIPCOUNT_PREPARED_DUO_POSE} viewport`
  : 'Duo exposes both required inner-display orientations', { timeout: 120_000 }, async ({ app, screen, device }) => {
  const preparedPose = process.env.PIPCOUNT_PREPARED_DUO_POSE;
  const poses = [
    { orientation: 'portrait', label: 'inner-landscape', size: { width: 951, height: 669 } },
    { orientation: 'landscape-left', label: 'inner-portrait', size: { width: 669, height: 951 } },
  ] as const;
  const selectedPoses = poses.filter(pose => !preparedPose || pose.label === preparedPose);
  expect(selectedPoses.length).toBeGreaterThan(0);
  await device.installApp();
  await device.openApp('com.icequeen.scorekeeper', {
    relaunch: true,
    launchArguments: ['-in-memory-store', '-unlock-pro', '-force-light-theme', '-break-ui-data', '-hasSeenScoreDeckTutorial', 'YES'],
  });
  await finishOnboarding(app, screen);
  if (!preparedPose) await device.fold('open');
  for (const pose of selectedPoses) {
    if (!preparedPose) await device.setOrientation(pose.orientation);
    await expect(screen.getByTestId('navigation_island')).toHaveCount(1);
    await expect(screen.getByRole('tablist')).toBeHidden();
    await assertClearOfIsland(screen, screen.getByTestId('new_game_button'));
    const artifact = await captureState(app, `duo-${pose.label}`, 'Open Duo uses the full inner display with one navigation island');
    const png = await readFile(await screenshotPath(artifact));
    expect({ width: png.readUInt32BE(16), height: png.readUInt32BE(20) }).toEqual(pose.size);
  }
});

test('Duo keeps the active game and manual score draft through folding', { timeout: 420_000 }, async ({ app, screen, device }) => {
  await device.installApp();
  await device.openApp('com.icequeen.scorekeeper', {
    relaunch: true,
    launchArguments: ['-in-memory-store', '-unlock-pro', '-force-light-theme', '-break-ui-data', '-hasSeenScoreDeckTutorial', 'YES'],
  });
  await finishOnboarding(app, screen);
  await device.fold('open');
  await device.setOrientation('portrait');
  const resume = screen.getByTestId(/^active_game_/).first();
  await screen.getByTestId('home_content_scroll').scrollUntilVisible(resume);
  const frame = await resume.boundingBox();
  if (!frame) throw new Error('The active game has no current frame');
  await screen.swipe({
    from: { x: frame.x + 30, y: frame.y + frame.height / 2 },
    to: { x: frame.x + frame.width - 15, y: frame.y + frame.height / 2 },
  });
  await expect(screen.getByTestId('running_total_maya')).toHaveText('7');
  await expect(screen.getByTestId('running_total_leo')).toHaveText('9');
  await tapNativeControl(screen, screen.getByTestId('submit_round_button').last());
  await expect(screen.getByTestId('round_entry_deck')).toBeVisible();
  const player = await visibleDeckPlayer(screen, ['maya', 'leo']);
  await tapNativeControl(screen, screen.getByTestId('deck_type_score_button'));
  const field = screen.getByTestId('deck_manual_value');
  await enterKeyboardText(screen, field, '46');
  await expect(field).toHaveValue('46');
  await device.fold('closed');
  await expect(screen.getByTestId('round_entry_deck')).toBeVisible();
  await expect(field).toHaveValue('46');
  await expect(screen.getByTestId(`deck_manual_use_${player}`)).toBeEnabled();
  await captureState(app, 'duo-folded-draft', 'The current player and score 46 remain after folding');
  await device.fold('open');
  await expect(screen.getByTestId('round_entry_deck')).toBeVisible();
  await expect(field).toHaveValue('46');
  await captureState(app, 'duo-reopened-draft', 'The same score draft remains after reopening the inner display');
  await tapNativeControl(screen, screen.getByTestId('round_deck_cancel_button'));
  await expect(screen.getByTestId('running_total_maya')).toHaveText('7');
  await expect(screen.getByTestId('running_total_leo')).toHaveText('9');
});
