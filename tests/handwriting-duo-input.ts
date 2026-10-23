import { appendFile, readdir } from 'node:fs/promises';
import { isAbsolute, join, resolve, sep } from 'node:path';
import { expect, type Locator, type Screen } from 'e2e';

type CaptureApp = { screenshot(label?: string): Promise<string> };

// e2e returns a path relative to the current attempt's artifact directory.
// Resolve only a unique match within this run, without assuming its hashed name.
export async function screenshotPath(artifact: string): Promise<string> {
  if (isAbsolute(artifact)) return artifact;
  const manifest = process.env.PIPCOUNT_JOURNEY_MANIFEST;
  if (!manifest || !isAbsolute(manifest) || artifact.split(/[\\/]/).includes('..')) {
    throw new Error('A run-local absolute manifest is required to resolve this screenshot');
  }
  const root = resolve(manifest, '..', 'results');
  const suffix = sep + artifact.split(/[\\/]/).join(sep);
  const matches: string[] = [];
  let entriesSeen = 0;
  async function visit(directory: string): Promise<void> {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      if (++entriesSeen > 10_000) throw new Error('Screenshot resolution exceeded its run-local bound');
      const candidate = join(directory, entry.name);
      if (entry.isDirectory()) await visit(candidate);
      else if (entry.isFile() && candidate.endsWith(suffix)) matches.push(candidate);
    }
  }
  await visit(root);
  if (matches.length !== 1) throw new Error(`Expected one run-local screenshot, found ${matches.length}`);
  return matches[0];
}

export async function tapOpenDuoControl(
  app: CaptureApp, screen: Screen, control: Locator, label: string,
  verifyUncertainResult?: () => Promise<void>,
): Promise<void> {
  await expect(control).toBeVisible();
  const artifact = await screenshotPath(await app.screenshot(`${label}-input-reference`));
  const bounds = await control.boundingBox();
  if (!bounds || bounds.width <= 0 || bounds.height <= 0) {
    throw new Error('The open Duo control has no current native frame');
  }
  const manifest = process.env.PIPCOUNT_JOURNEY_MANIFEST;
  if (manifest) await appendFile(manifest, `${JSON.stringify({
    label: `${label}-input-reference`, state: 'native locator input in the full-width window',
    artifact, inputGeometry: { bounds, input: 'native locator' },
  })}\n`, 'utf8');
  try {
    await control.tap();
  } catch (error) {
    if (!verifyUncertainResult || !(error instanceof Error) ||
        !error.message.includes('XCTest recorded a failure while executing tap')) throw error;
    const after = await app.screenshot(`${label}-uncertain-result`);
    await verifyUncertainResult();
    if (manifest) await appendFile(manifest, `${JSON.stringify({
      label: `${label}-uncertain-result`, artifact: after,
      state: 'native tap reported an error; the exact postcondition passed without a repeated action',
      actionResult: 'verified-after-uncertain-error',
    })}\n`, 'utf8');
  }
}

export async function assertIslandLayout(screen: Screen, scroll: Locator, expectedWidth?: number): Promise<void> {
  const island = screen.getByTestId('navigation_island');
  await expect(island).toHaveCount(1);
  await expect(island).toBeVisible();
  const bounds = await island.boundingBox();
  const viewport = await scroll.boundingBox();
  if (!bounds || !viewport) throw new Error('The island or content scroll view has no native frame');
  const trailingGap = viewport.x + viewport.width - bounds.x - bounds.width;
  const bottomGap = viewport.y + viewport.height - bounds.y - bounds.height;
  const homeIndicatorInset = 34;
  if (trailingGap < -1 || trailingGap > 24 || bottomGap < -1 || bottomGap > 24 + homeIndicatorInset ||
      bounds.x < viewport.x || bounds.y < viewport.y || Math.min(bounds.width, bounds.height) > 84) {
    throw new Error(`The island is not compact and bottom-trailing: ${JSON.stringify({bounds, viewport})}`);
  }
  if (expectedWidth !== undefined) {
    expect(viewport.width).toBeCloseTo(expectedWidth, 0);
    expect(bounds.width).toBeGreaterThan(bounds.height);
  }
  console.log('Island and full-width content frames', {bounds, viewport, trailingGap, bottomGap});
}

export async function assertClearOfIsland(screen: Screen, control: Locator): Promise<void> {
  await expect(control).toBeVisible();
  const bounds = await control.boundingBox();
  const island = await screen.getByTestId('navigation_island').boundingBox();
  if (!bounds || !island) throw new Error('The content control or island has no native frame');
  if (bounds.x < island.x + island.width && bounds.x + bounds.width > island.x &&
      bounds.y < island.y + island.height && bounds.y + bounds.height > island.y) {
    throw new Error('The content control is covered by the island');
  }
}

export async function tapOpenDuoTab(app: CaptureApp, screen: Screen, control: Locator, name: string): Promise<void> {
  const scroll = screen.getByTestId(/^(home|games|players|more)_content_scroll$/, {visible: true});
  await assertIslandLayout(screen, scroll);
  await expect(control).toBeVisible();
  const bounds = await control.boundingBox();
  if (!bounds || bounds.width < 44 || bounds.height < 44) {
    throw new Error('The island control has less than a 44 point target');
  }
  await app.screenshot(`wide-island-${name.toLowerCase()}-reference`);
  await control.tap();
  await expect(screen.getByRole('button', name, { exact: true, selected: true })).toBeVisible();
}
