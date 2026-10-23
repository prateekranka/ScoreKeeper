import {readFile} from 'node:fs/promises';
import {tapOpenDuoTab,screenshotPath} from './handwriting-duo-input';
import {scrollMainContent} from './handwriting-layout-scroll';
import {test, type Device} from '@e2e-dev/mobile';
import {expect, type Screen} from 'e2e';
import {execFileSync} from 'node:child_process';
import {foldIfSupported,captureState, tapTab, tapNativeControl, enterKeyboardText, visibleDeckPlayer, pressReturnKey, type ScreenshotApp} from './handwriting-helpers';
import {openRoundDeck, manualScoreForCurrentPlayer} from './native-glass-flows';

const bundle='com.icequeen.scorekeeper';
const names=['aleksandra wiśniewska-kowalczyk','christopher alexander montgomery iii','konstantin oberhauser-wettstein','jo','j','ólafur darri ólafsson','đặng thị ngọc hân','王秀英','نور الهدى عبد الرحمن',"seán o'brien-ó súilleabháin",'maría josé de la cruz y fernández','dana','🦊 fox','👩🏽‍💻 priya','ferdinand-habsburg-lothringen'];
function contentSize(value?:string):string {
 return execFileSync('xcrun',['simctl','ui',process.env.PIPCOUNT_DEVICE!,'content_size',...(value?[value]:[])],{encoding:'utf8',timeout:10000}).trim();
}
async function openFixture(device:Device,screen:Screen){
 await device.installApp();
 await device.openApp(bundle,{relaunch:true,launchArguments:['-in-memory-store','-unlock-pro','-force-light-theme','-break-ui-data','-hasSeenScoreDeckTutorial','YES']});
 await expect(screen.getByTestId('tab_home')).toBeVisible();
}
async function selectData(app:ScreenshotApp,screen:Screen,mode:string){
 for(let attempt=0;attempt<4 && !(await screen.getByTestId('legal_support_button').isVisible());attempt++){
  const islandBack=screen.getByTestId('island_back_button');
  await tapNativeControl(screen,await islandBack.isVisible()?islandBack:screen.getByTestId('BackButton').first());
 }
 await tapTab(screen,'More');
 const menu=screen.getByTestId('break_ui_data_toggle');
 await screen.scrollUntilVisible(menu);
 await tapNativeControl(screen,menu);
 await expect(screen.getByTestId(`break_ui_data_${mode}`)).toBeVisible();
 await screen.getByTestId(`break_ui_data_${mode}`).tap();
 await expect(screen.getByTestId('tab_home')).toBeVisible();
 await captureState(app,`break-${mode}-home`,'Native Home after selecting '+mode+' in-memory data');
}

async function resumeBySlide(screen:Screen,device:Device,wide=false){
 const active=screen.getByTestId(/^active_game_/).first();await scrollMainContent(screen,device,active,'down',wide);
 const frame=await active.boundingBox();if(!frame)throw new Error('Resume slider has no current frame');
 await screen.swipe({from:{x:frame.x+30,y:frame.y+frame.height/2},to:{x:frame.x+frame.width-15,y:frame.y+frame.height/2}});
}

async function reduceTransparency(app:ScreenshotApp,screen:Screen,device:Device,checked:boolean){
 await device.openApp('com.apple.Preferences',{relaunch:true});
 const back=screen.getByTestId('BackButton').first();for(let i=0;i<4 && await back.isVisible();i++)await back.tap();
 const access=screen.getByText('Accessibility',{exact:true}).last();await screen.scrollUntilVisible(access);await access.tap();
 await screen.getByText('Display & Text Size',{exact:true}).last().tap();
 const toggle=screen.getByRole('switch','Reduce Transparency',{exact:true});await screen.scrollUntilVisible(toggle);
 const original=await toggle.isChecked();
 if(original!==checked){
  const frame=await toggle.boundingBox();if(!frame)throw new Error('Reduce Transparency has no current frame');
  await screen.swipe({from:{x:frame.x+frame.width-(checked?48:16),y:frame.y+frame.height/2},to:{x:frame.x+frame.width-(checked?16:48),y:frame.y+frame.height/2}});
 }
 await expect(toggle).toBeChecked({checked});await captureState(app,checked?'break-transparency-on':'break-transparency-restored','Actual iOS Reduce Transparency '+(checked?'On':'restored'));
 return original;
}

