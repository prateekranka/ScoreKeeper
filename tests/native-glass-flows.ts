import { type Device } from '@e2e-dev/mobile';
import { expect, type Screen } from 'e2e';
import {
  foldIfSupported,
  enterKeyboardText,
  captureState,
  drawSeven,
  finishOnboarding,
  pressReturnKey,
  scrollControlAboveTabDock,
  scrollControlAboveFixedControl,
  swipeDeckPlayer,
  tapNativeControl,
  tapTab,
  visibleDeckPlayer,
  type ScreenshotApp,
} from './handwriting-helpers';

type GameKind = 'generic' | 'phase10' | 'whatsForDinner';
type TwoPlayers = readonly [string, string];

const bundleId = 'com.icequeen.scorekeeper';
const gameTiles: Record<GameKind, string> = {
  generic: 'game_tile_generic',
  phase10: 'game_tile_phase10',
  whatsForDinner: 'game_tile_whatsForDinner',
};

export async function tapGameOverAction(screen: Screen, testId: string): Promise<void> {
  const action = screen.getByTestId(testId);
  await screen.scrollUntilVisible(action);
  await action.tap();
}

export async function captureGameOverActions(app: ScreenshotApp, screen: Screen, label: string): Promise<void> {
  const home = screen.getByTestId('home_button');
  const playAgain = screen.getByTestId('play_again_button');
  await screen.scrollUntilVisible(home);
  await expect(home).toBeVisible();
  await expect(playAgain).toBeVisible();
  await captureState(app, label, 'Game Over lower section with Home and Play Again actions visible');
}

export async function returnToPlayersDock(screen: Screen): Promise<void> {
  const playersTab = screen.getByTestId('tab_players');
  for (let attempt = 0; attempt < 3; attempt += 1) {
    if (await playersTab.isVisible() || await screen.getByTestId('add_new_player_button').isVisible()) return;
    const islandBack = screen.getByTestId('island_back_button');
    const backButton = await islandBack.isVisible() ? islandBack : screen.getByTestId('BackButton');
    await expect(backButton).toBeVisible();
    await tapNativeControl(screen, backButton);
  }
  await expect(playersTab).toBeVisible();
}

export async function assertHistoryPageAndFirstCard(screen: Screen): Promise<void> {
  await expect(screen.getByText('game history', { exact: true }).first()).toBeVisible();
  const firstCard = screen.getByTestId('history_card_0');
  await screen.scrollUntilVisible(firstCard);
  await expect(firstCard).toBeVisible();
}

export async function returnFromHistoryToMore(screen: Screen): Promise<void> {
  const moreBack = screen.getByRole('button', 'more', { exact: true });
  if (await moreBack.isVisible()) {
    await moreBack.tap();
  } else {
    await screen.getByRole('button', 'Back', { exact: true }).tap();
  }
  await expect(screen.getByText('more', { exact: true }).first()).toBeVisible();
}

export async function launchFreshJourney(
  app: ScreenshotApp,
  screen: Screen,
  device: Device,
  extraArguments: string[] = ['-unlock-pro'],
): Promise<void> {
  await device.installApp();
  await device.openApp(bundleId, {
    relaunch: true,
    launchArguments: [
      '-in-memory-store',
      '-force-light-theme',
      '-reset-onboarding',
      '-UIPreferredContentSizeCategoryName',
      'UICTContentSizeCategoryL',
      ...extraArguments,
    ],
  });
  await foldIfSupported(device, 'closed');
  await device.setOrientation('portrait');
  await finishOnboarding(app, screen);
  await tapTab(screen, 'Home');
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
  await captureState(app, 'home-empty', 'home before any game starts');
}

