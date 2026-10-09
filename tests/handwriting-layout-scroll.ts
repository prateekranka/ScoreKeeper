import type { Device } from '@e2e-dev/mobile';
import type { Locator, Screen } from 'e2e';

/** Keep controls below navigation and above pinned actions with short, reversible drags. */
export async function scrollMainContent(screen: Screen, device: Device, target: Locator, direction: 'up' | 'down' = 'down', openDuo = false, fullControl = false, searchAttempts = 18): Promise<void> {
  const accessibleDeck = screen.getByTestId('round_deck_accessible_scroll').last();
  const inAccessibleDeck = await accessibleDeck.isVisible();
  const inAccessibleScoring = await screen.getByTestId('scoring_accessible_scroll').isVisible();
  const inOpenDuo = openDuo;
  if (await screen.getByTestId('round_entry_deck').isVisible() && !inAccessibleDeck) {
    const deck = await screen.getByTestId('round_entry_deck').boundingBox();
    const bounds = await target.boundingBox();
    if (!deck || !bounds) throw new Error('The frontmost deck control has no current frame');
    const center = bounds.y + bounds.height / 2;
    if (center >= deck.y + 22 && center <= deck.y + deck.height - 22) return;
    throw new Error('The frontmost deck control is outside its usable viewport');
  }
  let towardLaterRows = direction === 'down';
  for (let attempt = 0; attempt < searchAttempts; attempt += 1) {
    const frames = [];
    if (inAccessibleDeck) {
      const bounds = await screen.getByTestId('round_entry_deck').boundingBox();
      if (bounds) frames.push(bounds);
    } else if (inAccessibleScoring) {
      const bounds = await screen.getByTestId('scoring_accessible_scroll').boundingBox();
      if (bounds) frames.push(bounds);
    } else {
      const scrollViews = await device.locator('role=ScrollView').all();
      for (const view of scrollViews) {
        try {
          const bounds = await view.boundingBox();
          if (bounds && bounds.width >= 160 && bounds.height >= 120) frames.push(bounds);
        } catch (error) {
          if (!(error instanceof Error) || !error.message.includes('matched no nodes')) throw error;
          // A transition removed a scroll view from the current tree. Keep
          // the current surviving frames rather than using the stale index.
        }
      }
    }
    // Prefer the complete surface over nested horizontal history or keyboard views.
    const frame = frames.sort((left, right) => right.width*right.height-left.width*left.height)[0];
    if (!frame) throw new Error('The main scroll view has no current frame');
    if(attempt===0 || attempt===8) console.log('Scroll surface',frame,'candidates',frames,'target',await target.isVisible()?await target.boundingBox():null);
    const targetVisible = await target.isVisible();
    const targetFrame = targetVisible ? await target.boundingBox() : null;
    let bottom = frame.y + frame.height - 16;
    for (const id of (inAccessibleDeck || inAccessibleScoring ? [] : ['start_game_button', 'submit_round_button', 'tab_games', 'legal_support_button'])) {
      const fixed = screen.getByTestId(id, { visible: true }).last();
      if (await fixed.isVisible()) {
        const fixedFrame = await fixed.boundingBox();
        // A pinned action is itself a valid target; it must not exclude itself.
        if (fixedFrame && targetFrame && fixedFrame.x === targetFrame.x && fixedFrame.y === targetFrame.y) continue;
        const horizontalRegion = targetFrame ?? frame;
        const overlapsHorizontally = fixedFrame && fixedFrame.x < horizontalRegion.x + horizontalRegion.width && fixedFrame.x + fixedFrame.width > horizontalRegion.x;
        if (fixedFrame && overlapsHorizontally && fixedFrame.x >= frame.x && fixedFrame.y > frame.y) {
          bottom = Math.min(bottom, fixedFrame.y - 16);
        }
      }
    }
    // Native ScrollView bounds include the area beneath the navigation bar.
    const top = Math.max(inAccessibleDeck || inAccessibleScoring ? 24 : fullControl ? 128 : 96, frame.y + 24);
    if (bottom - top < 60) throw new Error('The main scroll view has no clear drag region');
    const availableHeight = bottom - top;
    let distance = Math.min(180, availableHeight * 0.45);
    if (targetFrame) {
      const fullControlFits = targetFrame.height <= Math.min(inAccessibleDeck || inAccessibleScoring || fullControl ? availableHeight : 100, availableHeight);
      const controlTop = fullControlFits ? targetFrame.y : targetFrame.y + targetFrame.height / 2 - 22;
      const controlBottom = fullControlFits ? targetFrame.y + targetFrame.height : controlTop + 44;
      if (controlTop >= top && controlBottom <= bottom) return;
      towardLaterRows = controlBottom > bottom;
      const overflow = towardLaterRows ? controlBottom - bottom : top - controlTop;
      distance = Math.min(distance, Math.max(56, overflow + 6));
    } else if (attempt === Math.floor(searchAttempts / 2) - 1 && direction === 'down') {
      // Off-screen rows can be absent from the tree. Search back if we passed one.
      towardLaterRows = !towardLaterRows;
    }
    // Stay within the rendered leading gutter. The expanded Duo's reported
    // view bounds can extend into its black trailing safe area.
    const x = inOpenDuo ? Math.max(340, Math.min(680, frame.x + frame.width / 2 - 80)) : frame.x + frame.width / 2;
    const centerY = top + availableHeight / 2;
    const fromY = centerY + (towardLaterRows ? distance / 2 : -distance / 2);
    const toY = centerY + (towardLaterRows ? -distance / 2 : distance / 2);
    if (inAccessibleDeck && await screen.getByTestId('score_writing_canvas').isVisible()) {
      const canvas = await screen.getByTestId('score_writing_canvas').boundingBox();
      const bands = canvas ? [
        { start: top, end: Math.min(bottom, canvas.y - 8) },
        { start: Math.max(top, canvas.y + canvas.height + 8), end: bottom },
      ].filter(band => band.end - band.start >= 24) : [{start:top,end:bottom}];
      if (!bands.length) throw new Error('There is no scroll region outside the drawing canvas');
      const band = bands.sort((a,b)=>towardLaterRows ? b.end-a.end : a.start-b.start)[0];
      const start = towardLaterRows ? band.end-6 : band.start+6;
      const end = Math.max(top,Math.min(bottom,start+(towardLaterRows ? -distance : distance)));
      await screen.swipe({from:{x,y:start},to:{x,y:end}});
    } else await screen.swipe({ from: { x, y: fromY }, to: { x, y: toY } });
  }
  throw new Error(`The target did not reach a usable region after ${searchAttempts} short scrolls`);
}

