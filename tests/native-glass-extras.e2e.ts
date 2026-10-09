import {test} from '@e2e-dev/mobile';
import {expect} from 'e2e';
import {captureState,tapNativeControl,tapTab,scrollControlAboveTabDock} from './handwriting-helpers';
import {launchFreshJourney,startGameFromHome} from './native-glass-flows';

test('capture utility sheets and the Pro offer',{timeout:360_000},async({app,screen,device})=>{
 if(!process.env.PIPCOUNT_HOME_TOOLS_ONLY){
 if(process.env.PIPCOUNT_CAPTURE_EXISTING) await device.openApp('com.icequeen.scorekeeper',{relaunch:false});
 else {await launchFreshJourney(app,screen,device,['-unlock-pro']); await startGameFromHome(app,screen,'phase10',['Maya','Leo'],'gallery-extras');}
 for(const tool of ['timer','dice','starter']){
  await tapNativeControl(screen,screen.getByRole('button',tool,{exact:true}));
  const action=screen.getByRole('button',tool==='timer'?'start':tool==='dice'?'roll':'pick starter',{exact:true});
  await screen.scrollUntilVisible(action);
  await captureState(app,`gallery-tool-${tool}`,`${tool} scoring utility sheet`);
  await tapNativeControl(screen,screen.getByRole('button','done',{exact:true}).last());
 }
 }
 await launchFreshJourney(app,screen,device,[]);
 for(const [title,tool] of [['open game timer','timer'],['roll dice','dice'],['pick a random starter','starter'],['learn about undo','undo']]){
  const control=screen.getByRole('button',title,{exact:true}); await scrollControlAboveTabDock(screen,control,'tab_home','Home utility'); await tapNativeControl(screen,control);
  await expect(screen.getByRole('button','done',{exact:true}).last()).toBeVisible();
  await captureState(app,`gallery-home-tool-${tool}`,'Home utility sheet');
  await tapNativeControl(screen,screen.getByRole('button','done',{exact:true}).last());
 }
 await tapTab(screen,'More');
 const upgrade=screen.getByTestId('more_upgrade_button'); await screen.scrollUntilVisible(upgrade); await tapNativeControl(screen,upgrade);
 await expect(screen.getByTestId('paywall_title')).toBeVisible();
 const retry=screen.getByTestId('paywall_retry_button');
 const unlock=screen.getByTestId('paywall_unlock_button');
 await expect.poll(async()=>await retry.isVisible()||await unlock.isEnabled(),{timeout:30_000}).toBe(true);
 await captureState(app,'gallery-paywall','Pro offer after StoreKit loads or reports unavailable');
 await tapNativeControl(screen,screen.getByTestId('paywall_close_button'));
});