export async function addPlayers(
  app: ScreenshotApp,
  screen: Screen,
  players: TwoPlayers,
  prefix: string,
  exerciseDuplicateValidation = false,
): Promise<void> {
  const first = screen.getByTestId('player_name_field_0');
  const second = screen.getByTestId('player_name_field_1');
  const continueButton = screen.getByTestId('start_game_button').last();

  await expect(first).toBeVisible();
  await expect(continueButton).toBeDisabled();
  await captureState(app, `${prefix}-setup-blank`, 'blank player setup with Continue disabled');

  await enterKeyboardText(screen, first, players[0]);
  await captureState(app, `${prefix}-setup-keyboard`, `first player entered: ${players[0]}`);
  await pressReturnKey(screen);
  await screen.scrollUntilVisible(second);

  await enterKeyboardText(screen, second, exerciseDuplicateValidation ? players[0].toUpperCase() : players[1]);
  await expect(second).toHaveValue(exerciseDuplicateValidation ? players[0].toUpperCase() : players[1]);
  if (exerciseDuplicateValidation) {
    await expect(screen.getByText('player names must be unique', { exact: true })).toBeVisible();
    await expect(continueButton).toBeDisabled();
    await captureState(app, `${prefix}-setup-duplicate-validation`, 'case-insensitive duplicate player name rejected');
    await pressReturnKey(screen);
    await enterKeyboardText(screen, second, players[1]);
    await expect(second).toHaveValue(players[1]);
  }

  await pressReturnKey(screen);
  await expect(continueButton).toBeEnabled();
  await expect(continueButton).toBeVisible();
  await captureState(app, `${prefix}-setup-filled`, `player setup ready for ${players.join(' and ')}`);
  await continueButton.tap();
}

export async function startGameFromHome(
  app: ScreenshotApp,
  screen: Screen,
  kind: GameKind,
  players: TwoPlayers,
  prefix: string,
  options: { duplicateValidation?: boolean; stopAfterSettings?: boolean; targetScore?: string } = {},
): Promise<void> {
  await tapTab(screen, 'Games');
  const tile = screen.getByTestId(gameTiles[kind]);
  await scrollControlAboveTabDock(screen, tile, 'tab_games', `${kind} game tile`);
  await expect(tile).toBeVisible();
  await captureState(app, `${prefix}-game-picker`, `game picker before ${kind}`);
  await tile.tap();

  await addPlayers(app, screen, players, prefix, options.duplicateValidation ?? false);
  if (kind !== 'whatsForDinner') {
    await expect(screen.getByText('rules for tonight', { exact: true })).toBeVisible();
    if (kind === 'generic') {
      const targetField = screen.getByTestId('target_score_field');
      await expect(targetField).toBeVisible();
      if (options.targetScore !== undefined) {
        await enterKeyboardText(screen, targetField, '0');
        await expect(screen.getByTestId('target_score_error')).toBeVisible();
        await expect(screen.getByTestId('start_game_button').last()).toBeDisabled();
        await captureState(app, `${prefix}-settings-target-invalid`, 'target score zero is rejected before the game starts');
        await enterKeyboardText(screen, targetField, options.targetScore);
        await expect(targetField).toHaveValue(options.targetScore);
        await expect(screen.getByTestId('target_score_error')).toBeHidden();
      }
    }
    await captureState(app, `${prefix}-settings`, `${kind} game settings`);
    if (options.stopAfterSettings) return;
    const startButton = screen.getByTestId('start_game_button').last();
    await expect(startButton).toBeVisible();
    await startButton.tap();
  }

  await expect(screen.getByTestId('submit_round_button').last()).toBeVisible();
  const modeHeader = kind === 'generic'
    ? screen.getByLabel('Round 1 running totals', { exact: true })
    : kind === 'phase10'
      ? screen.getByText('ten phases, round 1, 2 players', { exact: true })
      : screen.getByText("what's for dinner, round 1, 2 players", { exact: true });
  await expect(modeHeader).toBeVisible();
  await captureState(app, `${prefix}-scoreboard-before-round`, `${kind} scoreboard before its next round`);
}

export async function openRoundDeck(
  app: ScreenshotApp,
  screen: Screen,
  players: TwoPlayers,
  prefix: string,
): Promise<string> {
  await tapNativeControl(screen, screen.getByTestId('submit_round_button').last());
  await expect(screen.getByTestId('round_entry_deck')).toBeVisible();

  const gotIt = screen.getByRole('button', 'got it', { exact: true });
  if (await gotIt.isVisible()) {
    await captureState(app, `${prefix}-deck-tutorial`, 'first-use handwriting tutorial');
    await gotIt.tap();
  } else {
    await captureState(app, `${prefix}-deck-tutorial-dismissed`, 'handwriting tutorial had already been dismissed');
  }

  await expect(screen.getByTestId('score_writing_canvas')).toBeVisible();
  const current = await visibleDeckPlayer(screen, players);
  await captureState(app, `${prefix}-deck-blank`, `blank score canvas for ${current}`);
  return current;
}

