import {readFile} from 'node:fs/promises';
import {test} from '@e2e-dev/mobile';
import {expect} from 'e2e';
import {foldIfSupported,captureState,tapNativeControl,tapTab,enterKeyboardText,visibleDeckPlayer} from './handwriting-helpers';
import {scrollMainContent} from './handwriting-layout-scroll';
import {tapOpenDuoTab,screenshotPath,assertIslandLayout,assertClearOfIsland} from './handwriting-duo-input';

const bundle='com.icequeen.scorekeeper';
const pose=process.env.PIPCOUNT_NO_FOLD?'default':process.env.PIPCOUNT_DUO_POSE ?? 'default';
const openSize=pose==='default'?undefined:pose==='inner-portrait'?{width:669,height:951}:{width:951,height:669};
const tabs=[['Home','tab_home','new_game_button'],['Games','tab_games','game_tile_generic'],['Players','tab_players','saved_player_maya'],['More','legal_support_button','theme_light_button']] as const;

test('wide roots use one bottom trailing island and folded roots use native tabs',{timeout:600000},async({app,screen,device})=>{
 try{
  await device.installApp();
  await device.openApp(bundle,{relaunch:true,launchArguments:['-in-memory-store','-unlock-pro','-force-light-theme','-break-ui-data']});
  if(pose!=='default') await foldIfSupported(device, 'open');
  const initial=await captureState(app,'wide-initial-home','Demo data in the open Duo window');
  const png=await readFile(await screenshotPath(initial));
  if(openSize) expect({width:png.readUInt32BE(16),height:png.readUInt32BE(20)}).toEqual(openSize);
  await expect(screen.getByTestId('break_ui_data_toggle')).toBeHidden();
  if(pose==='default') await assertIslandLayout(screen,screen.getByTestId('home_content_scroll'),Number(process.env.PIPCOUNT_DUO_WINDOW_WIDTH ?? '466'));
  for(const [name,id,marker] of tabs){
   await expect(screen.getByTestId('navigation_island')).toHaveCount(1);
   await expect(screen.getByRole('tablist')).toBeHidden();
   await expect(screen.getByTestId(/^sidebar_/)).toBeHidden();
   await expect(screen.getByRole('button',/^(Show|Hide) Sidebar$/i)).toBeHidden();
   await tapOpenDuoTab(app,screen,screen.getByTestId(id),name);
   if(name==='More') {
    await expect(screen.getByTestId('theme_light_button')).toBeVisible();
    await expect(screen.getByText('PipCount Pro',{exact:true})).toBeHidden();
    await expect(screen.getByTestId('more_upgrade_button')).toBeHidden();
    await expect(screen.getByTestId('pro_unlocked_status')).toBeHidden();
   }
   const primary=name==='Home'?screen.getByTestId(/^active_game_/).first()
    :screen.getByTestId(name==='Games'?'game_tile_generic':name==='Players'?'add_new_player_button':'theme_light_button');
   await assertClearOfIsland(screen,primary);
   if(name==='Home') await assertClearOfIsland(screen,screen.getByTestId('new_game_button'));
   await captureState(app,`wide-root-${name.toLowerCase()}-at-rest`,`${name}: primary action clears the island before scrolling`);
   const content=screen.getByTestId(marker);await scrollMainContent(screen,device,content,'down',true);
   await expect(content).toBeVisible();
   const lastControl=name==='Home'?screen.getByRole('button','learn about undo',{exact:true})
    :screen.getByTestId(name==='Games'?'game_tile_whatsForDinner':name==='Players'?'saved_player_leo':'support_link');
   await scrollMainContent(screen,device,lastControl,'down',true,true);
   await assertClearOfIsland(screen,lastControl);
   await captureState(app,`wide-root-${name.toLowerCase()}`,`${name}: same Demo fixture and selected open pose; bottom trailing island with native tabs hidden`);
  }
  await tapOpenDuoTab(app,screen,screen.getByTestId('tab_home'),'Home');
  await scrollMainContent(screen,device,screen.getByTestId('new_game_button'),'up',true);
  await expect(screen.getByTestId('new_game_button')).toBeVisible();
  await foldIfSupported(device, 'closed');
  if (!process.env.PIPCOUNT_NO_FOLD) {
  await expect(screen.getByTestId('navigation_island')).toBeHidden();
  for(const [name,,marker] of tabs){
   await tapTab(screen,name);const content=screen.getByTestId(marker);await scrollMainContent(screen,device,content);
   await expect(content).toBeVisible();await captureState(app,`folded-root-${name.toLowerCase()}`,'Native tabs remain available after folding');
  }
  }
 }finally{
  await foldIfSupported(device, 'closed');
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
  await foldIfSupported(device, 'open');await expect(screen.getByTestId('submit_round_button').last()).toBeVisible();
  await expect(screen.getByTestId('running_total_maya')).toHaveText('7');await expect(screen.getByTestId('running_total_leo')).toHaveText('9');
  await expect(screen.getByTestId(/^sidebar_/)).toBeHidden();
  await expect(screen.getByTestId('navigation_island')).toHaveCount(1);
  await expect(screen.getByTestId('tab_home')).toBeHidden();
  await expect(screen.getByTestId('island_back_button')).toBeVisible();
  await expect(screen.getByTestId('scoring_tools_button')).toBeVisible();
  await expect(screen.getByTestId('undo_last_round_button')).toBeVisible();
  await assertIslandLayout(screen,screen.getByTestId('scoring_content_scroll'));
  await captureState(app,'wide-active-game','The same game route and saved totals survive opening the Duo');
  await foldIfSupported(device, 'closed');await expect(screen.getByTestId('submit_round_button').last()).toBeVisible();
  await tapNativeControl(screen,screen.getByTestId('submit_round_button').last());await expect(screen.getByTestId('round_entry_deck')).toBeVisible();
  const player=await visibleDeckPlayer(screen,['maya','leo']);
  await tapNativeControl(screen,screen.getByTestId('deck_type_score_button'));
  const field=screen.getByTestId('deck_manual_value');await enterKeyboardText(screen,field,'46');await expect(field).toHaveValue('46');
  await captureState(app,'folded-manual-draft','Uncommitted score 46 before opening the Duo');
  await foldIfSupported(device, 'open');await expect(screen.getByTestId('round_entry_deck')).toBeVisible();await expect(field).toHaveValue('46');
  await expect(screen.getByTestId('deck_manual_use_'+player)).toBeEnabled();
  await captureState(app,'wide-manual-draft','The same player and score draft survive opening the Duo');
  await foldIfSupported(device, 'closed');await expect(field).toHaveValue('46');
  await captureState(app,'refolded-manual-draft','Score draft remains 46 after folding again');
  await tapNativeControl(screen,screen.getByTestId('round_deck_cancel_button'));await expect(screen.getByTestId('round_entry_deck')).toBeHidden();
  await expect(screen.getByTestId('running_total_maya')).toHaveText('7');await expect(screen.getByTestId('running_total_leo')).toHaveText('9');
  await captureState(app,'fold-cancel-unchanged-totals','Cancel leaves the original saved round unchanged');
  await foldIfSupported(device, 'open');
  await screen.getByTestId('scoring_tools_button').tap();
  await screen.getByTestId('end_game_button').tap();
  await screen.getByRole('button','end game',{exact:true}).last().tap();
  await expect(screen.getByText('leo wins',{exact:true})).toBeVisible();
  await assertIslandLayout(screen,screen.getByTestId('game_over_content_scroll'));
  for(const id of ['home_button','play_again_button','share_game_recap_button']) await expect(screen.getByTestId(id)).toBeVisible();
  await expect(screen.getByTestId('tab_home')).toBeHidden();
  await captureState(app,'wide-game-over-island','Back, rematch and share replace root destinations in the trailing island');
 }finally{
  await foldIfSupported(device, 'closed');await device.openApp(bundle,{relaunch:true,launchArguments:['-in-memory-store','-unlock-pro','-force-light-theme','-break-ui-data']});
 }
});