test('break-ui empty one and 1284-row collections',{timeout:900000},async({app,screen,device})=>{
 await openFixture(device,screen);
 await captureState(app,'break-demo-home','Normal two-player fixture');
 for(const mode of ['empty','one','huge']){
  const began=Date.now();
  await selectData(app,screen,mode);
  console.log(`Fixture ${mode} selection and Home capture: ${Date.now()-began} ms`);
  await tapTab(screen,'Players');
  if(mode==='empty') await expect(screen.getByText('no players saved yet',{exact:true})).toBeVisible();
  else {
   const id=mode==='one'?'saved_player_jo':'saved_player_aleksandra wiśniewska-kowalczyk 1';
   await screen.scrollUntilVisible(screen.getByTestId(id));
   await expect(screen.getByTestId(id)).toBeVisible();
  }
  await captureState(app,`break-${mode}-players`,'Player library with '+mode+' data');
  await tapTab(screen,'Home');
  if(mode==='empty'){
   await tapTab(screen,'More');
   await captureState(app,'break-empty-more','Empty data still permits navigation and settings');
  } else {
   await tapTab(screen,'More');
   const history=screen.getByTestId('see_all_button');
   await screen.scrollUntilVisible(history);await tapNativeControl(screen,history);
   await expect(screen.getByTestId('history_card_0')).toBeVisible();
   await captureState(app,`break-${mode}-history`,'History with '+mode+' collection');
   await tapNativeControl(screen,screen.getByTestId('history_card_0'));
   await expect(screen.getByTestId('game_detail_view')).toBeVisible();
   await captureState(app,`break-${mode}-detail`,'Game detail from '+mode+' history');
  }
 }
 await selectData(app,screen,'demo');
 await tapTab(screen,'Games');await expect(screen.getByTestId('game_tile_generic')).toBeVisible();
 await captureState(app,'break-demo-restored-games','Normal data and native navigation still work after huge data');
});