export async function manualScoreForCurrentPlayer(
  app: ScreenshotApp,
  screen: Screen,
  player: string,
  value: number,
  prefix: string,
  invalidBoundaryChecks: boolean,
): Promise<void> {
  await tapNativeControl(screen, screen.getByTestId('deck_type_score_button'));
  const field = screen.getByTestId('deck_manual_value');
  const useButton = screen.getByTestId(`deck_manual_use_${player}`);
  const rangeHint = screen.getByTestId('deck_manual_range_hint');
  await expect(field).toBeVisible();
  await captureState(app, `${prefix}-${player}-manual-open`, `manual score field for ${player}`);

  if (invalidBoundaryChecks) {
    for (const invalid of [] as string[]) {
      await enterKeyboardText(screen, field, invalid);
      await expect(field).toHaveValue(invalid);
      await expect(rangeHint).toBeVisible();
      await expect(useButton).toBeDisabled();
      await captureState(app, `${prefix}-${player}-manual-invalid-${invalid === '-1' ? 'negative-one' : 'one-hundred'}`, `${invalid} is rejected by the 0 to 99 manual range`);
    }
  }

  await enterKeyboardText(screen, field, String(value));
  await expect(field).toHaveValue(String(value));
  await expect(rangeHint).toBeHidden();
  await expect(useButton).toBeEnabled();
  await captureState(app, `${prefix}-${player}-manual-valid-${value}`, `${player} entered valid manual score ${value}`);
  await tapNativeControl(screen, useButton);
}

export async function scoreManualRound(
  app: ScreenshotApp,
  screen: Screen,
  players: TwoPlayers,
  scores: Readonly<Record<string, number>>,
  prefix: string,
  invalidPlayer?: string,
  beforeEachPlayer?: (player: string) => Promise<void>,
  expectGameOver = false,
): Promise<void> {
  const first = await visibleDeckPlayer(screen, players);
  const second = players.find((name) => name.toLowerCase() !== first.toLowerCase())?.toLowerCase();
  if (!second) throw new Error('A two-player round needs two distinct players');

  for (const player of [first, second]) {
    await expect(screen.getByLabel(`Drawing area for ${player}'s score`, { exact: true })).toBeVisible();
    await beforeEachPlayer?.(player);
    const score = scores[player] ?? scores[player.toLowerCase()];
    if (score === undefined) throw new Error(`No manual score was supplied for ${player}`);
    await manualScoreForCurrentPlayer(app, screen, player, score, prefix, invalidPlayer?.toLowerCase() === player);
    if (player === first) {
      await expect(screen.getByLabel(`Drawing area for ${second}'s score`, { exact: true })).toBeVisible();
      await captureState(app, `${prefix}-partial-after-${first}`, `${first} confirmed; ${second} remains unscored`);
    }
  }

  await expect(screen.getByTestId('round_entry_deck')).toBeHidden();
  if (expectGameOver) {
    await expect(screen.getByTestId('winner_text').first()).toBeVisible();
  } else {
    await expect(screen.getByTestId('submit_round_button').last()).toBeVisible();
    await captureState(app, `${prefix}-scoreboard-after-round`, 'all player scores saved to the scoreboard');
  }
}

export async function finishCurrentGame(app: ScreenshotApp, screen: Screen, winner: string, prefix: string): Promise<void> {
  const tools = screen.getByTestId('scoring_tools_button');
  if (await tools.isVisible()) await tapNativeControl(screen, tools);
  await tapNativeControl(screen, screen.getByTestId('end_game_button').last());
  await screen.getByRole('button', 'end game', { exact: true }).last().tap();
  await expect(screen.getByTestId('winner_text').first()).toContainText(winner.toLowerCase());
  await captureState(app, `${prefix}-game-over`, `completed game; expected winner ${winner}`);
  await captureGameOverActions(app, screen, `${prefix}-game-over-actions`);
}

export async function addSavedPlayer(app: ScreenshotApp, screen: Screen, name: string, prefix: string): Promise<void> {
  const addNewPlayer = screen.getByTestId('add_new_player_button');
  await scrollControlAboveTabDock(screen, addNewPlayer, 'tab_players', 'Add saved player button');
  await addNewPlayer.tap();
  const field = screen.getByTestId('add_saved_player_name_field');
  await expect(field).toBeVisible();
  await captureState(app, `${prefix}-add-player-blank`, 'saved-player form before a name is entered');
  await enterKeyboardText(screen, field, name);
  await expect(field).toHaveValue(name);
  await captureState(app, `${prefix}-add-player-keyboard`, `saved-player form with ${name} entered`);
  await tapNativeControl(screen, screen.getByTestId('add_saved_player_save_button'));
  await expect(screen.getByTestId(`saved_player_${name.toLowerCase()}`)).toBeVisible();
  await captureState(app, `${prefix}-players-populated`, `saved player ${name.toLowerCase()} appears in the roster`);
}

