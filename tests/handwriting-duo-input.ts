import { appendFile, readFile, readdir } from 'node:fs/promises';
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
  const root = resolve(manifest, '..', 'artifacts');
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

/**
 * Temporary, bounded compatibility for this Duo's open landscape-left pose.
 * The installed native runner rotates input with an 871-wide app window while
 * its inner panel capture is 951 wide. The final score assertion proves where
 * the one corrected input landed. Never apply this to another size or pose.
 */
export async function tapOpenDuoControl(
  app: CaptureApp, screen: Screen, control: Locator, label: string,
  verifyUncertainResult?: () => Promise<void>,
): Promise<void> {
  await expect(control).toBeVisible();
  const artifact = await screenshotPath(await app.screenshot(`${label}-input-reference`));
  const png = await readFile(artifact);
  const size = { width: png.readUInt32BE(16), height: png.readUInt32BE(20) };
  if (size.width !== 951 || size.height !== 669) {
    throw new Error('The open Duo input correction requires the observed 951×669 panel');
  }
  const bounds = await control.boundingBox();
  if (!bounds) throw new Error('The open Duo control has no current bounds');
  const point = { x: bounds.x + bounds.width / 2 - 80, y: bounds.y + bounds.height / 2 };
  if (point.x < 0 || point.x >= 871 || point.y < 0 || point.y >= 669) {
    throw new Error('The corrected input point is outside this app window');
  }
  const manifest = process.env.PIPCOUNT_JOURNEY_MANIFEST;
  if (manifest) await appendFile(manifest, `${JSON.stringify({
    label: `${label}-input-reference`, state: 'open Duo control before the measured input correction',
    artifact, inputGeometry: { bounds, point, panel: size, appWindowWidth: 871, correction: -80 },
  })}\n`, 'utf8');
  try {
    await screen.tapAt(point);
  } catch (error) {
    if (!verifyUncertainResult || !(error instanceof Error) ||
        !error.message.includes('XCTest recorded a failure while executing tap')) throw error;
    // XCTest can report a failure after the app accepted this action. Read a
    // fresh state and require the caller's exact postcondition. Never retap.
    const after = await app.screenshot(`${label}-uncertain-result`);
    try { await verifyUncertainResult(); }
    catch (verificationError) {
      throw new Error(`The uncertain native tap did not pass its postcondition: ${verificationError instanceof Error ? verificationError.message : String(verificationError)}`, { cause: error });
    }
    if (manifest) await appendFile(manifest, `${JSON.stringify({
      label: `${label}-uncertain-result`, artifact: after,
      state: 'native tap returned an error; the exact app postcondition passed without repeating the action',
      actionResult: 'verified-after-uncertain-error',
    })}\n`, 'utf8');
  }
}