test('break-ui multilingual 15-player scorecard at AX5 in light and dark',{timeout:900000},async({app,screen,device})=>{
 const original=contentSize();
 let originalTransparency:boolean|undefined;
 try{
  if(process.env.PIPCOUNT_BREAK_TRANSPARENCY)originalTransparency=await reduceTransparency(app,screen,device,true);
  contentSize('accessibility-extra-extra-extra-large');
  expect(contentSize()).toBe('accessibility-extra-extra-extra-large');
  await openFixture(device,screen);
  for(const appearance of ['light','dark'].filter(v=>!process.env.PIPCOUNT_BREAK_APPEARANCE || v===process.env.PIPCOUNT_BREAK_APPEARANCE)){
   await tapTab(screen,'More');
   const theme=screen.getByTestId(`theme_${appearance}_button`);await screen.scrollUntilVisible(theme);await tapNativeControl(screen,theme);
   await selectData(app,screen,'worst');
   await tapTab(screen,'Players');
   if(!process.env.PIPCOUNT_BREAK_SCORE_ONLY) for(const name of [names[0],names[5],names[6],names[7],names[8],names[12],names[13]].filter(value=>!process.env.PIPCOUNT_BREAK_CRITICAL_NAMES || value===names[0])){
    const card=screen.getByTestId('saved_player_'+name);await scrollMainContent(screen,device,card,'down',false,true);await expect(card).toBeVisible();
    if(name===names[0]){
     const frame=await card.boundingBox();expect(frame?.height).toBeLessThan(450);
    }
    await captureState(app,`break-worst-${appearance}-name-${names.indexOf(name)}`,'AX5 player row for '+name);
   }
   if(!process.env.PIPCOUNT_BREAK_SCORE_ONLY){
    const missing=screen.getByTestId('saved_player_');await scrollMainContent(screen,device,missing,'down',false,true,40);await expect(missing).toBeVisible();
    await expect(screen.getByText('unnamed player',{exact:true}).last()).toBeVisible();
    await captureState(app,`break-worst-${appearance}-missing-name`,'Empty stored name has the unnamed player fallback');
    await tapNativeControl(screen,missing);await expect(screen.getByTestId('player_stats_view').last()).toBeVisible();
    await expect(screen.getByText('unnamed player',{exact:true}).last()).toBeVisible();
    await captureState(app,`break-worst-${appearance}-missing-name-history`,'The same fallback identifies the player history');
    await selectData(app,screen,'worst');
   }
   if(process.env.PIPCOUNT_BREAK_ROSTER_ONLY)continue;
   await tapTab(screen,'Home');
   await resumeBySlide(screen,device);
   const scoringScroll=screen.getByTestId(/^scoring_(accessible|content)_scroll$/, {visible:true});
   await expect(scoringScroll).toBeVisible();
   const submit=screen.getByTestId('submit_round_button').last();
   if(!(await screen.getByTestId('navigation_island').isVisible())) await scoringScroll.scrollUntilVisible(submit,{timeout:30000});
   await scrollMainContent(screen,device,submit,'down',false,true);
   const submitFrame=await submit.boundingBox();expect(submitFrame?.width).toBeGreaterThanOrEqual(44);expect(submitFrame?.height).toBeGreaterThanOrEqual(44);
   await captureState(app,`break-worst-${appearance}-score-round-reachable`,'Score Round is reachable before all 50 rounds of history');
   await tapNativeControl(screen,submit);
   await expect(screen.getByTestId('round_entry_deck')).toBeVisible();
   const gotIt=screen.getByRole('button','got it',{exact:true});if(await gotIt.isVisible())await gotIt.tap();
   const typeScore=screen.getByTestId('deck_type_score_button');await scrollMainContent(screen,device,typeScore,'down',false,true,40);
   await tapNativeControl(screen,typeScore);
   const field=screen.getByTestId('deck_manual_value');await enterKeyboardText(screen,field,'99');await expect(field).toHaveValue('99');
   const keyboardIdentity=await screen.getByTestId('deck_keyboard_player').textContent();
   const current=names.find(name=>keyboardIdentity===`Score for ${name}`);if(!current)throw new Error('The keyboard does not identify a fixture player: '+keyboardIdentity);
   await captureState(app,`break-worst-${appearance}-keyboard-99`,'AX5 upper valid score boundary and full player identity');
   const done=screen.getByTestId('deck_keyboard_done');await tapNativeControl(screen,done);await expect(screen.getByTestId('inputView')).toBeHidden();
   const use=screen.getByTestId('deck_manual_use_'+current);await scrollMainContent(screen,device,use,'down',false,true);await expect(use).toBeEnabled();
   await captureState(app,`break-worst-${appearance}-use-99`,'The valid draft remains available after keyboard dismissal');
   const cancel=screen.getByTestId('round_deck_cancel_button');await scrollMainContent(screen,device,cancel,'up',false,true,40);await tapNativeControl(screen,cancel);
   await expect(screen.getByTestId('round_entry_deck')).toBeHidden();
   const high=screen.getByTestId('running_total_'+names[0]);
   await scoringScroll.scrollUntilVisible(high,{timeout:120000});await expect(high).toHaveText('4,950');
   await captureState(app,`break-worst-${appearance}-total-4950`,'Fifteen players and 50 rounds; long name beside exact unchanged total 4950');
   await captureState(app,`break-worst-${appearance}-cancelled`,'Cancelling uncommitted score leaves the saved total unchanged');
  }
 }catch(error){
  await captureState(app,'break-worst-failure-before-restoration',String(error));throw error;
 }finally{
  contentSize(original);expect(contentSize()).toBe(original);
  if(originalTransparency!==undefined)await reduceTransparency(app,screen,device,originalTransparency);
  await device.openApp(bundle,{relaunch:true,launchArguments:['-in-memory-store','-force-light-theme','-unlock-pro','-break-ui-data']});
 }
});