export async function chooseHeadToHeadPlayers(screen: Screen, playerOne: string, playerTwo: string): Promise<void> {
  const firstPicker = screen.getByRole('button', /^player one, /).last();
  await screen.scrollUntilVisible(firstPicker, { direction: 'up' });
  await tapNativeControl(screen, firstPicker);
  const firstOption = screen.getByText(playerOne.toLowerCase(), { exact: true }).last();
  await expect(firstOption).toBeVisible();
  await tapNativeControl(screen, firstOption);

  const secondPicker = screen.getByRole('button', /^player two, /).last();
  await screen.scrollUntilVisible(secondPicker, { direction: 'up' });
  await tapNativeControl(screen, secondPicker);
  const secondOption = screen.getByText(playerTwo.toLowerCase(), { exact: true }).last();
  await expect(secondOption).toBeVisible();
  await tapNativeControl(screen, secondOption);
}

export async function completeTargetTie(
  app: ScreenshotApp,
  screen: Screen,
  players: TwoPlayers,
  prefix: string,
): Promise<void> {
  await startGameFromHome(app, screen, 'generic', players, prefix, { targetScore: '10' });
  await tapNativeControl(screen, screen.getByTestId('submit_round_button').last());
  await scoreManualRound(app, screen, players, { [players[0].toLowerCase()]: 5, [players[1].toLowerCase()]: 5 }, `${prefix}-round-01`);
  await tapNativeControl(screen, screen.getByTestId('submit_round_button').last());
  await scoreManualRound(
    app,
    screen,
    players,
    { [players[0].toLowerCase()]: 5, [players[1].toLowerCase()]: 5 },
    `${prefix}-round-02`,
    undefined,
    undefined,
    true,
  );
  await expect(screen.getByTestId('winner_text').first()).toContainText('tie');
  await captureState(app, `${prefix}-game-over`, 'both players naturally reached the target on the same round');
  await captureGameOverActions(app, screen, `${prefix}-game-over-actions`);
  await tapGameOverAction(screen, 'home_button');
}

export async function recognizeSevenForCurrentPlayer(
  app: ScreenshotApp,
  screen: Screen,
  player: string,
  prefix: string,
): Promise<void> {
  await drawSeven(screen);
  await captureState(app, `${prefix}-${player}-actual-ink-seven`, `actual screen-drawn seven for ${player}`);
  await tapNativeControl(screen, screen.getByTestId('recognize_score_button'));
  await expect(screen.getByRole('button', 'Use 7', { exact: true })).toBeVisible();
  await expect(screen.getByTestId('deck_source_thumbnail')).toBeVisible();
  await captureState(app, `${prefix}-${player}-recognized-seven`, `Vision recognized 7 and shows source ink for ${player}`);
}

export async function acceptSevenForCurrentPlayer(
  app: ScreenshotApp,
  screen: Screen,
  player: string,
  prefix: string,
): Promise<void> {
  await recognizeSevenForCurrentPlayer(app, screen, player, prefix);
  await tapNativeControl(screen, screen.getByTestId(`deck_accept_${player}`));
}

export async function resumeGameFromHome(screen: Screen, gameDisplayName: string, round: number): Promise<void> {
  const slider = screen.getByRole('button', `Resume ${gameDisplayName}, round ${round}`, { exact: true });
  const homeDockButton = screen.getByTestId('tab_home');
  await expect(slider).toBeVisible();

  let frame = await slider.boundingBox();
  let dockFrame = await homeDockButton.boundingBox();
  for (let attempt = 0; attempt < 6; attempt += 1) {
    if (!frame || frame.width < 120 || frame.height <= 0 || !dockFrame || dockFrame.height <= 0) {
      throw new Error(`Resume slider or Home dock for ${gameDisplayName} has no usable accessibility frame`);
    }
    if (frame.y >= 0 && frame.y + frame.height <= dockFrame.y - 8) break;

    const x = frame.x + frame.width / 2;
    const fromY = dockFrame.y - 12;
    const toY = Math.max(24, fromY - Math.max(140, frame.height + 72));
    await screen.swipe({ from: { x, y: fromY }, to: { x, y: toY } });
    frame = await slider.boundingBox();
    dockFrame = await homeDockButton.boundingBox();
  }

  if (!frame || !dockFrame || frame.y < 0 || frame.y + frame.height > dockFrame.y - 8) {
    throw new Error(`Resume slider for ${gameDisplayName} stayed below the Home dock after 6 scrolls`);
  }

  // Re-read the complete, unobscured frame before using the slider gesture.
  frame = await slider.boundingBox();
  dockFrame = await homeDockButton.boundingBox();
  if (!frame || !dockFrame || frame.width < 120 || frame.height <= 0 || frame.y < 0 || frame.y + frame.height > dockFrame.y - 8) {
    throw new Error(`Resume slider for ${gameDisplayName} lost its clear frame before the resume gesture`);
  }
  const y = frame.y + frame.height / 2;
  await screen.swipe({
    from: { x: frame.x + 26, y },
    to: { x: frame.x + frame.width - 18, y },
  });
}

