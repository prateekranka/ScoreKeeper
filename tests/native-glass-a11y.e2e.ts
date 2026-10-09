import { test } from '@e2e-dev/mobile';
import { expect } from 'e2e';
import { captureState, tapNativeControl, enterKeyboardText, pressReturnKey, visibleDeckPlayer } from './handwriting-helpers';
import { scrollMainContent } from './handwriting-layout-scroll';
import { tapOpenDuoControl, tapOpenDuoTab, screenshotPath } from './handwriting-duo-input';
import { enterOpenDuoText, submitOpenDuoName } from './handwriting-duo-keyboard';
import { writeFile, readFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';

const bundle='com.icequeen.scorekeeper';
// Native simulator configuration arranges/restores the environment. Every app
// interaction and assertion stays in TesterArmy e2e.
function systemContentSize(value?:string):string {
 const udid=process.env.PIPCOUNT_DEVICE??'E00E0899-9FCB-49BE-9D05-E469A89371EA';
 return execFileSync('xcrun',['simctl','ui',udid,'content_size',...(value?[value]:[])],{
  encoding:'utf8',timeout:10_000,env:{...process.env,DEVELOPER_DIR:'/Applications/Xcode-27.1-beta.app/Contents/Developer'}
 }).trim();
}
async function setSystemSwitch(screen:any,control:any,checked:boolean){
 await expect(control).toBeVisible();
 if(await control.isChecked()!==checked){
  const row=await control.boundingBox(); if(!row) throw new Error('System switch has no current frame');
  console.log('System switch row',row,'before',await control.inputValue());
  const y=row.y+row.height/2;
  if(checked) await control.tap({position:{x:row.width-25,y:row.height/2}});
  else await screen.swipe({from:{x:row.x+row.width-16,y},to:{x:row.x+row.width-48,y}});
  console.log('System toggle after',await control.inputValue());
 }
 await expect(control).toBeChecked({checked});
}
async function setSystemSlider(screen:any,slider:any,percentage:number){
 const bounds=await slider.boundingBox(); if(!bounds) throw new Error('System slider has no current frame');
 const current=Number.parseFloat(await slider.inputValue())/100;
 if(Math.round(current*100)===percentage) return;
 console.log('System slider',bounds,'before',await slider.inputValue());
 // Begin on the thumb, then drag to the requested stop. The track excludes its A labels.
 const left=bounds.x+48, right=bounds.x+bounds.width-48;
 await screen.swipe({from:{x:left+(right-left)*current,y:bounds.y+bounds.height/2},to:{x:left+(right-left)*percentage/100,y:bounds.y+bounds.height/2}});
 console.log('System slider after',await slider.inputValue());
}
async function tapSystemRow(app:any,screen:any,control:any,label:string){
 const png=await readFile(await screenshotPath(await app.screenshot(`system-${label}-navigation-reference`)));
 const height=png.readUInt32BE(20), width=png.readUInt32BE(16);
 const drag=async(down:boolean)=>screen.swipe({from:{x:24,y:height/2+(down?60:-60)},to:{x:24,y:height/2+(down?-60:60)}});
 let down=true;
 for(let i=0;i<36;i++){
  if(await control.isVisible()){
   const bounds=await control.boundingBox(); const y=bounds.y+bounds.height/2;
   if(y>=120 && y<=height-100) {
    const point={x:bounds.x+bounds.width-34,y};
    console.log('System row point',label,bounds,point);
    await control.tap({position:{x:bounds.width-34,y:bounds.height/2}}); return;
   }
   await drag(y>=120);
  } else {
   const bar=screen.getByLabel(/^Vertical scroll bar/).first();
   const position=await bar.isVisible()?Number.parseFloat(await bar.inputValue()):0;
   if(position>=99) down=false; else if(position<=1) down=true;
   console.log("Settings scan",label,i,position,down);
   await drag(down);
  }
 }
 throw new Error(`System settings control is not reachable: ${label}`);
}
async function openSystemTextPage(app:any,screen:any,device:any){
 if(await screen.getByRole('slider').last().isVisible()) return;
 const larger=screen.getByTestId('LARGER_TEXT').last();
 if(await larger.isVisible()) {await tapSystemRow(app,screen,larger,'larger-text'); await expect(screen.getByRole('slider').last()).toBeVisible(); return;}
 const displayRow=screen.getByTestId('DISPLAY_AND_TEXT').last();
 if(await displayRow.isVisible()){await tapSystemRow(app,screen,displayRow,'display-text'); await expect(screen.getByTestId('LARGER_TEXT').last()).toBeVisible(); await tapSystemRow(app,screen,screen.getByTestId('LARGER_TEXT').last(),'larger-text'); await expect(screen.getByRole('slider').last()).toBeVisible(); return;}
 const back=screen.getByTestId('BackButton').first(); for(let i=0;i<4 && await back.isVisible();i++) await back.tap();
 await tapSystemRow(app,screen,screen.getByRole('button','Accessibility',{exact:true}).last(),'accessibility');
 await expect(screen.getByTestId('Accessibility')).toBeVisible();
 await tapSystemRow(app,screen,screen.getByTestId('DISPLAY_AND_TEXT').last(),'display-text');
 await expect(screen.getByTestId('Display & Text Size')).toBeVisible();
 await tapSystemRow(app,screen,screen.getByTestId('LARGER_TEXT').last(),'larger-text');
 await expect(screen.getByRole('slider').last()).toBeVisible();
}
const cases=[['compact','light'],['compact','dark'],['inner-portrait','light'],['inner-portrait','dark'],['inner-landscape','light'],['inner-landscape','dark']] as const;

test('largest system text plus Reduce Transparency keeps every layout usable', {timeout:1_800_000}, async ({app,screen,device})=>{
 const recordedOriginal=process.env.PIPCOUNT_SETTINGS_RESTORE_FROM
  ? JSON.parse(await readFile(process.env.PIPCOUNT_SETTINGS_RESTORE_FROM,'utf8')):undefined;
 if(recordedOriginal) systemContentSize(recordedOriginal.originalContentSize);
 const originalContentSize=systemContentSize();
 await device.installApp(); await app.open();
 if(!process.env.PIPCOUNT_PHONE) await device.fold('closed'); await device.setOrientation('portrait');
 await device.openApp('com.apple.Preferences',{relaunch:true});
 console.log('Opened system Settings');
 const rootBack=screen.getByTestId('BackButton').first(); for(let i=0;i<4 && await rootBack.isVisible();i++) await rootBack.tap();
 console.log('Settings root ready');
 const access=screen.getByText('Accessibility',{exact:true}).last(); await screen.scrollUntilVisible(access); await access.tap();
 console.log('Accessibility page ready');
 const display=screen.getByText('Display & Text Size',{exact:true}).last(); await display.tap();
 console.log('Display and Text Size page ready');
 const transparency=screen.getByRole('switch','Reduce Transparency',{exact:true});
 if(!(await transparency.isVisible())) await screen.scrollUntilVisible(transparency);
 if(recordedOriginal) await setSystemSwitch(screen,transparency,recordedOriginal.originalTransparency);
 const originalTransparency=await transparency.isChecked();
 const larger=screen.getByTestId('LARGER_TEXT').last(); await screen.scrollUntilVisible(larger,{direction:'up'}); await larger.tap();
 const largerSwitch=screen.getByRole('switch','Larger Accessibility Sizes',{exact:true});
 await expect(largerSwitch).toBeVisible();
 if(recordedOriginal) await setSystemSwitch(screen,largerSwitch,recordedOriginal.originalLarger);
 const originalLarger=await largerSwitch.isChecked();
 const slider=screen.getByRole('slider').last();
 await expect(slider).toBeVisible();
 if(recordedOriginal){
  await setSystemSlider(screen,slider,Number.parseFloat(recordedOriginal.originalValue));
  await expect(slider).toHaveValue(recordedOriginal.originalValue);
  expect(systemContentSize()).toBe(recordedOriginal.originalContentSize);
 }
 const originalValue=await slider.inputValue();
 await captureState(app,'system-text-size-original','Original system text slider and accessibility range');
 await writeFile(process.env.PIPCOUNT_SETTINGS_RECORD!,JSON.stringify({originalTransparency,originalLarger,originalValue,originalContentSize},null,2));
 try {
  await screen.getByTestId('BackButton').first().tap();
  if(!(await transparency.isVisible())) await screen.scrollUntilVisible(transparency); await setSystemSwitch(screen,transparency,true);
  await captureState(app,'system-reduce-transparency-on','Real iOS Reduce Transparency is On');
  await screen.getByTestId('LARGER_TEXT').last().tap();
  await setSystemSwitch(screen,largerSwitch,true);
  systemContentSize('accessibility-extra-extra-extra-large');
  await expect(slider).toHaveValue('100%');
  await captureState(app,'system-text-size-largest','System text slider at the largest accessibility value');
  await expect(slider).toHaveValue('100%');
  console.log('Largest system slider',await slider.inputValue(),'actual category',systemContentSize());
  expect(systemContentSize()).toBe('accessibility-extra-extra-extra-large');
  for(const [pose,appearance] of cases.filter(([pose,appearance])=>pose===(process.env.PIPCOUNT_A11Y_POSE??'compact') && (!process.env.PIPCOUNT_A11Y_APPEARANCE || appearance===process.env.PIPCOUNT_A11Y_APPEARANCE))){
   const label=`combined-${pose}-${appearance}`;
   const openLandscape=pose==='inner-landscape';
   // Open the target app before changing display shape. Folding Settings first
   // can leave the beta runner's app clip inherited from the Settings window.
   if(openLandscape) await device.openApp(bundle,{relaunch:false});
   if(!process.env.PIPCOUNT_PHONE) await device.fold(pose==='compact'?'closed':'open');
   // Device Hub sets the inner window pose; its actual PNG dimensions prove it.
   // Sending a redundant sensor rotation to the open beta simulator can block its runner.
   if(pose==='compact') await device.setOrientation('portrait');
   await device.setAppearance(appearance);
   // No Dynamic Type launch override: the app receives the real system setting.
   await device.openApp(bundle,{relaunch:true,launchArguments:['-in-memory-store','-unlock-pro','-themeMode','system']});
   const tap=async(control:any,action:string)=>{
    await expect(control).toBeVisible();
    const bounds=await control.boundingBox();
    console.log('Control frame',action,bounds);
    if(!bounds||(!action.startsWith('close-') && (bounds.width<44||bounds.height<44))) throw new Error(`${action} has less than a 44 by 44 point target`);
    if(openLandscape && action.startsWith('tab-')) return tapOpenDuoTab(app,screen,control,action.slice(4));
    if(action.startsWith('close-') || action.startsWith('utility-') || action.startsWith('tab-')) return control.tap();
    if(openLandscape && await screen.getByTestId('round_entry_deck').isVisible()){
     return control.tap({position:{x:bounds.width/2,y:bounds.height/2}});
    }
    return openLandscape?tapOpenDuoControl(app,screen,control,`${label}-${action}`):tapNativeControl(screen,control);
   };
   const scroll=async(control:any)=>scrollMainContent(screen,device,control,'down',openLandscape);
   // The beta runner can mark the sheet's trailing button hidden against a stale
   // 669-point root even though the actual landscape capture is 951 points wide.
   // A native selector retains this node. Require its fresh, screenshot-contained
   // toolbar frame and verify dismissal; never apply this to another window size.
   const sheetDone=()=>openLandscape?device.locator('role=button label=done').last():screen.getByRole('button',/^done$/i).last();
   const checkSheetDone=async()=>{
    const control=sheetDone();
    if(!openLandscape){await expect(control).toBeVisible();return control;}
    // A foreground-only open keeps the sheet and app data, and refreshes the
    // beta runner's window context before resolving its trailing native button.
    await device.openApp(bundle,{relaunch:false});
    const png=await readFile(await screenshotPath(await app.screenshot(`${label}-sheet-toolbar-reference`)));
    expect({width:png.readUInt32BE(16),height:png.readUInt32BE(20)}).toEqual({width:951,height:669});
    if(await control.count()){
     const bounds=await control.boundingBox();
     if(!bounds || bounds.x<600 || bounds.x+bounds.width>951 || bounds.y<0 || bounds.y+bounds.height>100) throw new Error('Landscape sheet Done is outside its observed toolbar');
     console.log('Landscape native Done frame',bounds);
    }
    return control;
   };
   const closeSheet=async(tool:string,marker:any)=>{
    await expect(marker).toBeVisible();
    const control=await checkSheetDone();
    if(openLandscape){
     // The native in-app back command acts on the live navigation bar directly.
     // A utility sheet has one native bar action: Done. It avoids the clipped
     // projected tree and requires the unique sheet content to disappear.
     await device.back();
     await expect.poll(async()=>await marker.count()).toBe(0);
     await expect.poll(async()=>await sheetDone().count()).toBe(0);
    }else{
     await tap(control,`close-${tool}`); await expect(control).toBeHidden();
    }
   };
   const tab=async(name:string)=>{
    const control=screen.getByTestId(name==='More'?'legal_support_button':`tab_${name.toLowerCase()}`,{visible:true}).last();
    await expect(control).toBeVisible();
    await expect(screen.getByTestId(/^sidebar_/)).toBeHidden();
    await tap(control,`tab-${name}`);
   };
   const homeShot=await captureState(app,`${label}-home`,'Home at largest real system text with Reduce Transparency On');
   const homePng=await readFile(await screenshotPath(homeShot));
   const viewport={width:homePng.readUInt32BE(16),height:homePng.readUInt32BE(20)};
   console.log('Actual app viewport',label,viewport);
   expect(viewport.width>viewport.height).toBe(openLandscape);

   for(const [title,tool] of ((process.env.PIPCOUNT_A11Y_DECK_ONLY || process.env.PIPCOUNT_A11Y_CONFIG_ONLY || process.env.PIPCOUNT_A11Y_NAV_ONLY) ? [] : [['open game timer','timer'],['roll dice','dice'],['pick a random starter','starter'],['learn about undo','undo']])) {
    const control=screen.getByRole('button',title,{exact:true}); await scroll(control); await tap(control,`home-${tool}`);
    await checkSheetDone();
    await captureState(app,`${label}-tool-${tool}`,'Home utility sheet at largest text');
    const headline=screen.getByText(({timer:'keep turns moving',dice:'roll a quick number',starter:'choose who starts',undo:'fix mistakes safely'} as Record<string,string>)[tool],{exact:true});
    await closeSheet(tool,headline);
   }
   if(process.env.PIPCOUNT_A11Y_HOME_ONLY) continue;
   if(!process.env.PIPCOUNT_A11Y_DECK_ONLY && !process.env.PIPCOUNT_A11Y_CONFIG_ONLY){
   await tab('Players'); await captureState(app,`${label}-players`,'Saved players at largest text');
   await tab('More');
   const theme=screen.getByTestId('theme_system_button'); await scroll(theme); await tap(theme,'system-theme');
   await captureState(app,`${label}-more`,'More uses the requested system light or dark appearance');
   }
   await tab('Games'); await captureState(app,`${label}-games`,'Games retains reachable navigation and game controls');
   if(process.env.PIPCOUNT_A11Y_NAV_ONLY) continue;
   const tile=screen.getByTestId('game_tile_generic'); await scroll(tile); await tap(tile,'game');
   const names=['Christopher Alexander Montgomery III','美咲'] as const;
   for(const [i,name] of names.entries()){
    const field=screen.getByTestId(`player_name_field_${i}`); await scroll(field);
    if(openLandscape) await enterOpenDuoText(app,screen,field,name,`${label}-name-${i}`);
    else await enterKeyboardText(screen,field,name);
    if(openLandscape) await submitOpenDuoName(app,screen,`${label}-name-return`);
    else await pressReturnKey(screen);
   }
   await captureState(app,`${label}-setup`,'Long player names and Continue remain usable');
   await tap(screen.getByTestId('start_game_button').last(),'continue');
   await captureState(app,`${label}-settings`,'Game settings and Start remain usable');
   for(const [choice,title] of [['lowest','lowest score wins'],['highest','highest score wins']]){
    const control=screen.getByTestId(`win_condition_choice_${choice}`);await scrollMainContent(screen,device,control,'down',openLandscape,true);await tap(control,`win-${choice}`);
    await expect(screen.getByRole('button',title,{exact:true,selected:true})).toBeVisible();
    await scrollMainContent(screen,device,control,'down',openLandscape,true);
    await captureState(app,`${label}-settings-${choice}`,'Full-size win condition choices are readable and change the selected rule');
   }
   const target=screen.getByTestId('target_score_field');await scroll(target);await expect(target).toBeVisible();
   await captureState(app,`${label}-settings-target`,'Optional target score remains reachable by vertical scrolling');
   if(process.env.PIPCOUNT_A11Y_CONFIG_ONLY) continue;
   await scroll(screen.getByTestId('start_game_button').last());
   await tap(screen.getByTestId('start_game_button').last(),'start');
   const submit=screen.getByTestId('submit_round_button').last(); await scroll(submit); await expect(submit).toBeVisible();
   await captureState(app,`${label}-scoreboard`,'Opaque scorecard with accessible utility actions');
   await expect(screen.getByTestId('undo_last_round_button')).toBeDisabled();
   await scroll(submit); await tap(submit,'open-deck');
   const tutorial=screen.getByRole('button','got it',{exact:true}); if(await tutorial.isVisible()) await tap(tutorial,'tutorial');
   await scroll(screen.getByTestId('score_writing_canvas'));
   await captureState(app,`${label}-deck`,'Handwriting canvas at largest text');
   for(let turn=0;turn<2;turn++){
    await scroll(screen.getByTestId('score_writing_canvas'));
    const current=await visibleDeckPlayer(screen,names);
    const score=current===names[0].toLowerCase()?'7':'9';
    const manual=screen.getByTestId('deck_type_score_button'); await scroll(manual); await tap(manual,'manual');
    const value=screen.getByTestId('deck_manual_value'); await scroll(value);
    if(openLandscape) await enterOpenDuoText(app,screen,value,score,`${label}-score-${score}`);
    else await enterKeyboardText(screen,value,score);
    const done=screen.getByTestId('deck_keyboard_done').last(); await expect(done).toBeVisible();
    await expect(screen.getByTestId('inputView')).toBeVisible();
    await expect(screen.getByTestId('deck_keyboard_player')).toHaveText(`Score for ${current}`);
    await captureState(app,`${label}-keyboard-${score}`,'Software keyboard, current player, and Done at largest text');
    await tap(done,`done-${score}`); await expect(screen.getByTestId('inputView')).toBeHidden();
    const use=screen.getByTestId(`deck_manual_use_${current}`); await scroll(use); await expect(use).toBeEnabled();
    await captureState(app,`${label}-confirm-${score}`,'Full score confirmation action after the keyboard is dismissed');
    await tap(use,`confirm-${score}`);
   }
   await expect(screen.getByTestId('round_entry_deck')).toBeHidden();
   for(const [index,total] of ['7','9'].entries()) {
    const readout=screen.getByTestId(`running_total_${names[index].toLowerCase()}`);
    await scroll(readout); await expect(readout).toHaveText(total);
    await captureState(app,`${label}-saved-total-${total}`,'Verified saved total with its player');
   }
   const history=screen.getByTestId('round_history_1_card'); await scroll(history);
   for(const name of names) await expect(screen.getByTestId(`round_history_1_player_${name.toLowerCase()}`)).toHaveText(name.toLowerCase());
   await captureState(app,`${label}-history`,'Complete round history names and scores at largest text');
   const undo=screen.getByTestId('undo_last_round_button'); await scroll(undo); await expect(undo).toBeEnabled();
   await captureState(app,`${label}-saved`,'Known scores 7 and 9 saved under combined accessibility settings');
   await tap(undo,'undo'); await expect(undo).toBeDisabled();
   for(const name of names) {
    const readout=screen.getByTestId(`running_total_${name.toLowerCase()}`);
    await scroll(readout); await expect(readout).toHaveText('0');
   }
   await captureState(app,`${label}-undo`,'Undo removes the saved round without changing player identity');
   if(process.env.PIPCOUNT_A11Y_DECK_ONLY) continue;
   await device.openApp(bundle,{relaunch:true,launchArguments:['-in-memory-store','-unlock-pro','-themeMode','system']});
   await tab('Games');
   const phase=screen.getByTestId('game_tile_phase10'); await scroll(phase); await tap(phase,'phase');
   for(const [i,name] of ['Maya','Leo'].entries()) {
    const field=screen.getByTestId(`player_name_field_${i}`); await scroll(field);
    if(openLandscape) await enterOpenDuoText(app,screen,field,name,`${label}-phase-name-${i}`);
    else await enterKeyboardText(screen,field,name);
    if(openLandscape) await submitOpenDuoName(app,screen,`${label}-name-return`);
    else await pressReturnKey(screen);
   }
   await scroll(screen.getByTestId('start_game_button').last()); await tap(screen.getByTestId('start_game_button').last(),'phase-continue');
   await scroll(screen.getByTestId('start_game_button').last()); await tap(screen.getByTestId('start_game_button').last(),'phase-start');
   for(const tool of ['timer','dice','starter']){
    const utility=screen.getByRole('button',tool,{exact:true}); await scroll(utility); await tap(utility,`utility-${tool}`);
    const action=screen.getByRole('button',tool==='timer'?'start':tool==='dice'?'roll':'pick starter',{exact:true});
    await scroll(action); await tap(action,`utility-${tool}-primary`);
    if(tool==='timer') {const pause=screen.getByRole('button','pause',{exact:true}); await expect(pause).toBeVisible(); await tap(pause,'timer-pause');}
    await captureState(app,`${label}-scoring-${tool}`,'Scoring utility primary action remains reachable at largest text');
    await closeSheet(`scoring-${tool}`,screen.getByRole('button',tool==='timer'?'start':tool==='dice'?'roll':'pick starter',{exact:true}));

   }

  }
 } catch(error){
  console.error('Accessibility flow failed before restoration',error);
  await captureState(app,'combined-failure-before-restore','Actual app state before restoring system settings');
  throw error;
 } finally {
  systemContentSize(originalContentSize);
  expect(systemContentSize()).toBe(originalContentSize);
  if(!process.env.PIPCOUNT_PHONE) await device.fold('closed'); await device.setOrientation('portrait'); await device.setAppearance('light');
  await device.openApp('com.apple.Preferences',{relaunch:true});
  await openSystemTextPage(app,screen,device);
  const toggle=screen.getByRole('switch','Larger Accessibility Sizes',{exact:true}); await expect(toggle).toBeVisible(); await setSystemSwitch(screen,toggle,originalLarger);
  const size=screen.getByRole('slider').last();
  await setSystemSlider(screen,size,Number.parseFloat(originalValue));
  await expect(size).toHaveValue(originalValue);
  await screen.getByTestId('BackButton').first().tap();
  const reduce=screen.getByRole('switch','Reduce Transparency',{exact:true}); await screen.scrollUntilVisible(reduce);
  await setSystemSwitch(screen,reduce,originalTransparency);
  await expect(reduce).toBeChecked({checked:originalTransparency});
  await captureState(app,'system-settings-restored','System text size and Reduce Transparency restored to their original values');
  await device.openApp(bundle,{relaunch:true,launchArguments:['-in-memory-store','-force-light-theme']});
 }
});