test('break-ui invalid manual values and recoverable store failure',{timeout:600000},async({app,screen,device})=>{
 await device.installApp();
 await device.openApp(bundle,{relaunch:true,launchArguments:['-in-memory-store','-force-light-theme','-force-store-open-failure-once','-unlock-pro']});
 await expect(screen.getByTestId('startup_retry_button')).toBeVisible();
 await captureState(app,'break-store-failure','Real debug seam shows a recoverable store-open error');
 await screen.getByTestId('startup_retry_button').tap();
 await expect(screen.getByTestId('new_game_button')).toBeVisible();
 await captureState(app,'break-store-retry','Retry opens Home without deleting data');
 await tapTab(screen,'Games');await tapNativeControl(screen,screen.getByTestId('game_tile_generic'));
 const firstName=screen.getByTestId('player_name_field_0');const secondName=screen.getByTestId('player_name_field_1');
 await expect(screen.getByTestId('start_game_button').last()).toBeDisabled();
 await firstName.fill('J');await pressReturnKey(screen);await secondName.fill('j');
 await expect(screen.getByText('player names must be unique',{exact:true})).toBeVisible();
 await expect(screen.getByTestId('start_game_button').last()).toBeDisabled();
 await captureState(app,'break-duplicate-name','Case-insensitive duplicate J/j cannot continue');
 await secondName.fill('Đặng Thị Ngọc Hân');await expect(secondName).toHaveValue('Đặng Thị Ngọc Hân');await pressReturnKey(screen);
 await screen.getByTestId('start_game_button').last().tap();
 const target=screen.getByTestId('target_score_field');
 for(const invalid of ['0','99999999999999999999']){
  await target.fill(invalid);await expect(screen.getByTestId('target_score_error')).toBeVisible();await expect(screen.getByTestId('start_game_button').last()).toBeDisabled();
  await captureState(app,'break-target-invalid-'+invalid,'Invalid target score '+invalid+' cannot start');
 }
 await target.fill('1000000');await expect(target).toHaveValue('1000000');await expect(screen.getByTestId('target_score_error')).toBeHidden();
 const startCapture=await captureState(app,'break-target-large-keyboard','Actual Start Game remains above the number keyboard');
 const png=await readFile(await screenshotPath(startCapture));expect(png.readUInt32BE(16)).toBe(402);expect(png.readUInt32BE(20)).toBe(874);
 await expect(screen.getByTestId('start_game_button').last()).toBeEnabled();
 await screen.tapAt({x:201,y:523});
 await expect(screen.getByTestId('submit_round_button').last()).toBeVisible();
 const current=await openRoundDeck(app,screen,['J','Đặng Thị Ngọc Hân'],'break-boundary');
 await tapNativeControl(screen,screen.getByTestId('deck_type_score_button'));
 const field=screen.getByTestId('deck_manual_value');const use=screen.getByTestId('deck_manual_use_'+current);
 for(const raw of ['100','-1','1.5','99999999999999999999']){
  await field.fill(raw);await expect(field).toHaveValue(raw);await expect(use).toBeDisabled();await expect(screen.getByTestId('deck_manual_range_hint')).toBeVisible();
  await captureState(app,'break-invalid-'+raw.replaceAll('.','point'),'Manual input rejects raw value '+raw);
 }
 await field.fill('0');await expect(use).toBeEnabled();await expect(screen.getByTestId('deck_manual_range_hint')).toBeHidden();
 await captureState(app,'break-valid-zero','Zero is accepted after invalid input');
 await tapNativeControl(screen,use);
 const second=await visibleDeckPlayer(screen,['J','Đặng Thị Ngọc Hân']);
 await manualScoreForCurrentPlayer(app,screen,second,99,'break-boundary',false);
 await expect(screen.getByTestId('round_entry_deck')).toBeHidden();
 await expect(screen.getByTestId('running_total_'+current)).toHaveText('0');await expect(screen.getByTestId('running_total_'+second)).toHaveText('99');
 await captureState(app,'break-boundaries-saved','Exact scores zero and 99 saved without ending the million-point game');
});