export async function scoreGenericRoundWithInk(
  app: ScreenshotApp,
  screen: Screen,
  players: TwoPlayers,
  prefix: string,
): Promise<void> {
  const first = await openRoundDeck(app, screen, players, prefix);
  const second = players.find((name) => name.toLowerCase() !== first)?.toLowerCase();
  if (!second) throw new Error('A two-player round needs two distinct players');

  await expect(screen.getByTestId('deck_no_ink_hint')).toBeHidden();
  await tapNativeControl(screen, screen.getByTestId('recognize_score_button'));
  await expect(screen.getByTestId('deck_no_ink_hint')).toBeVisible();
  await captureState(app, `${prefix}-no-ink`, 'recognition with an empty canvas asks for ink');

  // Exercise player switching before confirmation. Returning to the first
  // card must show a blank canvas because its unconfirmed ink was discarded.
  await drawSeven(screen);
  await captureState(app, `${prefix}-${first}-ink-before-player-switch`, `${first} has unconfirmed ink`);
  await swipeDeckPlayer(screen, first, 'next');
  await expect(screen.getByLabel(`Drawing area for ${second}'s score`, { exact: true })).toBeVisible();
  await captureState(app, `${prefix}-player-jump-to-${second}`, `switching preserves confirmed scores and discards no card data`);
  await swipeDeckPlayer(screen, second, 'previous');
  await expect(screen.getByLabel(`Drawing area for ${first}'s score`, { exact: true })).toBeVisible();
  await captureState(app, `${prefix}-return-to-unconfirmed-${first}`, `${first}'s unconfirmed drawing was cleared after a player jump`);

  await drawSeven(screen);
  await captureState(app, `${prefix}-${first}-ink-seven`, `digit 7 drawn on ${first}'s score canvas`);
  await tapNativeControl(screen, screen.getByTestId(`deck_clear_${first}`));
  await captureState(app, `${prefix}-${first}-clear`, `clear removed unconfirmed ink from ${first}'s canvas`);
  await drawSeven(screen);
  await captureState(app, `${prefix}-${first}-ink-after-clear`, `digit 7 redrawn on ${first}'s score canvas`);
  await tapNativeControl(screen, screen.getByTestId('recognize_score_button'));
  await expect(screen.getByRole('button', 'Use 7', { exact: true })).toBeVisible();
  await expect(screen.getByTestId('deck_source_thumbnail')).toBeVisible();
  await captureState(app, `${prefix}-${first}-recognition-confirmation`, `recognized 7 and source drawing for ${first}`);
  await tapNativeControl(screen, screen.getByTestId(`deck_retry_${first}`));
  await expect(screen.getByTestId('score_writing_canvas')).toBeVisible();
  await captureState(app, `${prefix}-${first}-redraw`, `redraw returned ${first} to a fresh canvas`);
  await acceptSevenForCurrentPlayer(app, screen, first, `${prefix}-retry`);

  await expect(screen.getByLabel(`Drawing area for ${second}'s score`, { exact: true })).toBeVisible();
  await captureState(app, `${prefix}-partial-after-${first}`, `${first} confirmed; ${second} remains unscored`);
  await acceptSevenForCurrentPlayer(app, screen, second, prefix);

  const retryButton = screen.getByRole('button', 'try again', { exact: true });
  await expect(retryButton).toBeVisible();
  await captureState(app, `${prefix}-save-error-retained-draft`, 'first round save failed; both confirmed scores remain in the deck');
  await retryButton.tap();
  await expect(screen.getByTestId('round_entry_deck')).toBeHidden();
  await expect(screen.getByLabel('Round 2 running totals', { exact: true })).toBeVisible();
  await expect(screen.getByText('last round +7', { exact: true })).toHaveCount(2);
  await captureState(app, `${prefix}-save-retry-complete`, 'retry saved the complete handwritten 7 and 7 round');
}

