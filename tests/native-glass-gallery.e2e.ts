import {scrollMainContent} from './handwriting-layout-scroll';
import {test} from '@e2e-dev/mobile';
import {expect} from 'e2e';
import {captureState,tapNativeControl,tapTab} from './handwriting-helpers';
import {launchFreshJourney,startGameFromHome,openRoundDeck,scoreManualRound,finishCurrentGame,tapGameOverAction,addSavedPlayer,chooseHeadToHeadPlayers,scorePhaseRound,startDinnerRoundWithInk,returnToPlayersDock} from './native-glass-flows';

test('capture every PipCount destination for the design comparison', {timeout:900_000}, async ({app,screen,device})=>{
 const names=['Maya','Leo'] as const;
 await launchFreshJourney(app,screen,device,['-unlock-pro','-hasSeenScoreDeckTutorial','NO']);
 await startGameFromHome(app,screen,'generic',names,'gallery-scoreboard');
 await openRoundDeck(app,screen,names,'gallery-handwriting');
 await scoreManualRound(app,screen,names,{maya:7,leo:9},'gallery-manual');
 await expect(screen.getByTestId('undo_last_round_button')).toBeEnabled();
 await screen.getByTestId('round_log_button').tap();
 await expect(screen.getByText('round 1',{exact:true})).toBeVisible();
 await captureState(app,'gallery-round-log','Saved round displayed on the opaque round log');
 await tapNativeControl(screen,screen.getByRole('button','done',{exact:true}).last());
 await finishCurrentGame(app,screen,'leo','gallery-result');
 await tapGameOverAction(screen,'home_button');
 await captureState(app,'gallery-home-completed','Home with the completed scoreboard game');
 await tapTab(screen,'Players');
 await captureState(app,'gallery-players','Saved players from the completed game');
 const maya=screen.getByTestId('saved_player_maya'); await screen.scrollUntilVisible(maya); await maya.tap();
 await expect(screen.getByTestId('player_stats_view').last()).toBeVisible();
 await captureState(app,'gallery-player-history','Player history and statistics');
 const compare=screen.getByRole('button','compare',{exact:true}); await screen.scrollUntilVisible(compare); await tapNativeControl(screen,compare);
 await expect(screen.getByText('choose the matchup',{exact:true})).toBeVisible();
 await captureState(app,'gallery-head-to-head-picker','Head to head selection');
 await chooseHeadToHeadPlayers(screen,'maya','leo');
 await captureState(app,'gallery-head-to-head','Head to head with a completed game');
 await returnToPlayersDock(screen);
 await addSavedPlayer(app,screen,'Jo','gallery-roster');
 const rename=screen.getByRole('button','Rename jo',{exact:true});
 if(await rename.isVisible()){
  await tapNativeControl(screen,rename); await captureState(app,'gallery-rename-player','Native player rename form');
  await tapNativeControl(screen,screen.getByRole('button',/^(cancel|Cancel)$/).last());
 }
 await tapTab(screen,'More');
 await captureState(app,'gallery-more','More with tools and appearance settings');
 const history=screen.getByTestId('see_all_button'); for(let i=0;i<5 && !(await history.isVisible());i++) await screen.swipe({direction:'up'});
 await expect(history).toBeVisible(); await tapNativeControl(screen,history);
 await expect(screen.getByTestId('history_card_0')).toBeVisible();
 await captureState(app,'gallery-history','Completed game history');
 await tapNativeControl(screen,screen.getByTestId('history_card_0'));
 await expect(screen.getByTestId('game_detail_view')).toBeVisible();
 await captureState(app,'gallery-game-detail','Completed game detail');
 const share=screen.getByTestId('share_game_detail_button').last(); await screen.scrollUntilVisible(share); await tapNativeControl(screen,share);
 await captureState(app,'gallery-share','Native result share sheet');
 // Each other format uses fresh data, but the same actual player and scoring controls.
 await launchFreshJourney(app,screen,device,['-unlock-pro']);
 await startGameFromHome(app,screen,'phase10',names,'gallery-ten-phases');
 await scorePhaseRound(app,screen,names,'gallery-phase-round',false);
 for(const tool of ['timer','dice','starter']) {
  await tapNativeControl(screen,screen.getByRole('button',tool,{exact:true}));
  const action=screen.getByRole('button',tool==='timer'?'start':tool==='dice'?'roll':'pick starter',{exact:true});
  await screen.scrollUntilVisible(action);
  await captureState(app,`gallery-tool-${tool}`,`${tool} utility sheet with reachable controls`);
  await tapNativeControl(screen,screen.getByRole('button','done',{exact:true}).last());
 }

 await launchFreshJourney(app,screen,device,['-unlock-pro']);
 await startGameFromHome(app,screen,'whatsForDinner',names,'gallery-dinner');
 await startDinnerRoundWithInk(app,screen,names,'gallery-dinner-round');
});