test('break-ui wide Duo data containers',{timeout:600000},async({app,screen,device})=>{
 if(!process.env.PIPCOUNT_BREAK_WIDE) test.skip('Separate wide device run');
 try{
  await openFixture(device,screen);await selectData(app,screen,'worst');await foldIfSupported(device, 'open');
  await expect(screen.getByTestId('tab_home')).toBeVisible();
  await expect(screen.getByTestId(/^sidebar_/)).toBeHidden();
  await expect(screen.getByRole('button',/^Show Sidebar$/i)).toBeHidden();
  await captureState(app,'break-wide-worst-home','Full-width native-tab Home in the widest available Duo container');
  const title=screen.getByTestId(/^active_title_/).first();await scrollMainContent(screen,device,title,'down',true,true);
  const titleFrame=await title.boundingBox();const statusFrame=await screen.getByTestId(/^active_status_/).first().boundingBox();
  expect(titleFrame?.height).toBeLessThan(45);expect(statusFrame?.height).toBeLessThan(40);
  await captureState(app,'break-wide-worst-active-game','Active-game title and status remain on one line without a sidebar');
  await tapOpenDuoTab(app,screen,screen.getByTestId('tab_players'),'Players');
  const first=screen.getByTestId('saved_player_'+names[0]);await screen.scrollUntilVisible(first);await expect(first).toBeVisible();
  await captureState(app,'break-wide-worst-players','Mixed long-name cards inside the actual wide detail container');
 }catch(error){
  await captureState(app,'break-wide-failure-before-restoration',String(error));throw error;
 }finally{
  await foldIfSupported(device, 'closed');
  await device.openApp(bundle,{relaunch:true,launchArguments:['-in-memory-store','-force-light-theme','-unlock-pro','-break-ui-data']});
 }
});

test('break-ui restore and verify original system settings',{timeout:300000},async({app,screen,device})=>{
 if(!process.env.PIPCOUNT_BREAK_ORIGINAL_SETTINGS)test.skip('Separate environment restoration run');
 const original=JSON.parse(await readFile(process.env.PIPCOUNT_BREAK_ORIGINAL_SETTINGS!,'utf8'));
 await device.installApp();contentSize(original.originalContentSize);
 await reduceTransparency(app,screen,device,original.originalTransparency);
 const larger=screen.getByTestId('LARGER_TEXT').last();await screen.scrollUntilVisible(larger,{direction:'up'});await larger.tap();
 const toggle=screen.getByRole('switch','Larger Accessibility Sizes',{exact:true});await expect(toggle).toBeVisible();
 await expect(screen.getByRole('slider').last()).toBeVisible();
 if(await toggle.isChecked()!==original.originalLarger){
  const frame=await toggle.boundingBox();if(!frame || frame.width<64 || frame.height<=0)throw new Error('System switch has no current row frame');
  const point={x:frame.x+frame.width-32,y:frame.y+frame.height/2};
  console.log('Larger Accessibility Sizes row and trailing switch point',frame,point);
  await captureState(app,'break-system-switch-before-restoration','Current native switch before restoring the recorded original setting');
  await screen.tapAt(point);
 }
 await expect(toggle).toBeChecked({checked:original.originalLarger});
 await expect(screen.getByRole('slider').last()).toHaveValue(original.originalValue);
 expect(contentSize()).toBe(original.originalContentSize);
 await captureState(app,'break-original-system-text-restored','Original real system text slider and accessibility range restored');
 await openFixture(device,screen);
 await captureState(app,'break-final-demo-home','Stress data removed; normal Demo data and original system settings');
});
