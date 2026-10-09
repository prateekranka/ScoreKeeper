import {test} from '@e2e-dev/mobile';
import {expect} from 'e2e';
import {captureState,tapNativeControl} from './handwriting-helpers';
test('native tabs retain their stable identifiers',async({app,screen,device})=>{
 await device.installApp(); await app.open();
 for(const [id,content] of [['tab_home','new_game_button'],['tab_games','game_tile_generic'],['tab_players','add_new_player_button'],['legal_support_button','theme_light_button']]){
  await expect(screen.getByTestId(id)).toBeVisible();
  await tapNativeControl(screen,screen.getByTestId(id));
  await expect(screen.getByTestId(content)).toBeVisible();
  await captureState(app,`native-${id}`,'Native tab with original identifier and correct destination');
 }
});
