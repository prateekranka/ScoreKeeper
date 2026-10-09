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
  const keyboardKey = screen.getByTestId('inputView').last();
  await expect(keyboardKey).toBeVisible();
  for (const character of value) await keyboardKey.press(character);
  await expect(field).toHaveValue(value);
}

export async function submitOpenDuoName(app:CaptureApp,screen:Screen,label:string):Promise<void>{
  const keyboard=screen.getByTestId('inputView').last();
  await expect(keyboard).toBeVisible();
  const key=screen.getByTestId('Return').last();
  if(await key.isVisible()){
    const frame=await key.boundingBox();
    if(!frame) throw new Error('The visible Return key has no current frame');
    await key.tap({position:{x:frame.width/2,y:frame.height/2}});
  }else{
    try{await keyboard.press('Enter');}
    catch(error){
      if(!(error instanceof Error)||!error.message.includes('XCTest recorded a failure while executing keyboardReturn')) throw error;
      await app.screenshot(`${label}-return-result`);
      await expect(keyboard).toBeHidden();
      console.log('Native Return reported an error; actual keyboard dismissal verified without repeating the action',label);
    }
  }
  await expect(keyboard).toBeHidden();
}
