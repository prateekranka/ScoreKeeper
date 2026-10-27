import { test } from '@e2e-dev/mobile';
import { expect } from 'e2e';
import { tapNativeControl, captureState } from './handwriting-helpers';
import {
  launchFreshJourney,
  startGameFromHome,
  openRoundDeck,
  scoreManualRound,
  finishCurrentGame,
  tapGameOverAction,
} from './native-glass-flows';

test('legacy access completes a game and rematch through native scoring', { timeout: 300_000 }, async ({ app, screen, device }) => {
  const names = ['Maya', 'Leo'] as const;
  await launchFreshJourney(app, screen, device, ['-unlock-pro', '-hasSeenScoreDeckTutorial', 'YES']);
  await startGameFromHome(app, screen, 'generic', names, 'release-smoke');
  await openRoundDeck(app, screen, names, 'release-smoke');
  await scoreManualRound(app, screen, names, { maya: 7, leo: 9 }, 'release-smoke');
  await expect(screen.getByTestId('running_total_maya')).toHaveText('7');
  await expect(screen.getByTestId('running_total_leo')).toHaveText('9');
  await expect(screen.getByTestId('undo_last_round_button')).toBeEnabled();
  await tapNativeControl(screen, screen.getByTestId('undo_last_round_button'));
  await expect(screen.getByTestId('running_total_maya')).toHaveText('0');
  await expect(screen.getByTestId('running_total_leo')).toHaveText('0');
  await openRoundDeck(app, screen, names, 'release-smoke-rescore');
  await scoreManualRound(app, screen, names, { maya: 7, leo: 9 }, 'release-smoke-rescore');
  await finishCurrentGame(app, screen, 'leo', 'release-smoke');
  await tapGameOverAction(screen, 'play_again_button');
  await expect(screen.getByTestId('submit_round_button').last()).toBeVisible();
  await expect(screen.getByTestId('paywall_main')).toBeHidden();
  await captureState(app, 'release-smoke-rematch', 'The preserved legacy entitlement allows a native rematch');
});

test('the last legacy start preserves the active game and gates its rematch', { timeout: 300_000 }, async ({ app, screen, device }) => {
  const names = ['Maya', 'Leo'] as const;
  await launchFreshJourney(app, screen, device, ['-grandfathered', '24', '-exit-offer-seen', '-hasSeenScoreDeckTutorial', 'YES']);
  await startGameFromHome(app, screen, 'generic', names, 'last-legacy-start');
  await openRoundDeck(app, screen, names, 'last-legacy-start');
  await scoreManualRound(app, screen, names, { maya: 7, leo: 9 }, 'last-legacy-start');
  await expect(screen.getByTestId('running_total_maya')).toHaveText('7');
  await expect(screen.getByTestId('running_total_leo')).toHaveText('9');
  await expect(screen.getByTestId('paywall_main')).toBeHidden();
  await finishCurrentGame(app, screen, 'leo', 'last-legacy-start');
  await tapGameOverAction(screen, 'play_again_button');
  await expect(screen.getByTestId('paywall_main')).toBeVisible();
  await tapNativeControl(screen, screen.getByTestId('paywall_close_button'));
  await expect(screen.getByTestId('play_again_button')).toBeVisible();
  await expect(screen.getByText('leo wins', { exact: true })).toBeVisible();
  await captureState(app, 'last-legacy-rematch-gate', 'The exhausted allowance blocks a rematch while retaining the completed game');
});
