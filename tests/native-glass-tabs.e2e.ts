import {test} from '@e2e-dev/mobile';
import {expect} from 'e2e';
import {captureState,tapTab} from './handwriting-helpers';
import {tapOpenDuoTab,assertIslandLayout} from './handwriting-duo-input';
import {scrollMainContent} from './handwriting-layout-scroll';

test('root navigation retains identifiers in folded and open Duo poses', {timeout: 600000}, async({app,screen,device})=>{
 await device.installApp();
 await app.open();
 try {
  const poses=process.env.PIPCOUNT_DUO_POSE==='default'?['default','closed','open'] as const:['closed','open'] as const;
  for (const pose of poses) {
   if(pose!=='default') await device.fold(pose);
   const island=screen.getByTestId('navigation_island');
   if (pose!=='closed') await expect(island).toHaveCount(1);
   if(pose==='default') await assertIslandLayout(screen,screen.getByTestId(/^(home|games|players|more)_content_scroll$/, {visible:true}),Number(process.env.PIPCOUNT_DUO_WINDOW_WIDTH ?? '466'));
   if(pose==='closed') await expect(island).toBeHidden();
   for(const [name,id,content] of [['Home','tab_home','new_game_button'],['Games','tab_games','game_tile_generic'],['Players','tab_players','add_new_player_button'],['More','legal_support_button','theme_light_button']]){
    const tab=screen.getByTestId(id);
    await expect(tab).toBeVisible();
    if(pose!=='closed') await tapOpenDuoTab(app,screen,tab,name);
    else await tapTab(screen,name);
    const destination=screen.getByTestId(content);
    await scrollMainContent(screen,device,destination);
    await expect(destination).toBeVisible();
    await captureState(app,`${pose}-${id}`,'Original navigation identifier and correct destination');
   }
  }
 } finally {
  await device.fold('closed');
 }
});
