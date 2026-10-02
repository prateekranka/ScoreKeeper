import { bauhausArt, bauhausStar } from './bauhaus-art.js';
const variants = {
  A: { name: 'Night hub', label: 'Home first', description: 'The current Bauhaus home, extended with round totals, a saved crew, and a recap of the night.', emphasis: 'Keep the current artwork and Home layout. Add useful context to the active game card.', short: 'Current Home, with totals and less setup for the next game.' },
  B: { name: 'Crew first', label: 'People first', description: 'Your regular crew and saved house rules come first. Start another game with the same people.', emphasis: 'Use the current Players artwork and paper cards. Keep the crew ready between games.', short: 'Saved people and rules, ready for another game.' },
  C: { name: 'Score first', label: 'Rounds first', description: 'A round ledger in the current Bauhaus design. Add a score, correct any round, and see updated totals.', emphasis: 'Use the current scoring artwork, black numbers, and blue actions. Make typed entry easy to reach.', short: 'Editable rounds and typed scores, inside the current design.' },
  D: { name: 'Night story', label: 'Recap first', description: 'The whole night in one place: game wins, personal records, and a quick return to the current game.', emphasis: 'Use the current celebration artwork and paper cards. Keep wins separate from each game’s points.', short: 'A recap of wins and records, with the current celebration artwork.' },
};
const keys = Object.keys(variants);
const url = new URL(location.href);
let currentKey = keys.includes(url.searchParams.get('variant')) ? url.searchParams.get('variant') : 'A';
let compare = url.searchParams.get('view') === 'compare';
const viewerOnly = url.searchParams.get('viewer') === '1';
if (viewerOnly) compare = false;
const production = url.searchParams.get('mode') === 'production' || viewerOnly;
const lab = document.querySelector('#lab');
const escapeHTML = (value) => String(value).replace(/[&<>"']/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character]));

const paths = {
  home: '<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1Z"/>',
  people: '<circle cx="9" cy="7" r="3"/><path d="M3 21v-3a6 6 0 0 1 12 0v3m2-17a3 3 0 0 1 0 6m1 4a5 5 0 0 1 3 4v3"/>',
  history: '<path d="M3 11a9 9 0 1 1 2 7M3 4v7h7m2-5v6l4 2"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  chevron: '<path d="m9 5 7 7-7 7"/>',
  left: '<path d="m15 5-7 7 7 7"/>',
  arrow: '<path d="M4 12h15m-6-6 6 6-6 6"/>',
  down: '<path d="M12 4v15m-6-6 6 6 6-6"/>',
  close: '<path d="m6 6 12 12M6 18 18 6"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  trophy: '<path d="M8 3h8v7a4 4 0 0 1-8 0Zm0 2H4v3a4 4 0 0 0 4 4m8-7h4v3a4 4 0 0 1-4 4m-4 2v7m-5 0h10"/>',
  crown: '<path d="m3 7 4 4 5-7 5 7 4-4-2 12H5Z"/>',
  table: '<rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8m-4-4v4"/>',
  grid: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
  edit: '<path d="m14 5 5 5M3 21l5-1L21 7a2 2 0 0 0-5-5L3 15Z"/>',
  keyboard: '<rect x="2" y="5" width="20" height="14" rx="2"/><path d="M6 9h1m3 0h1m3 0h1m3 0h1M6 12h1m3 0h1m3 0h1m3 0h1M7 16h10"/>',
  draw: '<path d="m15 4 5 5-9 9-7 2 2-7ZM13 6l5 5M3 21h18"/>',
  share: '<path d="M12 16V3m-5 5 5-5 5 5M5 12v8a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-8"/>',
  spark: '<path d="m12 3 2.4 6.6L21 12l-6.6 2.4L12 21l-2.4-6.6L3 12l6.6-2.4Z"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10v.5"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  lock: '<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3m-4 4v3"/>',
  bookmark: '<path d="M6 3h12v18l-6-4-6 4Z"/>',
  wifi: '<path d="M3 8a16 16 0 0 1 18 0M6 12a10 10 0 0 1 12 0m-9 4a4 4 0 0 1 6 0m-3 4h.01"/>',
  menu: '<circle cx="5" cy="12" r=".8"/><circle cx="12" cy="12" r=".8"/><circle cx="19" cy="12" r=".8"/>',
  leaf: '<path d="M20 3c-8 0-16 4-16 11a6 6 0 0 0 6 6c7 0 10-9 10-17ZM4 20 15 9"/>',
};
const icon = (name, extra = '') => `<svg class="icon ${extra}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] || paths.spark}</svg>`;
const person = (id, name, initials, bg, ink) => {
  const palette = { '#f4cb70': ['#FFB512', '#0B0B0B'], '#c0d7eb': ['#0D47D9', '#FFFFFF'], '#e8bcaf': ['#EF3340', '#FFFFFF'], '#c5d9b9': ['#0A8F4B', '#FFFFFF'], '#c8c5eb': ['#0D47D9', '#FFFFFF'] };
  const nativeColor = palette[bg] || [bg, ink];
  return { id, name, initials, bg: nativeColor[0], ink: nativeColor[1] };
};
const originalPlayers = [
  person('mina', 'Mina', 'M', '#f4cb70', '#694820'),
  person('omar', 'Omar', 'O', '#c0d7eb', '#335572'),
  person('jules', 'Jules', 'J', '#e8bcaf', '#804c3b'),
  person('sam', 'Sam', 'S', '#c5d9b9', '#43623b'),
];
const originalCrews = [
  { id: 'friday', name: 'Friday regulars', detail: 'Your usual four. Ready in one tap.', players: originalPlayers },
  { id: 'family', name: 'Sunday family', detail: 'A little friendly competition.', players: [person('you', 'You', 'Y', '#f4cb70', '#694820'), person('dad', 'Dad', 'D', '#c0d7eb', '#335572'), person('mum', 'Mum', 'M', '#e8bcaf', '#804c3b')] },
  { id: 'lunch', name: 'Lunch break', detail: 'A quick game with the team.', players: [originalPlayers[0], originalPlayers[2], person('nia', 'Nia', 'N', '#c8c5eb', '#544782')] },
];
const originalPresets = [
  { id: 'rummy', name: 'Friday Rummy', game: 'Rummy', direction: 'low', rounds: 6 },
  { id: 'uno', name: 'UNO at home', game: 'UNO', direction: 'low', rounds: 5 },
  { id: 'quick', name: 'Quick score', game: 'Scoreboard', direction: 'high', rounds: 0 },
];
function initialState() {
  return {
    route: 'night', crews: structuredClone(originalCrews), presets: structuredClone(originalPresets), crewId: 'friday', selectedCrewId: 'friday', nextCrewId: null, presetId: 'rummy', activePresetId: 'rummy', returnSheet: null, formDraft: {},
    players: structuredClone(originalPlayers), night: 'Friday night', nightFinished: false,
    game: 'Rummy', direction: 'low', roundGoal: 6, active: true,
    rounds: [{ mina: 18, omar: 22, jules: 10, sam: 32 }, { mina: 24, omar: 17, jules: 28, sam: 20 }, { mina: 8, omar: 31, jules: 26, sam: 27 }],
    completed: [{ name: 'Ten Phases', winner: 'Jules', winnerId: 'jules', note: 'Finished all ten phases' }, { name: 'Scoreboard', winner: 'Omar', winnerId: 'omar', note: 'A close one: won by 8', recordValue: 8, recordPrevious: 5 }],
    records: { 'mina:Rummy': 12, 'omar:Rummy': 8, 'jules:Rummy': 10, 'sam:Rummy': 7, 'omar:Scoreboard': 8 },
    sheet: null, mode: 'type', draft: {}, selectedPlayer: 'mina', editRound: null, error: '', drawn: false, recognized: false, toast: '',
  };
}
const states = Object.fromEntries(keys.map(key => [key, initialState()]));
const features = { night: 'Playing', scores: 'Score entry', crews: 'Crews & rules', recap: 'Night recap', table: 'Table view' };
const initialFeature = Object.hasOwn(features, url.searchParams.get('feature')) ? url.searchParams.get('feature') : 'night';
for (const s of Object.values(states)) {
  s.route = initialFeature === 'scores' ? 'night' : initialFeature;
  if (initialFeature === 'scores') openScores(s);
}
if (viewerOnly) {
  states[currentKey].route = 'table';
  try {
    const snapshot = JSON.parse(url.searchParams.get('scores') || 'null');
    if (snapshot && Array.isArray(snapshot.players) && snapshot.players.length > 0 && snapshot.players.length <= 15 && snapshot.players.every(p => p && typeof p.id === 'string' && typeof p.name === 'string' && typeof p.initials === 'string' && /^#[0-9a-f]{6}$/i.test(p.bg) && /^#[0-9a-f]{6}$/i.test(p.ink)) && snapshot.scores && snapshot.players.every(p => Number.isSafeInteger(snapshot.scores[p.id]))) {
      const s = states[currentKey];
      s.players = snapshot.players;
      s.rounds = [snapshot.scores];
      s.game = String(snapshot.game || 'Scoreboard').slice(0, 50);
      s.night = String(snapshot.night || 'Game night').slice(0, 50);
      s.direction = snapshot.direction === 'high' ? 'high' : 'low';
      s.viewerRound = Number.isSafeInteger(snapshot.round) ? snapshot.round : 1;
    }
  } catch { /* A malformed viewer link uses the visible sample game. */ }
}

function total(s, id) { return s.rounds.reduce((sum, round) => sum + (round[id] || 0), 0); }
function rankings(s) { return s.players.map(p => ({ ...p, score: total(s, p.id) })).sort((a, b) => s.direction === 'low' ? a.score - b.score : b.score - a.score); }
function leader(s) { return rankings(s)[0]; }
function rule(s) { return `${s.direction === 'low' ? 'Lowest' : 'Highest'} score wins`; }
function currentCrew(s) { return s.crews.find(c => c.id === s.crewId) || s.crews[0]; }
function selectedCrew(s) { return s.crews.find(c => c.id === s.selectedCrewId) || currentCrew(s); }
function nextCrew(s) { return s.crews.find(c => c.id === s.nextCrewId) || currentCrew(s); }
function activePresetName(s) { return s.presets.find(p => p.id === s.activePresetId)?.name || 'Your saved rules'; }
function roundLabel(s) { return `Round ${s.rounds.length + 1}${s.roundGoal ? ` of ${s.roundGoal}` : ''}`; }
function avatar(p, crown = false) { return `<span class="avatar" style="--avatar-bg:${p.bg};--avatar-ink:${p.ink}" aria-hidden="true">${crown ? icon('crown') : ''}${escapeHTML(p.initials)}</span>`; }
function avatars(players) { return `<div class="avatars" aria-hidden="true">${players.slice(0, 4).map(p => avatar(p)).join('')}</div>`; }
function brand() { return `<div class="brand">pipcount ${bauhausStar()}</div>`; }
function primary(action, text, symbol = 'plus') { return `<button class="primary" data-action="${action}">${icon(symbol)}${text}</button>`; }
function secondary(action, text, symbol) { return `<button class="secondary" data-action="${action}">${symbol ? icon(symbol) : ''}${text}</button>`; }
function actionButton(action, symbol, label, className = 'plain-icon') { return `<button class="${className}" data-action="${action}" aria-label="${label}">${icon(symbol)}</button>`; }
function ruleLabel(s) { return `<span class="rule-label">${icon(s.direction === 'low' ? 'down' : 'spark')}${rule(s)}</span>`; }
function recentGames(s, limit = 2) { return s.completed.slice(-limit).reverse().map(g => `<div class="recent-game"><div class="game-mark" aria-hidden="true">${escapeHTML(g.name.slice(0, 1))}</div><div><strong>${escapeHTML(g.name)}</strong><small>${escapeHTML(g.note)}</small></div><span class="win-label">${escapeHTML(g.winner)} won</span></div>`).join(''); }
function productHeader() { return `<header class="product-header"><div>${brand()}<p class="brand-tagline">game night, organized</p></div></header>`; }
function inactiveNight(s) { return `<div class="screen feature-screen">${productHeader()}<span class="eyebrow">${s.nightFinished ? 'A night well played' : 'Keep the night going'}</span><h1>${s.nightFinished ? 'Same time next week?' : 'One more game?'}</h1><p class="subline">Your crew is saved. Pick a game and you’re ready.</p><div class="recap-sheet"><div class="recap-icon">${icon('people')}</div><h2>${escapeHTML(s.night)}</h2><p>${s.completed.length} games played · ${s.players.length} friends</p>${avatars(s.players)}</div>${primary('next-game', s.nightFinished ? 'Start a new night' : 'Pick the next game', 'plus')}<div style="height:10px"></div>${secondary('recap', 'See the night recap', 'trophy')}</div>`; }

function scoreStrip(s) {
  return `<div class="native-score-strip" aria-label="Current totals">${s.players.slice(0, 4).map(p => `<div class="${p.id === leader(s).id ? 'is-leading' : ''}"><span>${escapeHTML(p.name)}</span><strong class="score-number" data-testid="total-${p.id}">${total(s, p.id)}</strong></div>`).join('')}</div>`;
}
function liveGame(s) {
  return `<div class="screen bauhaus-screen">${backHeader('scoreboard')}${bauhausArt('score', 120)}<span class="eyebrow">${roundLabel(s)}</span><h1 class="native-title">${escapeHTML(s.game)}</h1>${ruleLabel(s)}<section class="native-card native-standings" aria-label="Standings">${rankings(s).map((p, i) => `<div class="native-standing"><span class="native-rank">${i + 1}</span>${avatar(p)}<div><strong>${escapeHTML(p.name)}</strong><small>${i === 0 ? 'leading' : 'total score'}</small></div><b class="score-number" data-testid="total-${p.id}">${p.score}</b></div>`).join('')}</section>${primary('add-round', 'add round scores')}<div class="native-pair">${secondary('rounds', 'edit a round', 'edit')}${secondary('finish-game', 'finish game', 'check')}</div></div>`;
}
export function VariantA(s) {
  if (s.route === 'game') return liveGame(s);
  return `<div class="screen bauhaus-screen native-home">${productHeader()}<span class="eyebrow">round ${s.rounds.length + 1} is waiting</span>${bauhausArt('home', 248)}<section class="native-card" aria-label="Current game"><div class="native-card-heading"><h2>${escapeHTML(s.game)}</h2><span class="native-status">in progress</span></div><p class="native-meta">${s.players.length} players · ${roundLabel(s)} · ${s.direction === 'low' ? 'lowest' : 'highest'} wins</p>${scoreStrip(s)}${primary('add-round', 'add round scores')}<button class="native-card-link" data-action="game" aria-label="Open scoreboard">open scoreboard ${icon('chevron')}</button></section><button class="native-card native-shortcut" data-action="next-game"><span class="shortcut-shape" aria-hidden="true">${icon('people')}</span><div><strong>next game, same crew</strong><p>${escapeHTML(currentCrew(s).name)} · rules saved</p></div>${icon('chevron')}</button><div class="section-heading"><h2>this game night</h2><button class="text-button" data-action="recap">see recap</button></div>${recentGames(s)}</div>`;
}
export function VariantB(s) {
  if (s.route === 'game') return liveGame(s);
  return `<div class="screen bauhaus-screen native-crew-home">${productHeader()}<span class="eyebrow">your people, ready to play</span>${bauhausArt('crew', 176)}<section class="native-card" aria-label="Saved crew"><div class="native-card-heading"><h2>${escapeHTML(currentCrew(s).name)}</h2><button class="text-button" data-action="crews">change</button></div><p class="native-meta">saved crew · ${s.players.length} players</p><div class="native-crew-grid">${s.players.slice(0, 4).map(p => `<div>${avatar(p)}<strong>${escapeHTML(p.name)}</strong></div>`).join('')}</div><button class="native-preset-line" data-action="presets">${icon('bookmark')}<div><strong>${escapeHTML(activePresetName(s))}</strong><small>${rule(s)} · ${s.roundGoal || 'open'} rounds</small></div>${icon('chevron')}</button>${primary('next-game', 'next game, same crew', 'arrow')}</section><button class="native-card native-shortcut" data-action="game"><span class="shortcut-shape shape-blue" aria-hidden="true">${icon('grid')}</span><div><strong>keep playing ${escapeHTML(s.game)}</strong><p>${roundLabel(s)} · ${escapeHTML(leader(s).name)} leads</p></div>${icon('chevron')}</button><div class="section-heading"><h2>this game night</h2><button class="text-button" data-action="recap">see recap</button></div>${recentGames(s)}</div>`;
}
export function VariantC(s) {
  const visibleRounds = s.rounds.length + 1;
  return `<div class="screen bauhaus-screen native-score-home">${productHeader()}<div class="native-score-heading"><div><span class="eyebrow">${roundLabel(s)}</span><h1 class="native-title">${escapeHTML(s.game)}</h1>${ruleLabel(s)}</div>${bauhausArt('score', 112, 140)}</div><section class="native-card native-ledger-card" aria-label="Round scores"><table class="score-ledger" aria-label="Editable round scores"><thead><tr><th scope="col">RD</th>${s.players.slice(0, 4).map(p => `<th scope="col">${escapeHTML(p.name)}</th>`).join('')}</tr></thead><tbody>${Array.from({length:visibleRounds}, (_, index) => `<tr class="${index === s.rounds.length ? 'next-row' : ''}"><td>${String(index + 1).padStart(2, '0')}</td>${s.players.slice(0, 4).map(p => `<td>${index < s.rounds.length ? `<button data-action="edit-round" data-round="${index}" data-player="${p.id}" aria-label="Edit round ${index + 1}, ${escapeHTML(p.name)}: ${s.rounds[index][p.id]}">${s.rounds[index][p.id]}</button>` : `<button data-action="add-player-score" data-player="${p.id}" aria-label="Add round ${index + 1} score for ${escapeHTML(p.name)}">+</button>`}</td>`).join('')}</tr>`).join('')}</tbody><tfoot><tr><td>TOTAL</td>${s.players.slice(0, 4).map(p => `<td class="${p.id === leader(s).id ? 'winning-total' : ''}" data-testid="total-${p.id}">${total(s, p.id)}</td>`).join('')}</tr></tfoot></table><p class="native-ledger-note">tap a score to correct it</p>${primary('add-round', `enter round ${s.rounds.length + 1}`, 'keyboard')}</section><div class="native-pair">${secondary('table', 'table view', 'table')}${secondary('finish-game', 'finish game', 'check')}</div><button class="native-card native-shortcut" data-action="presets"><span class="shortcut-shape" aria-hidden="true">${icon('bookmark')}</span><div><strong>${escapeHTML(activePresetName(s))}</strong><p>your saved house rules</p></div>${icon('chevron')}</button><button class="text-button" data-action="recap">${s.completed.length} games earlier tonight ${icon('chevron')}</button></div>`;
}
function nativeRecord(record) {
  if (!record) return '';
  return `<button class="native-card native-record" data-action="recap"><span class="record-star" aria-hidden="true">${bauhausStar()}</span><div><span class="eyebrow">personal best</span><strong>${escapeHTML(record.winner)}’s ${record.recordValue}-point win</strong><p>${escapeHTML(record.name)} · previous best: ${record.recordPrevious}</p></div>${icon('chevron')}</button>`;
}
export function VariantD(s) {
  if (s.route === 'game') return liveGame(s);
  const wins = p => s.completed.filter(g => (g.winnerIds || [g.winnerId]).includes(p.id)).length;
  const last = s.completed.findLast(g => Number.isFinite(g.recordValue) && g.recordValue > 0);
  return `<div class="screen bauhaus-screen native-story-home">${productHeader()}<span class="eyebrow">the whole night, together</span>${bauhausArt('celebration', 144)}<section class="native-card" aria-label="Game Night summary"><div class="native-card-heading"><h2>${escapeHTML(s.night)}</h2><span class="native-status">${s.completed.length} games</span></div><p class="native-meta">${escapeHTML(currentCrew(s).name)} · wins, not mixed points</p><div class="native-win-strip">${s.players.slice(0, 4).map(p => `<div>${avatar(p)}<strong>${wins(p)}</strong><span>${escapeHTML(p.name)}</span><small>${wins(p) === 1 ? 'win' : 'wins'}</small></div>`).join('')}</div><p class="native-game-note">${escapeHTML(s.game)} is still on the table. ${roundLabel(s)}.</p>${primary('game', 'keep playing', 'arrow')}</section>${nativeRecord(last)}<div class="native-pair">${secondary('next-game', 'next game', 'plus')}${secondary('recap', 'night recap', 'history')}</div></div>`;
}
function gamesScreen(s) {
  return `<div class="screen bauhaus-screen">${productHeader()}<span class="eyebrow">pick a game, keep your rules</span>${bauhausArt('score', 176)}<h1 class="native-title">your games</h1><p class="subline">House rules you can use again.</p>${s.presets.map(p => `<button class="native-card native-shortcut" data-action="preset-from-crew" data-preset="${p.id}"><span class="shortcut-shape shape-blue" aria-hidden="true">${icon('grid')}</span><div><strong>${escapeHTML(p.name)}</strong><p>${p.direction === 'low' ? 'Lowest' : 'Highest'} wins · ${p.rounds || 'open'} rounds</p></div>${icon('chevron')}</button>`).join('')}<button class="text-button" data-action="new-preset">${icon('plus')} save a preset</button></div>`;
}
function moreScreen(s) {
  return `<div class="screen bauhaus-screen">${productHeader()}<span class="eyebrow">a night worth keeping</span>${bauhausArt('celebration', 176)}<h1 class="native-title">more</h1>${[['recap','history','game night recap',`${s.completed.length} games finished · ${s.players.length} friends`],['rounds','edit','round history','Every point. Every correction.'],['table','table','table view','Read-only scores for the group.']].map(([action,symbol,title,copy]) => `<button class="native-card native-shortcut" data-action="${action}"><span class="shortcut-shape shape-blue" aria-hidden="true">${icon(symbol)}</span><div><strong>${title}</strong><p>${copy}</p></div>${icon('chevron')}</button>`).join('')}</div>`;
}

function backHeader(text, action = 'night') { return `<header class="back-header">${actionButton(action, 'left', 'Back')}<h1>${text}</h1>${actionButton('table', 'table', 'Open table view')}</header>`; }
function crewsScreen(s) {
  const selected = selectedCrew(s);
  return `<div class="screen feature-screen"><span class="eyebrow">Less setup. More playing.</span><h1>Your people.</h1><p class="subline">Save a crew once. Bring everyone back next time.</p>${s.crews.map(c => `<button class="crew-choice" data-action="select-crew" data-crew="${c.id}" aria-pressed="${c.id === selected.id}"><div><strong>${escapeHTML(c.name)}</strong><p>${c.players.length} people · ${escapeHTML(c.detail)}</p></div>${c.id === selected.id ? icon('check') : icon('chevron')}</button>`).join('')}<button class="text-button" data-action="new-crew">${icon('plus')} Save a new crew</button><div class="section-heading"><h2>${escapeHTML(selected.name)}</h2><span class="small-label">${selected.players.length} players</span></div>${selected.players.map(p => `<div class="crew-person">${avatar(p)}<span class="name">${escapeHTML(p.name)}</span><span class="small-label">${p.id === 'mina' ? '2 wins last Friday' : 'Ready to play'}</span></div>`).join('')}<div class="section-heading"><h2>Rules you use</h2><button class="text-button" data-action="new-preset">Add preset</button></div>${s.presets.map(p => `<button class="preset-mini" data-action="preset-from-crew" data-preset="${p.id}"><span class="game-mark">${icon('bookmark')}</span><div><strong>${escapeHTML(p.name)}</strong><span>${p.direction === 'low' ? 'Lowest' : 'Highest'} score · ${p.rounds ? `${p.rounds} rounds` : 'Open rounds'}</span></div>${icon('chevron')}</button>`).join('')}</div>`;
}
function recapScreen(s) {
  const wins = Object.fromEntries(s.players.map(p => [p.id, s.completed.filter(g => (g.winnerIds || [g.winnerId]).includes(p.id)).length]));
  const last = s.completed.findLast(g => g.recordValue !== undefined);
  const highlight = last ? `<div class="highlight">${icon(last.recordValue ? 'spark' : 'trophy')}<div><strong>${escapeHTML(last.winner)}’s ${last.recordValue ? 'personal best' : 'moment'}</strong><p>${last.recordValue ? `${escapeHTML(last.name)} · ${last.recordValue}-point winning margin<br>Previous best: ${last.recordPrevious} points` : `${escapeHTML(last.name)} · ${escapeHTML(last.note)}`}</p></div></div>` : '';
  return `<div class="screen feature-screen recap-screen">
    <header class="product-header">${brand()}${actionButton('share-night', 'share', 'Share the night recap', 'icon-button')}</header>
    <span class="eyebrow">${s.nightFinished ? 'Night complete' : 'The whole night, together'}</span>
    <h1>${escapeHTML(s.night)}</h1><p class="subline">Fri, Oct 2 · ${escapeHTML(currentCrew(s).name)}</p>
    <section class="recap-sheet" aria-label="Game Night summary"><div class="recap-title-row"><div class="recap-icon">${icon('spark')}</div>
      <h2>${s.nightFinished ? 'A night worth keeping.' : 'Good games. Better company.'}</h2></div>
      <p>${s.completed.length} games finished · ${s.players.length} friends<br>${s.active && !s.nightFinished ? `${escapeHTML(s.game)} is still on the table.` : 'Same crew, next time.'}</p>
      <div class="recap-wins">${s.players.slice(0, 4).map(p => `<div>${avatar(p)}<strong>${wins[p.id]}</strong><span class="name">${escapeHTML(p.name)}</span><div class="small-label">${wins[p.id] === 1 ? 'win' : 'wins'}</div></div>`).join('')}</div>
    </section>
    ${s.active ? primary('night', 'Back to the game', 'left') : primary('next-game', s.nightFinished ? 'Start another night' : 'Next game, same crew', 'plus')}
    <div style="height:9px"></div><div class="pair-actions">${secondary('share-night', 'Share recap', 'share')}${secondary(s.nightFinished ? 'crews' : 'finish-night', s.nightFinished ? 'Saved crew' : 'End the night', s.nightFinished ? 'people' : 'check')}</div>
    <div style="height:16px"></div>${highlight}
    <div class="section-heading" style="margin-bottom:0"><h2>The games</h2><span class="small-label">Wins, not mixed points</span></div>
    <div class="recap-games">${recentGames(s, 10)}</div>
  </div>`;
}
function roundsScreen(s) {
  return `<div class="screen feature-screen">${backHeader('Round history')}<span class="eyebrow">${escapeHTML(s.game)} · ${s.rounds.length} rounds played</span><h1>Every point, in view.</h1><p class="subline">Fix an earlier score. Totals update immediately.</p><div class="history-names"><span></span>${s.players.slice(0, 4).map(p => `<span>${escapeHTML(p.name)}</span>`).join('')}<span></span></div><div class="round-history">${s.rounds.map((r, i) => `<button class="round-edit" data-action="edit-round" data-round="${i}" aria-label="Edit round ${i + 1}"><span class="round-label">Round ${i + 1}</span><span class="round-values">${s.players.slice(0, 4).map(p => `<span>${r[p.id]}</span>`).join('')}</span>${icon('edit')}</button>`).join('') || '<p class="empty-copy">No scores yet. Add the first round.</p>'}</div><div class="soft-panel"><div class="paper-scores" style="margin:0">${s.players.slice(0, 4).map(p => `<div><div class="name">${escapeHTML(p.name)}</div><div class="score score-number">${total(s, p.id)}</div></div>`).join('')}</div></div><div style="height:20px"></div>${primary('add-round', `Add round ${s.rounds.length + 1}`, 'keyboard')}<div style="height:10px"></div>${secondary('finish-game', 'Finish this game', 'check')}</div>`;
}
function viewerHref(s, key) {
  const viewerURL = new URL(location.href);
  viewerURL.search = '';
  viewerURL.searchParams.set('variant', key);
  viewerURL.searchParams.set('viewer', '1');
  viewerURL.searchParams.set('scores', JSON.stringify({ players: s.players, scores: Object.fromEntries(s.players.map(p => [p.id, total(s, p.id)])), game: s.game, night: s.night, direction: s.direction, round: s.rounds.length }));
  return viewerURL.href;
}
function tableScreen(s, key) {
  return `<div class="viewer-screen"><div class="viewer-top">${brand()}<span>${icon('lock')}Viewer mode</span></div><span class="eyebrow">${escapeHTML(s.night)}</span><h1>${escapeHTML(s.game)}</h1><p class="subline">${rule(s)} · ${s.viewerRound ?? s.rounds.length} rounds played</p><div class="viewer-grid">${rankings(s).map((p, i) => `<div class="viewer-player ${i === 0 ? 'leader' : ''}">${avatar(p)}<p>${escapeHTML(p.name)}</p><strong class="score-number">${p.score}</strong><small>${i === 0 ? 'Leading' : `${i + 1}${i === 1 ? 'nd' : i === 2 ? 'rd' : 'th'} place`}</small></div>`).join('')}</div><p class="viewer-foot">Everyone can see the score.<br>No accidental edits.</p>${!viewerOnly ? `<div style="height:18px"></div>${secondary('night', 'Back to scoring', 'left')}<a class="viewer-link" href="${escapeHTML(viewerHref(s, key))}" target="_blank" rel="noopener">Open read-only viewer link ${icon('arrow')}</a>` : '<p class="viewer-foot">Prototype snapshot · not live sync</p>'}</div>`;
}
function sheetHeader(title, description) { return `<div class="sheet-handle"></div><div class="sheet-header"><h2>${title}</h2>${actionButton('close-sheet', 'close', 'Close dialog')}</div><p class="subline">${description}</p>`; }
function scoreSheet(s) {
  const editing = s.editRound !== null;
  return `${sheetHeader(editing ? `Edit round ${s.editRound + 1}` : `Round ${s.rounds.length + 1}`, `${escapeHTML(s.game)} · ${rule(s).toLowerCase()}`)}<div class="input-segment" role="tablist" aria-label="Score entry method"><button role="tab" data-action="type-mode" aria-selected="${s.mode === 'type'}">${icon('keyboard')}Type</button><button role="tab" data-action="draw-mode" aria-selected="${s.mode === 'draw'}">${icon('draw')}Draw</button></div>${s.mode === 'type' ? `<div role="tabpanel" aria-label="Typed score entry">${s.players.map(p => `<label class="entry-row">${avatar(p)}<span class="entry-person"><strong>${escapeHTML(p.name)}</strong><small>Current total: ${total(s, p.id)}</small></span><input class="score-input" name="score-${p.id}" data-score="${p.id}" aria-label="Score for ${escapeHTML(p.name)}" type="text" inputmode="decimal" autocomplete="off" maxlength="7" placeholder="—" value="${escapeHTML(s.draft[p.id] ?? '')}"></label>`).join('')}<p class="entry-note">${icon('info')}Negative scores and scores over 99 are welcome.</p></div>` : `<div role="tabpanel" aria-label="Drawn score entry"><div class="draw-people">${s.players.map(p => `<button data-action="draw-player" data-player="${p.id}" aria-pressed="${s.selectedPlayer === p.id}" aria-label="Draw score for ${escapeHTML(p.name)}">${avatar(p)}${escapeHTML(p.name)}${s.draft[p.id] !== undefined && s.draft[p.id] !== '' ? ` · ${escapeHTML(s.draft[p.id])}` : ''}</button>`).join('')}</div><canvas class="draw-pad" aria-label="Handwriting pad for ${escapeHTML(s.players.find(p => p.id === s.selectedPlayer).name)}"></canvas><div class="draw-toolbar"><span>Write a score with your finger or pointer.</span><button class="text-button" data-action="clear-draw">Clear</button></div>${s.recognized ? `<div class="draw-recognition"><strong>24</strong><span>Sample recognition</span><button class="primary" data-action="use-recognition">Use 24</button></div>` : `<div style="margin:8px 0 15px">${secondary('recognize-draw', 'Recognize sample score', 'draw')}</div>`}<p class="entry-note">Prefer a keyboard? Switch to Type. Your scores stay.</p></div>`}<p class="error-message" role="status">${escapeHTML(s.error)}</p>${primary('save-round', editing ? 'Save correction' : 'Save round', 'check')}<p class="sheet-footer-note">${editing ? 'All later totals update. Nothing else changes.' : 'Saved on this phone. You can edit any round later.'}</p>`;
}
function presetSheet(s) {
  const starting = s.sheet === 'next-game';
  const crew = nextCrew(s);
  const changingCrew = crew.id !== s.crewId;
  return `${sheetHeader(starting ? (s.nightFinished || changingCrew ? 'Start a new night' : 'Next game. Same people.') : 'Your saved rules', starting ? `${escapeHTML(crew.name)} · ${crew.players.length} players ready` : 'Name your rules. Skip this setup next time.')} ${s.presets.map(p => `<button class="preset-choice" data-action="select-preset" data-preset="${p.id}" aria-pressed="${s.presetId === p.id}"><span class="game-mark">${icon('bookmark')}</span><div><strong>${escapeHTML(p.name)}</strong><p>${p.direction === 'low' ? 'Lowest' : 'Highest'} score wins · ${p.rounds ? `${p.rounds} rounds` : 'Open rounds'}</p></div>${s.presetId === p.id ? icon('check') : icon('chevron')}</button>`).join('')}<button class="text-button" data-action="new-preset">${icon('plus')} Save another preset</button>${starting ? `<div class="highlight" style="margin:15px 0">${icon('people')}<div><strong>${escapeHTML(crew.name)}</strong><p>${crew.players.map(p => escapeHTML(p.name)).join(', ')}</p></div></div>${changingCrew ? '<p class="small-label" style="margin-bottom:14px">A different crew starts a fresh sample night. This preview replaces the current night.</p>' : s.active ? '<p class="small-label" style="margin-bottom:14px">Starting the next game finishes the current game and keeps its result.</p>' : ''}${primary('start-next-game', s.nightFinished || changingCrew ? 'Start night' : 'Start next game', 'arrow')}` : '<p class="sheet-footer-note">These are your house rules, not official game rules.</p>'}`;
}
function otherSheet(s) {
  if (s.sheet === 'new-crew') return `${sheetHeader('Save your crew', 'For the people you play with again and again.')}<label class="form-field">Crew name<input name="crew-name" data-form="crew-name" value="${escapeHTML(s.formDraft['crew-name'] || '')}" placeholder="e.g. Sunday family" maxlength="40"></label><label class="form-field">Players, separated by commas<input name="crew-players" data-form="crew-players" value="${escapeHTML(s.formDraft['crew-players'] || '')}" placeholder="Mina, Omar, Jules, Sam" maxlength="180"></label><p class="small-label">Prototype crews support 2–4 people.</p><p class="error-message" role="status">${escapeHTML(s.error)}</p>${primary('save-crew', 'Save crew', 'check')}`;
  if (s.sheet === 'new-preset') return `${sheetHeader('Make it your game', 'Keep your house rules for next time.')}<label class="form-field">Preset name<input name="preset-name" data-form="preset-name" value="${escapeHTML(s.formDraft['preset-name'] || '')}" placeholder="e.g. Friday Rummy" maxlength="40"></label><label class="form-field">Game name<input name="preset-game" data-form="preset-game" value="${escapeHTML(s.formDraft['preset-game'] || '')}" placeholder="e.g. Rummy" maxlength="30"></label><div class="pair-actions"><label class="form-field">Winner<select name="preset-direction" data-form="preset-direction"><option value="low" ${s.formDraft['preset-direction'] !== 'high' ? 'selected' : ''}>Lowest score</option><option value="high" ${s.formDraft['preset-direction'] === 'high' ? 'selected' : ''}>Highest score</option></select></label><label class="form-field">Rounds<select name="preset-rounds" data-form="preset-rounds">${[['0', 'Open'], ['3', '3 rounds'], ['5', '5 rounds'], ['6', '6 rounds'], ['10', '10 rounds']].map(([value, label]) => `<option value="${value}" ${(s.formDraft['preset-rounds'] || '6') === value ? 'selected' : ''}>${label}</option>`).join('')}</select></label></div><p class="error-message" role="status">${escapeHTML(s.error)}</p>${primary('save-preset', 'Save preset', 'bookmark')}`;
  if (s.sheet === 'share-night') return `${sheetHeader('A night worth sharing', 'A little keepsake for the group chat.')}<div class="share-preview">${escapeHTML(shareText(s))}</div>${primary('copy-recap', 'Copy recap text', 'share')}<p class="sheet-footer-note">Copies text. No account or external service is connected.</p>`;
  if (s.sheet === 'finish-night') return `${sheetHeader('Call it a night?', 'Your games and crew stay in the recap.')}<div class="recap-icon">${icon('spark')}</div><p class="subline" style="text-align:center;margin-bottom:22px">${s.active ? (s.rounds.length ? 'We’ll finish the current game with the scores on the table.' : 'No scores yet. This game will be left out of the recap.') : `${s.completed.length} games finished. A good night with your people.`}</p>${primary('confirm-finish-night', 'Save the night recap', 'check')}<div style="height:10px"></div>${secondary('close-sheet', 'Keep playing')}`;
  return '';
}
function shareText(s) { return `${s.night} · PipCount\n${s.players.map(p => p.name).join(' · ')}\n\n${s.completed.map(g => `${g.name}: ${g.winner} won`).join('\n')}\n\n${s.completed.length} games. One good night. ✳`; }
function sheet(s) { return s.sheet ? `<div class="sheet-backdrop"><section class="sheet" role="dialog" aria-modal="true" aria-label="${s.sheet === 'scores' ? 'Score entry' : s.sheet === 'new-crew' ? 'Save crew' : s.sheet === 'new-preset' ? 'Save preset' : s.sheet === 'finish-night' ? 'Finish Game Night' : s.sheet === 'share-night' ? 'Share recap' : 'Saved game presets'}">${s.sheet === 'scores' ? scoreSheet(s) : ['next-game', 'presets'].includes(s.sheet) ? presetSheet(s) : otherSheet(s)}</section></div>` : ''; }
function navigation(s) { const activeRoute = ['game', 'rounds'].includes(s.route) ? 'night' : s.route === 'recap' ? 'more' : s.route; return `<div class="native-dock-backdrop"></div><nav class="app-nav" aria-label="App navigation">${[['night', 'home', 'Home'], ['games', 'grid', 'Games'], ['crews', 'people', 'Players'], ['more', 'menu', 'More']].map(([action, symbol, label]) => `<button data-action="${action}" ${activeRoute === action ? 'aria-current="page"' : ''}>${icon(symbol)}<span>${label}</span></button>`).join('')}</nav>`; }
function phoneContent(s, key) {
  let content;
  if (s.route === 'table') content = tableScreen(s, key);
  else if (s.route === 'crews') content = crewsScreen(s);
  else if (s.route === 'recap') content = recapScreen(s);
  else if (s.route === 'rounds') content = roundsScreen(s);
  else if (s.route === 'games') content = gamesScreen(s);
  else if (s.route === 'more') content = moreScreen(s);
  else if (!s.active) content = inactiveNight(s);
  else content = ({ A: VariantA, B: VariantB, C: VariantC, D: VariantD })[key](s);
  return `<div class="phone-content"><div class="status-bar"><span>9:41</span><div class="island" aria-hidden="true"></div><div class="status-icons" aria-hidden="true">${icon('wifi')}<i class="battery"></i></div></div><div class="app-body ${s.route === 'table' ? 'viewer-body' : ''}" ${s.sheet ? 'inert' : ''}>${content}</div>${s.route !== 'table' ? `<div ${s.sheet ? 'inert' : ''}>${navigation(s)}</div>` : ''}<div class="home-indicator" aria-hidden="true"></div>${sheet(s)}${s.toast ? `<div class="toast" role="status">${escapeHTML(s.toast)}</div>` : ''}</div>`;
}
function variantCard(key) { return `<section class="variant-card" aria-label="${key}: ${variants[key].name}"><div class="variant-meta"><a href="?variant=${key}" aria-label="Explore ${key}: ${variants[key].name}"><span class="variant-key">${key}</span>${variants[key].name} ${icon('arrow')}</a><small>${variants[key].label}</small></div><div class="phone theme-${key}" data-variant="${key}" data-testid="prototype-${key}">${phoneContent(states[key], key)}</div>${compare ? `<p class="variant-description">${variants[key].short}</p>` : ''}</section>`; }
function featureNav() { return `<nav class="lab-features" aria-label="Preview a feature"><span>Explore the features</span>${Object.entries(features).map(([feature, title]) => `<a href="?variant=${currentKey}${compare ? '&view=compare' : ''}&feature=${feature}" ${initialFeature === feature ? 'aria-current="page"' : ''}>${title}</a>`).join('')}</nav>`; }
function stateSummary(key) { const s = states[key]; return { variant: `${key} · ${variants[key].name}`, screen: s.route, crew: currentCrew(s).name, game: s.game, rule: rule(s), rounds: s.rounds.length, totals: Object.fromEntries(s.players.map(p => [p.name, total(s, p.id)])), gamesFinished: s.completed.length, nightFinished: s.nightFinished, drawer: s.sheet, entryMethod: s.mode }; }
function updateStateInspector() { const target = document.querySelector('#state-inspector'); if (target) target.textContent = JSON.stringify(compare ? keys.map(key => stateSummary(key)) : stateSummary(currentKey), null, 2); }
function renderLab() {
  phoneSizer.disconnect();
  document.body.classList.toggle('lab-production', production);
  lab.innerHTML = `<header class="lab-header"><div><div class="lab-kicker"><span class="lab-dot"></span>PipCount / Bauhaus feature prototypes / 02</div><h1>Four feature layouts. One Bauhaus design.</h1><p>The current PipCount design, extended with saved crews, typed scores, house rules, and a game-night recap.</p></div><nav class="lab-view-control" aria-label="Prototype display"><a href="?view=compare&variant=${currentKey}" ${compare ? 'aria-current="page"' : ''}>Compare all four</a><a href="?variant=${currentKey}" ${!compare ? 'aria-current="page"' : ''}>Focus on one</a></nav></header>${featureNav()}${compare ? `<main class="comparison">${keys.map(variantCard).join('')}</main>` : `<main class="single-layout">${variantCard(currentKey)}<aside class="direction-note"><span class="note-eyebrow">Direction ${currentKey} / ${variants[currentKey].label}</span><h2>${variants[currentKey].name}</h2><p>${variants[currentKey].description}</p><ol class="try-list"><li>Add a round.<span>Try 150 and −5. Switch between Type and Draw.</span></li><li>Change an earlier score.<span>Open round history, or tap a cell in Score first.</span></li><li>Keep the crew, change the game.<span>Finish a game. Pick the next preset from the recap.</span></li><li>See the night as a whole.<span>Open More → night recap. View results, then share the summary.</span></li></ol><div class="note-line"></div><p style="font-size:13px">${variants[currentKey].emphasis}</p></aside></main>`}<footer class="lab-footer"><p><strong>Clickable design study, not the iOS build.</strong> All names, results, and records are sample data. Scores and saved crews work in memory and reset on reload. Drawing uses simulated recognition (24). Viewer links carry a read-only score snapshot; they do not sync live.</p><details><summary>Prototype state · ${compare ? 'four independent examples' : variants[currentKey].name}</summary><pre id="state-inspector"></pre></details></footer><nav class="variant-switcher" aria-label="Design direction switcher"><button data-lab-action="previous" aria-label="Previous design direction">${icon('left')}</button><div class="current-variant"><small>Prototype direction · ← →</small><span>${currentKey} · ${variants[currentKey].name}</span></div><button data-lab-action="next" aria-label="Next design direction">${icon('chevron')}</button></nav>`;
  updateStateInspector();
  sizePhones();
  initDrawPads();
}
function renderPhone(key, focusDialog = false, focusPlayer = null) {
  const phone = document.querySelector(`[data-variant="${key}"]`);
  if (!phone) return;
  const previousSheet = phone.querySelector('[role="dialog"]')?.getAttribute('aria-label');
  const focusedControl = phone.contains(document.activeElement) ? controlKey(document.activeElement) : null;
  phone.innerHTML = phoneContent(states[key], key);
  if (previousSheet) phone.querySelector('.sheet-backdrop')?.classList.add('motion-static');
  sizePhones();
  updateStateInspector();
  initDrawPads();
  if (focusDialog) {
    const target = focusPlayer ? phone.querySelector(`[data-score="${focusPlayer}"]`) : phone.querySelector('[data-action="close-sheet"]');
    target?.focus({ preventScroll: true });
  } else {
    const controls = [...phone.querySelectorAll('button, input, select, a[href]')];
    const match = controls.find(element => sameControl(controlKey(element), focusedControl))
      || (!states[key].sheet && previousSheet ? controls.find(element => sameControl(controlKey(element), states[key].opener)) : null)
      || (states[key].sheet ? phone.querySelector('[data-action="close-sheet"]') : null);
    match?.focus({ preventScroll: true });
  }
}
function controlKey(element) { return element ? { action: element.dataset.action, player: element.dataset.player, preset: element.dataset.preset, crew: element.dataset.crew, round: element.dataset.round, score: element.dataset.score, form: element.dataset.form } : null; }
function sameControl(a, b) { return b && Object.values(b).some(Boolean) && Object.keys(a).every(key => a[key] === b[key]); }
function setToast(s, key, message) {
  s.toast = message;
  clearTimeout(s.toastTimer);
  s.toastTimer = setTimeout(() => { s.toast = ''; const toast = document.querySelector(`[data-variant="${key}"] .toast`); toast?.remove(); }, 2800);
}
function openScores(s, round = null, playerId = null) {
  s.sheet = 'scores'; s.mode = 'type'; s.editRound = round; s.error = ''; s.drawn = false; s.recognized = false;
  s.selectedPlayer = playerId || s.players[0].id;
  s.draft = round !== null ? Object.fromEntries(s.players.map(p => [p.id, String(s.rounds[round][p.id])])) : Object.fromEntries(s.players.map(p => [p.id, '']));
}
function finishGame(s) {
  if (!s.active || !s.rounds.length) return false;
  const sorted = rankings(s);
  const tied = sorted.filter(p => p.score === sorted[0].score);
  const margin = Math.abs((sorted[1]?.score || 0) - sorted[0].score);
  const recordKey = `${sorted[0].id}:${s.game}`;
  const previousMargin = s.records[recordKey];
  const record = tied.length === 1 && previousMargin !== undefined && margin > previousMargin;
  if (tied.length === 1) s.records[recordKey] = Math.max(previousMargin || 0, margin);
  s.completed.push({ name: s.game, winner: tied.map(p => p.name).join(' & '), winnerId: sorted[0].id, winnerIds: tied.map(p => p.id), note: tied.length > 1 ? 'A shared win' : margin ? `Won by ${margin} points` : 'First game in the books', recordValue: record ? margin : null, recordPrevious: previousMargin });
  s.active = false;
  return true;
}
function startNextGame(s) {
  const crew = nextCrew(s);
  const newNight = s.nightFinished || crew.id !== s.crewId;
  if (!newNight) finishGame(s);
  else { s.completed = []; s.nightFinished = false; }
  const preset = s.presets.find(p => p.id === s.presetId) || s.presets[0];
  s.crewId = crew.id; s.selectedCrewId = crew.id; s.nextCrewId = null;
  s.activePresetId = preset.id;
  if (newNight) s.night = crew.id === 'friday' ? 'Friday night' : `${crew.name} night`;
  s.players = structuredClone(crew.players);
  s.game = preset.game; s.direction = preset.direction; s.roundGoal = preset.rounds;
  s.rounds = []; s.active = true; s.sheet = null; s.route = 'night';
}

document.addEventListener('click', async event => {
  const labControl = event.target.closest('[data-lab-action]');
  if (labControl) { cycleVariant(labControl.dataset.labAction === 'next' ? 1 : -1); return; }
  const target = event.target.closest('[data-action]');
  if (!target || target.disabled) return;
  const phone = target.closest('[data-variant]');
  if (!phone || viewerOnly) return;
  const key = phone.dataset.variant;
  const s = states[key];
  currentKey = key;
  const action = target.dataset.action;
  const previousSheet = s.sheet;
  let focusDialog = false;
  let focusPlayer = null;
  if (['night', 'game', 'games', 'more', 'crews', 'recap', 'rounds', 'table'].includes(action)) { s.route = action; s.sheet = null; }
  else if (action === 'add-round' || action === 'add-player-score') { openScores(s, null, target.dataset.player); focusDialog = true; focusPlayer = target.dataset.player; }
  else if (action === 'edit-round') { openScores(s, Number(target.dataset.round), target.dataset.player); focusDialog = true; focusPlayer = target.dataset.player; }
  else if (action === 'close-sheet') { s.sheet = null; s.error = ''; }
  else if (action === 'type-mode' || action === 'draw-mode') { s.mode = action === 'type-mode' ? 'type' : 'draw'; s.error = ''; s.drawn = false; s.recognized = false; }
  else if (action === 'draw-player') { s.selectedPlayer = target.dataset.player; s.drawn = false; s.recognized = false; }
  else if (action === 'clear-draw') { s.drawn = false; s.recognized = false; }
  else if (action === 'recognize-draw') { if (s.drawn) s.recognized = true; else s.error = 'Write a score first, or choose Type.'; }
  else if (action === 'use-recognition') { s.draft[s.selectedPlayer] = '24'; s.recognized = false; s.drawn = false; s.mode = 'type'; }
  else if (action === 'save-round') {
    if (s.players.some(p => !/^-?\d{1,6}$/.test(String(s.draft[p.id] ?? '')))) { s.error = 'Enter a whole-number score for each player. Use 0 if needed.'; }
    else {
      const scores = Object.fromEntries(s.players.map(p => [p.id, Number(s.draft[p.id])]));
      if (s.editRound !== null) s.rounds[s.editRound] = scores;
      else s.rounds.push(scores);
      const edited = s.editRound !== null;
      s.sheet = null; s.error = ''; s.editRound = null;
      setToast(s, key, edited ? 'Round corrected. Totals updated.' : `Round ${s.rounds.length} saved.`);
    }
  }
  else if (action === 'finish-game') { if (finishGame(s)) { s.route = 'recap'; s.sheet = null; } else setToast(s, key, 'Add a round before finishing this game.'); }
  else if (action === 'next-game' || action === 'presets') { s.sheet = action; s.nextCrewId = null; s.error = ''; focusDialog = true; }
  else if (action === 'select-preset') { s.presetId = target.dataset.preset; }
  else if (action === 'preset-from-crew') { s.presetId = target.dataset.preset; s.nextCrewId = s.selectedCrewId; s.sheet = 'next-game'; focusDialog = true; }
  else if (action === 'start-next-game') { startNextGame(s); setToast(s, key, `${s.game} is ready. Your crew stays together.`); }
  else if (action === 'select-crew') { s.selectedCrewId = target.dataset.crew; }
  else if (action === 'new-crew' || action === 'new-preset') { s.returnSheet = ['next-game', 'presets'].includes(s.sheet) ? s.sheet : null; s.sheet = action; s.formDraft = {}; s.error = ''; focusDialog = true; }
  else if (action === 'save-crew') {
    const name = phone.querySelector('[name="crew-name"]').value.trim();
    const names = phone.querySelector('[name="crew-players"]').value.split(',').map(n => n.trim()).filter(Boolean);
    if (!name || names.length < 2 || names.length > 4) { s.error = 'Add a name and 2–4 players, separated by commas.'; }
    else {
      const id = `crew-${s.crews.length + 1}`;
      s.crews.push({ id, name, detail: 'Saved just now. Ready next time.', players: names.map((n, i) => ({ ...structuredClone(originalPlayers[i]), id: `${id}-${i}`, name: n, initials: n.slice(0, 1).toUpperCase() })) });
      s.selectedCrewId = id; s.sheet = null; setToast(s, key, `${name} saved.`);
    }
  }
  else if (action === 'save-preset') {
    const name = phone.querySelector('[name="preset-name"]').value.trim();
    const game = phone.querySelector('[name="preset-game"]').value.trim();
    if (!name || !game) s.error = 'Give the preset and game a name.';
    else {
      const id = `preset-${s.presets.length + 1}`;
      s.presets.push({ id, name, game, direction: phone.querySelector('[name="preset-direction"]').value, rounds: Number(phone.querySelector('[name="preset-rounds"]').value) });
      s.presetId = id; s.sheet = s.returnSheet; s.returnSheet = null; setToast(s, key, `${name} saved.`);
    }
  }
  else if (action === 'share-night' || action === 'finish-night') { s.sheet = action; focusDialog = true; }
  else if (action === 'confirm-finish-night') { finishGame(s); s.active = false; s.nightFinished = true; s.route = 'recap'; s.sheet = null; setToast(s, key, 'Night saved. Same crew, next time.'); }
  else if (action === 'copy-recap') {
    try { await navigator.clipboard.writeText(shareText(s)); setToast(s, key, 'Recap text copied.'); s.sheet = null; }
    catch { s.error = 'Copy the recap text above. Clipboard access is unavailable.'; setToast(s, key, s.error); }
  }
  if (!previousSheet && s.sheet) s.opener = controlKey(target);
  renderPhone(key, focusDialog, focusPlayer);
  const switcher = document.querySelector('.current-variant > span');
  if (switcher) switcher.textContent = `${currentKey} · ${variants[currentKey].name}`;
  updateURL();
});
document.addEventListener('input', event => {
  const formTarget = event.target.closest('[data-form]');
  if (formTarget) {
    const key = formTarget.closest('[data-variant]').dataset.variant;
    states[key].formDraft[formTarget.dataset.form] = formTarget.value;
    return;
  }
  const target = event.target.closest('[data-score]');
  if (!target) return;
  const key = target.closest('[data-variant]').dataset.variant;
  states[key].draft[target.dataset.score] = target.value;
  states[key].error = '';
  target.closest('.sheet').querySelector('.error-message').textContent = '';
  updateStateInspector();
});
document.addEventListener('keydown', event => {
  const phone = event.target.closest('[data-variant]');
  if (event.key === 'Escape' && phone && states[phone.dataset.variant].sheet) { states[phone.dataset.variant].sheet = null; renderPhone(phone.dataset.variant); return; }
  const dialog = event.target.closest('[role="dialog"]');
  if (event.key === 'Tab' && dialog) {
    const focusable = [...dialog.querySelectorAll('button:not(:disabled), input, select, a[href]')];
    const first = focusable[0]; const last = focusable.at(-1);
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  }
  if (['ArrowLeft', 'ArrowRight'].includes(event.key) && event.target.matches('[role="tab"]')) {
    event.preventDefault();
    const tabs = [...event.target.closest('[role="tablist"]').querySelectorAll('[role="tab"]')];
    tabs[(tabs.indexOf(event.target) + 1) % tabs.length].click();
    return;
  }
  if (['ArrowLeft', 'ArrowRight'].includes(event.key) && !event.target.closest('input, textarea, select, [contenteditable="true"], [data-variant]')) { event.preventDefault(); cycleVariant(event.key === 'ArrowRight' ? 1 : -1); }
});
function updateURL() { const next = new URL(location.href); next.searchParams.set('variant', currentKey); if (compare) next.searchParams.set('view', 'compare'); else next.searchParams.delete('view'); history.replaceState(null, '', next); }
function cycleVariant(delta) {
  if (viewerOnly) return;
  currentKey = keys[(keys.indexOf(currentKey) + delta + keys.length) % keys.length];
  updateURL();
  renderLab();
  if (compare) document.querySelector(`[data-variant="${currentKey}"]`).closest('.variant-card').scrollIntoView({ behavior: 'instant', block: 'nearest', inline: 'nearest' });
}
function initDrawPads() {
  for (const canvas of document.querySelectorAll('.draw-pad')) {
    if (canvas.dataset.ready) continue;
    canvas.dataset.ready = 'true';
    const key = canvas.closest('[data-variant]').dataset.variant;
    const s = states[key];
    const ratio = Math.min(devicePixelRatio || 1, 3);
    canvas.width = Math.round(canvas.clientWidth * ratio); canvas.height = Math.round(canvas.clientHeight * ratio);
    const context = canvas.getContext('2d');
    context.scale(ratio, ratio); context.strokeStyle = getComputedStyle(canvas).getPropertyValue('--ink').trim(); context.lineWidth = 5; context.lineCap = 'round'; context.lineJoin = 'round';
    let activePointer = null;
    const point = event => { const bounds = canvas.getBoundingClientRect(); return [(event.clientX - bounds.left) * canvas.clientWidth / bounds.width, (event.clientY - bounds.top) * canvas.clientHeight / bounds.height]; };
    canvas.addEventListener('pointerdown', event => {
      if (!event.isPrimary || (event.pointerType === 'mouse' && event.button !== 0) || activePointer !== null) return;
      event.preventDefault(); activePointer = event.pointerId; canvas.setPointerCapture(event.pointerId); context.beginPath(); context.moveTo(...point(event)); s.drawn = true; s.error = ''; canvas.closest('.sheet').querySelector('.error-message').textContent = '';
    });
    canvas.addEventListener('pointermove', event => { if (activePointer !== event.pointerId) return; context.lineTo(...point(event)); context.stroke(); });
    const end = event => { if (activePointer !== event.pointerId) return; if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId); activePointer = null; };
    canvas.addEventListener('pointerup', end); canvas.addEventListener('pointercancel', end); canvas.addEventListener('lostpointercapture', () => { activePointer = null; });
  }
}

const phoneSizer = new ResizeObserver(entries => {
  for (const entry of entries) entry.target.style.setProperty('--phone-scale', entry.target.clientWidth / 378);
});
function sizePhones() {
  for (const phone of document.querySelectorAll('.phone')) {
    phone.style.setProperty('--phone-scale', phone.clientWidth / 378);
    if (!phone.dataset.sized) { phone.dataset.sized = 'true'; phoneSizer.observe(phone); }
  }
}

renderLab();
