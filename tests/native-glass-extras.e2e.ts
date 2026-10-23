import {test} from '@e2e-dev/mobile';
import {expect} from 'e2e';
import {captureState,tapNativeControl,tapScoringTool,tapTab,scrollControlAboveTabDock} from './handwriting-helpers';
import {launchFreshJourney,startGameFromHome} from './native-glass-flows';

test('capture utility sheets and the Pro offer',{timeout:360_000},async({app,screen,device})=>{
 if(!process.env.PIPCOUNT_HOME_TOOLS_ONLY){
 if(process.env.PIPCOUNT_CAPTURE_EXISTING) await device.openApp('com.icequeen.scorekeeper',{relaunch:false});
 else {await launchFreshJourney(app,screen,device,['-unlock-pro']); await startGameFromHome(app,screen,'phase10',['Maya','Leo'],'gallery-extras',{device});}
 for(const tool of ['timer','dice','starter']){
  await tapScoringTool(screen,tool);
  const action=screen.getByRole('button',tool==='timer'?'start':tool==='dice'?'roll':'pick starter',{exact:true});
  await screen.scrollUntilVisible(action);
  await captureState(app,`gallery-tool-${tool}`,`${tool} scoring utility sheet`);
  await tapNativeControl(screen,screen.getByRole('button','done',{exact:true}).last());
 }
 }
 await launchFreshJourney(app,screen,device,['-grandfathered','0']);
 for(const [title,tool] of [['open game timer','timer'],['roll dice','dice'],['pick a random starter','starter'],['learn about undo','undo']]){
  const control=screen.getByRole('button',title,{exact:true}); await scrollControlAboveTabDock(screen,control,'tab_home','Home utility'); await tapNativeControl(screen,control);
  await expect(screen.getByRole('button','done',{exact:true}).last()).toBeVisible();
  await captureState(app,`gallery-home-tool-${tool}`,'Home utility sheet');
  await tapNativeControl(screen,screen.getByRole('button','done',{exact:true}).last());
 }
 await tapTab(screen,'More');
 const upgrade=screen.getByTestId('more_upgrade_button'); await screen.scrollUntilVisible(upgrade); await tapNativeControl(screen,upgrade);
 await expect(screen.getByTestId('paywall_title')).toBeVisible();
 await expect(screen.getByTestId(/^paywall_(primary|retry)_button$/)).toBeEnabled({timeout:30_000});
 await captureState(app,'gallery-paywall','Pro offer after StoreKit loads or reports unavailable');
 const mainCloseFrame=await screen.getByTestId('paywall_close_button').boundingBox();
 await tapNativeControl(screen,screen.getByTestId('paywall_close_button'));
 await expect(screen.getByTestId('paywall_gift')).toBeVisible();
  await captureState(app,'gallery-gift-at-presentation','Gift chrome immediately after closing the main offer');
  await expect(screen.getByTestId('paywall_main')).not.toBeVisible();
  await expect(screen.getByTestId('paywall_close_button')).toBeVisible();
  expect(await screen.getByTestId('paywall_close_button').boundingBox()).toEqual(mainCloseFrame);
 await captureState(app,'gallery-gift-paywall','Gift offer after closing the main paywall');
 await tapNativeControl(screen,screen.getByTestId('paywall_close_button'));
});