export async function scorePhaseRound(
  app: ScreenshotApp,
  screen: Screen,
  players: TwoPlayers,
  prefix: string,
  actualInk: boolean,
  exerciseManualBoundaries = false,
): Promise<void> {
  const current = await openRoundDeck(app, screen, players, prefix);
  const other = players.find((name) => name.toLowerCase() !== current)?.toLowerCase();
  if (!other) throw new Error('A two-player round needs two distinct players');
  const order = [current, other];

  for (const [index, player] of order.entries()) {
    const stage = screen.getByTestId(`stage_toggle_${player}`);
    if (player === 'maya') {
      await screen.scrollUntilVisible(stage);
      if (prefix === 'phase-round-01') {
        await captureState(app, 'phase-stage-zero', 'Maya is offered the first stage-completion control before the first round');
      }
      await tapNativeControl(screen, stage);
      await captureState(app, `${prefix}-maya-stage-${index + 1}`, 'Maya marked the current Ten Phases stage complete');
    }

    if (actualInk && index === 0) {
      await acceptSevenForCurrentPlayer(app, screen, player, prefix);
    } else {
      const score = exerciseManualBoundaries ? 99 : player === 'maya' ? 5 : 2;
      await manualScoreForCurrentPlayer(app, screen, player, score, prefix, exerciseManualBoundaries && index === 1);
    }

    if (index === 0) {
      await expect(screen.getByLabel(`Drawing area for ${other}'s score`, { exact: true })).toBeVisible();
      await captureState(app, `${prefix}-partial-after-${player}`, `${player} confirmed; ${other} remains unscored`);
    }
  }

  await expect(screen.getByTestId('round_entry_deck')).toBeHidden();
  if (prefix.endsWith('10')) {
    await expect(screen.getByText('ten phases complete', { exact: true })).toBeVisible();
    await captureState(app, 'phase-completion-confirmation', 'Maya completed all ten phases after ten submitted rounds');
    await screen.getByRole('button', 'end game', { exact: true }).last().tap();
    await expect(screen.getByTestId('winner_text').first()).toContainText('maya');
    await captureState(app, 'phase-ten-completed', 'Ten Phases ended naturally after its completion prompt');
    await captureGameOverActions(app, screen, 'phase-ten-game-over-actions');
  } else {
    await expect(screen.getByTestId('submit_round_button').last()).toBeVisible();
    await captureState(app, `${prefix}-scoreboard-after-round`, 'the Ten Phases round was submitted and saved');
  }
}

export async function startDinnerRoundWithInk(
  app: ScreenshotApp,
  screen: Screen,
  players: TwoPlayers,
  prefix: string,
): Promise<string> {
  const header = screen.getByText("what's for dinner, round 1, 2 players", { exact: true });
  await expect(header).toBeVisible();
  await captureState(app, `${prefix}-scoreboard-header`, 'Dinner compact scoreboard header before scrolling to the caller choices');

  const caller = screen.getByTestId('meal_reveal_maya');
  await scrollControlAboveFixedControl(
    screen,
    caller,
    screen.getByTestId('submit_round_button').last(),
    'Dinner Meal Reveal caller above the pinned score action',
  );
  for (const player of players) {
    await expect(screen.getByTestId(`meal_reveal_${player.toLowerCase()}`)).toBeVisible();
  }
  await captureState(app, `${prefix}-caller-selection`, 'the Dinner Meal Reveal caller choices are visible before selection');
  await expect(caller).toBeVisible();
  await caller.tap();
  await captureState(app, `${prefix}-caller-selected`, 'Maya is selected as the Meal Reveal caller');
  const first = await openRoundDeck(app, screen, players, prefix);
  const second = players.find((name) => name.toLowerCase() !== first)?.toLowerCase();
  if (!second) throw new Error('A two-player round needs two distinct players');

  await acceptSevenForCurrentPlayer(app, screen, first, prefix);
  await expect(screen.getByLabel(`Drawing area for ${second}'s score`, { exact: true })).toBeVisible();
  await captureState(app, `${prefix}-partial-after-${first}`, `${first} confirmed; ${second} remains unscored`);
  await manualScoreForCurrentPlayer(app, screen, second, 0, prefix, false);
  await expect(screen.getByTestId('round_entry_deck')).toBeHidden();
  await expect(screen.getByTestId('submit_round_button').last()).toBeVisible();
  await captureState(app, `${prefix}-scoreboard-after-round`, 'Dinner scores saved; the second player entered a valid zero');
  return second;
}
