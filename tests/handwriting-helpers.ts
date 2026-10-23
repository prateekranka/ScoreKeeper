import { appendFile, mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';
import { expect, type Locator, type Screen } from 'e2e';
import type { Device } from '@e2e-dev/mobile';

export async function foldIfSupported(device: Device, pose: Parameters<Device['fold']>[0]): Promise<void> {
  if (!process.env.PIPCOUNT_NO_FOLD) await device.fold(pose);
}

export type ScreenshotApp = {
  screenshot(label?: string): Promise<string>;
};

/** Tap the current accessible frame, which avoids stale native-control coordinates. */
export async function tapNativeControl(screen: Screen, locator: Locator): Promise<void> {
  await expect(locator).toBeVisible();
  const bounds = await locator.boundingBox();
  if (!bounds || bounds.width <= 0 || bounds.height <= 0) {
    throw new Error('Control has no accessible frame');
  }
  await screen.tapAt({
    x: bounds.x + bounds.width / 2,
    y: bounds.y + bounds.height / 2,
  });
}

export async function tapScoringTool(screen: Screen, title: string): Promise<void> {
  const menu = screen.getByTestId('scoring_tools_button');
  if (await menu.isVisible()) await tapNativeControl(screen, menu);
  await tapNativeControl(screen, screen.getByRole('button', title, { exact: true }));
}

export async function tapTab(screen: Screen, name: string): Promise<void> {
  const identifier = {
    Home: 'tab_home',
    Games: 'tab_games',
    Players: 'tab_players',
    More: 'legal_support_button',
  }[name];
  if (!identifier) throw new Error(`Unknown primary tab: ${name}`);
  const tab = screen.getByTestId(identifier);
  await expect(tab).toBeVisible();
  await tab.tap();
}

/** Scroll a surface until a control's full frame sits above its floating tab dock. */
export async function scrollControlAboveTabDock(
  screen: Screen,
  control: Locator,
  dockTestId: string,
  description: string,
): Promise<void> {
  const dock = screen.getByTestId(dockTestId, { visible: true }).last();
  await scrollControlAboveFixedControl(screen, control, dock, description);
}

/** Scroll a surface until the target sits fully above a pinned bottom action. */
export async function scrollControlAboveFixedControl(
  screen: Screen,
  control: Locator,
  fixedControl: Locator,
  description: string,
): Promise<void> {
  for (let attempt = 0; attempt <= 6; attempt += 1) {
    if (!(await control.isVisible())) await screen.scrollUntilVisible(control);
    const frame = await control.boundingBox();
    const dockFrame = await fixedControl.boundingBox();
    if (!frame || frame.width <= 0 || frame.height <= 0 || !dockFrame || dockFrame.height <= 0) {
      throw new Error(`${description} or its pinned control has no usable accessibility frame`);
    }
    if (dockFrame.x >= frame.x + frame.width || frame.x >= dockFrame.x + dockFrame.width) return;
    const top = 24;
    const bottom = dockFrame.y - 8;
    const fits = frame.height <= bottom - top;
    const targetTop = fits ? frame.y : frame.y + frame.height / 2 - 22;
    const targetBottom = fits ? frame.y + frame.height : targetTop + 44;
    if (targetTop >= top && targetBottom <= bottom) return;
    if (attempt === 6) throw new Error(`${description} stayed partly behind its pinned control after 6 scrolls`);
    const forward = targetBottom > bottom;
    const overflow = forward ? targetBottom - bottom : top - targetTop;
    const distance = Math.min(120, Math.max(24, overflow + 8), (bottom - top) / 2);
    const x = frame.x + 4;
    const center = (top + bottom) / 2;
    await screen.swipe({
      from: { x, y: center + (forward ? distance / 2 : -distance / 2) },
      to: { x, y: center + (forward ? -distance / 2 : distance / 2) },
      duration: 500,
    });
  }
}

/** Save a named e2e screenshot and append its report-relative path to the task manifest. */
export async function captureState(
  app: ScreenshotApp,
  label: string,
  state: string,
): Promise<string> {
  const artifact = await app.screenshot(label);
  const manifestPath = process.env.PIPCOUNT_JOURNEY_MANIFEST;
  if (!manifestPath) throw new Error('PIPCOUNT_JOURNEY_MANIFEST is required for durable capture notes');
  await mkdir(dirname(manifestPath), { recursive: true });
  await appendFile(manifestPath, `${JSON.stringify({ label, state, artifact })}\n`, 'utf8');
  return artifact;
}

export async function finishOnboarding(app: ScreenshotApp, screen: Screen): Promise<boolean> {
  const primaryButton = screen.getByTestId('onboarding_primary_button');
  if (!(await primaryButton.isVisible())) return false;

  const title = screen.getByTestId('onboarding_page_title');
  for (const page of ['score', 'setup', 'history']) {
    await expect(title).toBeVisible();
    await expect.poll(async () => (await title.boundingBox())?.x ?? -1).toBeGreaterThanOrEqual(0);
    await captureState(app, `onboarding-${page}`, `onboarding page: ${page}`);
    await primaryButton.tap();
  }
  await expect(primaryButton).not.toBeVisible();
  return true;
}

export async function pressReturnKey(screen: Screen): Promise<void> {
  const returnKey = screen.getByTestId('Return');
  await expect(returnKey).toBeVisible();
  const keyFrame = await returnKey.boundingBox();
  const keyboardFrame = await screen.getByTestId('inputView').boundingBox();
  if (!keyFrame || !keyboardFrame || keyFrame.x < keyboardFrame.x || keyFrame.y < keyboardFrame.y ||
      keyFrame.x + keyFrame.width > keyboardFrame.x + keyboardFrame.width + 1 ||
      keyFrame.y + keyFrame.height > keyboardFrame.y + keyboardFrame.height + 1) {
    throw new Error('The Return key is not inside the current software keyboard');
  }
  // The native runner can misclassify a keyboard key as an app control covered by the keyboard.
  // A documented local position taps the verified key frame; dismissal proves its result.
  await returnKey.tap({ position: { x: keyFrame.width / 2, y: keyFrame.height / 2 } });
  await expect(returnKey).toBeHidden();
}

/** Draw a seven with two real touch strokes placed inside the live PencilKit canvas frame. */
export async function drawSeven(screen: Screen): Promise<void> {
  const canvas = screen.getByTestId('score_writing_canvas');
  await expect(canvas).toBeVisible();
  const frame = await canvas.boundingBox();
  if (!frame || frame.width <= 0 || frame.height <= 0) {
    throw new Error('Score writing canvas has no accessible frame');
  }

  const topY = frame.y + frame.height * 0.2;
  await screen.swipe({
    from: { x: frame.x + frame.width * 0.22, y: topY },
    to: { x: frame.x + frame.width * 0.78, y: topY },
  });
  await screen.swipe({
    from: { x: frame.x + frame.width * 0.78, y: frame.y + frame.height * 0.2 },
    to: { x: frame.x + frame.width * 0.28, y: frame.y + frame.height * 0.8 },
  });
}

export async function visibleDeckPlayer(screen: Screen, names: readonly string[]): Promise<string> {
  for (const name of names) {
    if (await screen.getByLabel(`Drawing area for ${name.toLowerCase()}'s score`, { exact: true }).isVisible()) {
      return name.toLowerCase();
    }
  }
  throw new Error(`No visible score drawing area for ${names.join(' or ')}`);
}

/** Move between score cards through the source-defined edge swipe areas. */
export async function swipeDeckPlayer(screen: Screen, currentPlayer: string, direction: 'previous' | 'next'): Promise<void> {
  const area = screen.getByLabel(`Drawing area for ${currentPlayer.toLowerCase()}'s score`, { exact: true });
  await expect(area).toBeVisible();
  const frame = await area.boundingBox();
  if (!frame || frame.width < 80 || frame.height <= 0) {
    throw new Error('Score drawing area has no usable accessibility frame');
  }
  const y = frame.y + frame.height / 2;
  const fromX = direction === 'previous' ? frame.x + 4 : frame.x + frame.width - 4;
  const toX = direction === 'previous' ? frame.x + 54 : frame.x + frame.width - 54;
  await screen.swipe({ from: { x: fromX, y }, to: { x: toX, y } });
}

/** Native keyboard events avoid the runner's incorrect covered-field ref. */
export async function enterKeyboardText(screen: Screen, field: Locator, value: string): Promise<void> {
  await tapNativeControl(screen, field);
  const anchor = /^-?\d+$/.test(value)
    ? screen.getByText('9', {exact:true}).last()
    : screen.getByTestId('Return', {visible:true}).last();
  await expect(anchor).toBeVisible();
  const prior = await field.inputValue();
  const placeholder = await field.getAttribute('placeholder');
  if (prior && prior !== placeholder) {
    const end = await field.boundingBox();
    if (!end) throw new Error('The input field has no current frame');
    await screen.tapAt({x:end.x+end.width-10,y:end.y+end.height/2});
    const deletion = screen.getByLabel(/^(delete|Delete)$/).last();
    for (const character of prior) await tapNativeControl(screen, deletion);
    await expect(field).toHaveValue('');
  }
  for (const character of value) await anchor.press(character);
  await expect(field).toHaveValue(value);
}
