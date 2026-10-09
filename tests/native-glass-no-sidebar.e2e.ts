import {readFile} from 'node:fs/promises';
import {test} from '@e2e-dev/mobile';
import {expect} from 'e2e';
import {captureState,tapNativeControl,tapTab,enterKeyboardText,visibleDeckPlayer} from './handwriting-helpers';
import {scrollMainContent} from './handwriting-layout-scroll';
import {tapOpenDuoTab,screenshotPath} from './handwriting-duo-input';

const bundle='com.icequeen.scorekeeper';
const tabs=[['Home','tab_home','new_game_button'],['Games','tab_games','game_tile_generic'],['Players','tab_players','saved_player_maya'],['More','legal_support_button','theme_light_button']] as const;

test('wide root destinations use native tabs without a persistent sidebar',{timeout:600000},async({app,screen,device})=>{
 try{
  await device.installApp();
  await device.openApp(bundle,{relaunch:true,launchArguments:['-in-memory-store','-unlock-pro','-force-light-theme','-break-ui-data']});
  await device.fold('open');
  const initial=await captureState(app,'wide-initial-home','Demo data in the open Duo window');
  const png=await readFile(await screenshotPath(initial));expect({width:png.readUInt32BE(16),height:png.readUInt32BE(20)}).toEqual({width:951,height:669});
  for(const [name,id,marker] of tabs){
   await expect(screen.getByTestId(/^sidebar_/)).toBeHidden();
   await expect(screen.getByRole('button',/^(Show|Hide) Sidebar$/i)).toBeHidden();
   await tapOpenDuoTab(app,screen,screen.getByTestId(id),name);
   const content=screen.getByTestId(marker);await scrollMainContent(screen,device,content,'down',true);
   await expect(content).toBeVisible();
   await captureState(app,`wide-root-${name.toLowerCase()}`,`${name}: same Demo fixture and 951 by 669 window; native tabs with full content width`);
  }
  await tapOpenDuoTab(app,screen,screen.getByTestId('tab_home'),'Home');await expect(screen.getByTestId('new_game_button')).toBeVisible();
  await device.fold('closed');
  for(const [name,,marker] of tabs){
   await tapTab(screen,name);const content=screen.getByTestId(marker);await scrollMainContent(screen,device,content);
   await expect(content).toBeVisible();await captureState(app,`folded-root-${name.toLowerCase()}`,'Native tabs remain available after folding');
  }
 }finally{
  await device.fold('closed');
  await device.openApp(bundle,{relaunch:true,launchArguments:['-in-memory-store','-unlock-pro','-force-light-theme','-break-ui-data']});
 }
});

test('game route and manual score draft survive a Duo fold',{timeout:600000},async({app,screen,device})=>{
 try{
  await device.installApp();await device.openApp(bundle,{relaunch:true,launchArguments:['-in-memory-store','-unlock-pro','-force-light-theme','-break-ui-data','-hasSeenScoreDeckTutorial','YES']});
  const resume=screen.getByTestId(/^active_game_/).first();await scrollMainContent(screen,device,resume);
  const frame=await resume.boundingBox();if(!frame)throw new Error('Resume has no current frame');
  await screen.swipe({from:{x:frame.x+30,y:frame.y+frame.height/2},to:{x:frame.x+frame.width-15,y:frame.y+frame.height/2}});
  await expect(screen.getByTestId('submit_round_button').last()).toBeVisible();
  await captureState(app,'folded-active-game','Existing round 2 before opening the Duo');
  await device.fold('open');await expect(screen.getByTestId('submit_round_button').last()).toBeVisible();
  await expect(screen.getByTestId('running_total_maya')).toHaveText('7');await expect(screen.getByTestId('running_total_leo')).toHaveText('9');
  await expect(screen.getByTestId(/^sidebar_/)).toBeHidden();
  await captureState(app,'wide-active-game','The same game route and saved totals survive opening the Duo');
  await device.fold('closed');await expect(screen.getByTestId('submit_round_button').last()).toBeVisible();
  await tapNativeControl(screen,screen.getByTestId('submit_round_button').last());await expect(screen.getByTestId('round_entry_deck')).toBeVisible();
  const player=await visibleDeckPlayer(screen,['maya','leo']);
  await tapNativeControl(screen,screen.getByTestId('deck_type_score_button'));
  const field=screen.getByTestId('deck_manual_value');await enterKeyboardText(screen,field,'46');await expect(field).toHaveValue('46');
  await captureState(app,'folded-manual-draft','Uncommitted score 46 before opening the Duo');
  await device.fold('open');await expect(screen.getByTestId('round_entry_deck')).toBeVisible();await expect(field).toHaveValue('46');
  await expect(screen.getByTestId('deck_manual_use_'+player)).toBeEnabled();
  await captureState(app,'wide-manual-draft','The same player and score draft survive opening the Duo');
  await device.fold('closed');await expect(field).toHaveValue('46');
  await captureState(app,'refolded-manual-draft','Score draft remains 46 after folding again');
  await tapNativeControl(screen,screen.getByTestId('round_deck_cancel_button'));await expect(screen.getByTestId('round_entry_deck')).toBeHidden();
  await expect(screen.getByTestId('running_total_maya')).toHaveText('7');await expect(screen.getByTestId('running_total_leo')).toHaveText('9');
  await captureState(app,'fold-cancel-unchanged-totals','Cancel leaves the original saved round unchanged');
 }finally{
  await device.fold('closed');await device.openApp(bundle,{relaunch:true,launchArguments:['-in-memory-store','-unlock-pro','-force-light-theme','-break-ui-data']});
 }
});
