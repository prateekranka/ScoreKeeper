import { expect, type Locator, type Screen } from 'e2e';
import { tapOpenDuoControl } from './handwriting-duo-input';

type CaptureApp = { screenshot(label?: string): Promise<string> };

/**
 * Use the public mobile key-press route after the measured field focus.
 * A software-keyboard node anchors the key event without refocusing through
 * the incorrect landscape ref coordinates. This helper accepts fresh fields
 * only; its final field assertion checks the exact destination and full value.
 */
export async function enterOpenDuoText(
  app: CaptureApp, screen: Screen, field: Locator, value: string, label: string,
): Promise<void> {
  if (!value || [...value].length > 80) throw new Error('Open Duo text must contain 1–80 characters');
  await tapOpenDuoControl(app, screen, field, `${label}-focus`);
  const keyboardKey = /^\d+$/.test(value)
    ? screen.getByText('9', { exact: true }).last()
    : screen.getByTestId('Return', { visible: true }).last();
  await expect(keyboardKey).toBeVisible();
  for (const character of value) await keyboardKey.press(character);
  await expect(field).toHaveValue(value);
}
