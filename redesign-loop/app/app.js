(() => {
  "use strict";

  const app = document.querySelector("#app");
  const root = document.documentElement;
  const STORAGE_KEY = "pipcount-state";
  const STORAGE_VERSION = 3;
  const VALID_SCREENS = new Set([
    "onboarding", "home", "choose", "setup", "gameSettings", "settings", "scoring",
    "gameOver", "history", "detail", "roster", "playerStats", "stats", "headToHead",
    "paywall", "legal",
  ]);
  const PLAYER_COLORS = ["accent", "ink"];
  const PLAYER_SHAPES = ["circle", "square", "triangle", "diamond"];
  const DEFAULT_PLAYERS = [
    { name: "You", color: "accent", shape: "circle" },
    { name: "Alex", color: "ink", shape: "square" },
  ];
  const MODE_CONFIG = {
    scoreboard: {
      name: "Scoreboard",
      eyebrow: "FREE COUNTING",
      description: "A clean ledger for any game. Set a target, then end when ready.",
      symbol: "++",
      settingLabel: "Target score",
      settingHint: "A target marker for the host. Finish when the table calls it.",
      defaultTarget: 100,
      defaultRounds: 6,
    },
    phases: {
      name: "Ten Phases",
      eyebrow: "ROUND RACE",
      description: "Keep every phase visible. The table ends after the final round.",
      symbol: "10",
      settingLabel: "Number of rounds",
      settingHint: "Finish each round to move the marker. Highest total wins.",
      defaultTarget: 10,
      defaultRounds: 10,
    },
    dinner: {
      name: "What's for Dinner",
      eyebrow: "DECISION GAME",
      description: "Score the table's choices until the obvious answer wins.",
      symbol: "?",
      settingLabel: "Number of rounds",
      settingHint: "Use each round to tally a new option. Highest total wins.",
      defaultTarget: 5,
      defaultRounds: 5,
    },
  };

  const state = {
    screen: "onboarding",
    onboardingComplete: false,
    theme: "light",
    followsSystemTheme: true,
    selectedMode: "scoreboard",
    draftPlayers: clone(DEFAULT_PLAYERS),
    gameSettings: { targetScore: 100, roundCount: 6, turnOrder: "seat" },
    currentGame: null,
    history: [],
    lastGameId: null,
    detailGameId: null,
    selectedPlayerName: null,
    headToHeadIds: [],
    setupErrors: {},
    sheet: null,
    modal: null,
    focusReturnAction: null,
    lastOverlayKey: null,
    toast: null,
    toastTimer: null,
    storageError: null,
    transitionDirection: "forward",
    scoreRepeatSuppress: false,
    scoreHintSeen: false,
    timer: {
      totalSeconds: 10 * 60,
      remainingSeconds: 10 * 60,
      running: false,
      completed: false,
      deadline: null,
      cueEnabled: false,
      cueUnavailable: false,
      audioContext: null,
      interval: null,
    },
    proUnlocked: false,
  };

  let activeViewTransition = null;

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function uid(prefix) {
    return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`;
  }

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  function modeConfig(mode = state.selectedMode) {
    return MODE_CONFIG[mode];
  }

  function formatDate(iso, long = false) {
    return new Intl.DateTimeFormat("en", {
      month: long ? "long" : "short",
      day: "numeric",
      year: long ? "numeric" : undefined,
    }).format(new Date(iso));
  }

  function formatTime(seconds) {
    const safeSeconds = Math.max(0, seconds);
    const minutes = Math.floor(safeSeconds / 60).toString().padStart(2, "0");
    const rest = (safeSeconds % 60).toString().padStart(2, "0");
    return `${minutes}:${rest}`;
  }

  function pluralize(count, singular, plural = `${singular}s`) {
    return `${count} ${count === 1 ? singular : plural}`;
  }

  function entityLabel(game, count) {
    return pluralize(count, game?.mode === "dinner" ? "choice" : "player");
  }

  function outcomeForPlayers(players) {
    const topScore = Math.max(...players.map((player) => Number(player.score) || 0), 0);
    const winnerNames = players.filter((player) => (Number(player.score) || 0) === topScore).map((player) => player.name);
    return {
      result: winnerNames.length === 1 ? "win" : "tie",
      winnerNames,
      winnerName: winnerNames.length === 1 ? winnerNames[0] : null,
      topScore,
    };
  }

  function normalizeGame(game) {
    if (!game || !Array.isArray(game.players) || !game.players.length) return null;
    const players = game.players.map((player, index) => ({
      id: player.id || `${game.id || "game"}-p${index}`,
      name: String(player.name || `Player ${index + 1}`),
      color: PLAYER_COLORS.includes(player.color) ? player.color : "ink",
      shape: PLAYER_SHAPES.includes(player.shape) ? player.shape : PLAYER_SHAPES[index % PLAYER_SHAPES.length],
      score: Math.max(0, Number(player.score) || 0),
    }));
    const roundCount = Math.max(2, Number(game.roundCount) || 2);
    const roundLimit = game.mode === "scoreboard" ? Infinity : roundCount;
    const roundsByNumber = new Map();
    (Array.isArray(game.rounds) ? game.rounds : []).forEach((round) => {
      const number = Number(round?.number);
      if (!round || !Number.isFinite(number) || number < 1 || number > roundLimit) return;
      const savedScores = new Map((Array.isArray(round.scores) ? round.scores : []).map((score) => [String(score.name), score.score]));
      roundsByNumber.set(number, {
        ...round,
        number,
        scores: players.map((player) => ({ name: player.name, score: Math.max(0, Number(savedScores.get(player.name)) || 0) })),
      });
    });
    const outcome = outcomeForPlayers(players);
    return {
      ...game,
      id: game.id || uid("game"),
      players,
      rounds: [...roundsByNumber.values()].sort((a, b) => a.number - b.number),
      roundCount,
      targetScore: Math.max(10, Number(game.targetScore) || 10),
      result: outcome.result,
      winnerNames: outcome.winnerNames,
      winnerName: outcome.winnerName,
    };
  }

  function normalizeCurrentGame(game) {
    if (!game || !Array.isArray(game.players) || !game.players.length) return null;
    const normalized = normalizeGame(game);
    normalized.round = Math.max(1, Number(game.round) || 1);
    normalized.undoStack = Array.isArray(game.undoStack) ? game.undoStack : [];
    normalized.activePlayerIndex = Math.max(0, Math.min(normalized.players.length - 1, Number(game.activePlayerIndex) || 0));
    delete normalized.result;
    delete normalized.winnerNames;
    delete normalized.winnerName;
    return normalized;
  }

  function persistableState() {
    return {
      version: STORAGE_VERSION,
      screen: state.currentGame ? "scoring" : state.screen,
      onboardingComplete: state.onboardingComplete,
      theme: state.theme,
      followsSystemTheme: state.followsSystemTheme,
      selectedMode: state.selectedMode,
      draftPlayers: clone(state.draftPlayers),
      gameSettings: clone(state.gameSettings),
      currentGame: state.currentGame ? clone(state.currentGame) : null,
      history: clone(state.history),
      lastGameId: state.lastGameId,
      detailGameId: state.detailGameId,
      selectedPlayerName: state.selectedPlayerName,
      headToHeadIds: clone(state.headToHeadIds),
      scoreHintSeen: state.scoreHintSeen,
      proUnlocked: state.proUnlocked,
      timer: {
        totalSeconds: state.timer.totalSeconds,
        remainingSeconds: state.timer.remainingSeconds,
        running: state.timer.running,
        completed: state.timer.completed,
        deadline: state.timer.deadline,
        cueEnabled: state.timer.cueEnabled,
      },
    };
  }

  function persist() {
    let saved = false;
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(persistableState()));
      saved = true;
      state.storageError = null;
    } catch (error) {
      state.storageError = "Changes could not be saved on this device.";
    }
    const existingToast = app.querySelector(".toast");
    if (existingToast) {
      if (state.storageError || state.toast) existingToast.outerHTML = renderToast();
      else existingToast.remove();
    } else if (state.storageError && app.innerHTML) {
      app.insertAdjacentHTML("beforeend", renderToast());
    }
    return saved;
  }

  function hydrate() {
    let saved;
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY);
      saved = raw ? JSON.parse(raw) : null;
    } catch (error) {
      state.storageError = "Saved game data could not be read. Starting with a clean ledger.";
      return;
    }

    const systemTheme = window.matchMedia?.("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    if (!saved || typeof saved !== "object") {
      state.theme = systemTheme;
      state.followsSystemTheme = true;
      return;
    }

    state.theme = saved.theme === "dark" ? "dark" : saved.theme === "light" ? "light" : systemTheme;
    state.followsSystemTheme = saved.followsSystemTheme !== false;
    state.onboardingComplete = Boolean(saved.onboardingComplete);
    state.selectedMode = MODE_CONFIG[saved.selectedMode] ? saved.selectedMode : "scoreboard";
    state.draftPlayers = Array.isArray(saved.draftPlayers) && saved.draftPlayers.length
      ? saved.draftPlayers.map((player, index) => ({ ...player, color: PLAYER_COLORS.includes(player.color) ? player.color : "ink", shape: PLAYER_SHAPES.includes(player.shape) ? player.shape : PLAYER_SHAPES[index % PLAYER_SHAPES.length] }))
      : clone(DEFAULT_PLAYERS);
    state.gameSettings = { ...state.gameSettings, ...(saved.gameSettings || {}) };
    state.history = Array.isArray(saved.history) ? saved.history.map(normalizeGame).filter(Boolean).sort((a, b) => new Date(b.finishedAt) - new Date(a.finishedAt)) : [];
    state.currentGame = normalizeCurrentGame(saved.currentGame);
    state.lastGameId = saved.lastGameId || state.history[0]?.id || null;
    state.detailGameId = saved.detailGameId || null;
    state.selectedPlayerName = saved.selectedPlayerName || null;
    state.headToHeadIds = Array.isArray(saved.headToHeadIds) ? saved.headToHeadIds : [];
    state.scoreHintSeen = Boolean(saved.scoreHintSeen);
    state.proUnlocked = Boolean(saved.proUnlocked);
    state.timer = { ...state.timer, ...(saved.timer || {}), interval: null, audioContext: null };
    state.timer.totalSeconds = Math.max(60, Number(state.timer.totalSeconds) || 10 * 60);
    state.timer.remainingSeconds = Math.max(0, Number(state.timer.remainingSeconds) || 0);
    if (state.timer.running) {
      if (!state.timer.deadline) {
        state.timer.running = false;
      } else {
        const remaining = Math.ceil((state.timer.deadline - Date.now()) / 1000);
        state.timer.remainingSeconds = Math.max(0, remaining);
        if (!remaining) {
          state.timer.running = false;
          state.timer.completed = true;
          state.timer.deadline = null;
        }
      }
    }

    const savedScreen = VALID_SCREENS.has(saved.screen) ? saved.screen : state.onboardingComplete ? "home" : "onboarding";
    state.screen = state.currentGame ? "scoring" : savedScreen;
    if (state.screen === "onboarding" && state.onboardingComplete) state.screen = "home";
  }

  function resultLabel(game) {
    const names = game.winnerNames || [];
    if (game.result === "tie" || names.length > 1) return `${names.join(" and ")} tied`;
    return names[0] || game.winnerName || "No winner";
  }

  function resultSentence(game, verb = "won") {
    const names = game.winnerNames || [];
    if (game.result === "tie" || names.length > 1) return `${names.join(" and ")} tied at ${outcomeForPlayers(game.players).topScore}.`;
    return `${escapeHtml(names[0] || game.winnerName || "No winner")} ${verb} the table.`;
  }

  function leadingSentence(player, score) {
    return player?.name === "You" ? `You lead with ${score}.` : `${escapeHtml(player?.name || "Nobody")} is leading with ${score}.`;
  }

  function setTheme(theme) {
    state.theme = theme;
    root.dataset.theme = theme;
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute("content", theme === "dark" ? "#121218" : "#f0f0e4");
  }

  function showToast(message, kind = "info", options = {}) {
    state.toast = { message, kind };
    const toastState = state.toast;
    window.clearTimeout(state.toastTimer);
    state.toastTimer = window.setTimeout(() => {
      const toast = app.querySelector(".toast");
      if (toast) {
        toast.dataset.closing = "true";
        window.setTimeout(() => {
          if (state.toast !== toastState) return;
          state.toast = null;
          state.toastTimer = null;
          render(false);
        }, 180);
      } else {
        state.toast = null;
        state.toastTimer = null;
      }
    }, 3400);
    if (options.preserveScoring && state.screen === "scoring" && !state.modal && !state.sheet) {
      const current = app.querySelector(".toast");
      if (current) current.outerHTML = renderToast();
      else app.insertAdjacentHTML("beforeend", renderToast());
    } else {
      render(false);
    }
  }

  function captureFocusReturn() {
    const active = document.activeElement;
    const control = active?.closest?.("[data-action]");
    state.focusReturnAction = control?.id
      ? `#${control.id}`
      : control?.dataset.focusKey
        ? `focus-key:${control.dataset.focusKey}`
        : control?.dataset.action || null;
  }

  function applyRoute(screen, extra = {}, animate = true, direction = "forward") {
    state.screen = screen;
    Object.assign(state, extra);
    state.modal = null;
    state.sheet = null;
    state.transitionDirection = direction;
    render(animate, direction);
  }

  function navigate(screen, extra = {}, options = {}) {
    if (!VALID_SCREENS.has(screen)) return;
    if (screen === "home") state.onboardingComplete = true;
    const route = { app: "pipcount", screen, depth: options.replace ? 0 : (window.history.state?.app === "pipcount" ? window.history.state.depth || 0 : 0) + 1, ...extra };
    if (options.replace) {
      window.history.replaceState(route, "", `#${screen}`);
    } else {
      window.history.pushState(route, "", `#${screen}`);
    }
    persist();
    applyRoute(screen, extra, options.animate !== false, options.direction || "forward");
  }

  function goBack() {
    if (state.modal || state.sheet) {
      closeOverlay();
      return;
    }
    if (state.screen === "scoring") {
      openEndGameModal();
      return;
    }
    if (window.history.state?.app === "pipcount" && (window.history.state.depth || 0) > 0) {
      window.history.back();
    } else if (state.screen !== "home") {
      navigate("home", {}, { replace: true, direction: "back" });
    }
  }

  function restoreScoringHistoryEntry() {
    const currentDepth = window.history.state?.app === "pipcount" ? window.history.state.depth || 0 : 0;
    window.history.pushState({ app: "pipcount", screen: "scoring", depth: currentDepth + 1 }, "", "#scoring");
    state.screen = "scoring";
  }

  function navTabs() {
    if (!["home", "history", "roster", "stats"].includes(state.screen)) return "";
    return `<nav class="bottom-nav" aria-label="Primary navigation">
      ${navItem("home", "home", "Home", state.screen === "home")}
      ${navItem("history", "history", "History", state.screen === "history")}
      ${navItem("roster", "roster", "Roster", state.screen === "roster")}
      ${navItem("stats", "stats", "Stats", state.screen === "stats")}
    </nav>`;
  }

  function navItem(screen, icon, label, selected) {
    return `<button class="nav-item ${selected ? "is-active" : ""}" data-action="navigate" data-screen="${screen}" aria-current="${selected ? "page" : "false"}">
      <span class="nav-icon nav-icon--${icon}" aria-hidden="true"></span><span class="nav-label">${label}</span>
    </button>`;
  }

  function topbar({ title, kicker = "SCOREKEEPER", home = false, back = true, action = null } = {}) {
    const left = home ? "" : back ? `<button class="back-button" data-action="back" aria-label="Go back">Back</button>` : `<span></span>`;
    const right = action
      ? `<button class="button button--quiet button--small" data-action="${action.action}" ${action.screen ? `data-screen="${action.screen}"` : ""} aria-label="${escapeHtml(action.label)}">${escapeHtml(action.label)}</button>`
      : `<div class="topbar__actions">${home ? `<button class="icon-button" data-action="open-settings" aria-label="Open settings">Settings</button>` : ""}<button class="icon-button" data-action="toggle-theme" data-focus-key="theme-toggle" aria-label="Toggle light and dark theme">${state.theme === "light" ? "Dark" : "Light"}</button></div>`;
    return `<header class="topbar ${home ? "topbar--home" : ""}">${left}<div class="topbar__title ${home ? "brand-lockup" : ""}">${home ? `<span class="brand-mark" aria-hidden="true">PC</span>` : ""}<span><span class="topbar__kicker">${escapeHtml(kicker)}</span><strong class="topbar__name">${escapeHtml(title)}</strong></span></div>${right}</header>`;
  }

  function page(title, body, options = {}) {
    const blocked = state.sheet || state.modal;
    return `<div class="view-shell view-shell--${state.screen}"><div class="screen-content"${blocked ? ' aria-hidden="true" inert' : ""}>${topbar({ title, kicker: options.kicker, back: options.back !== false, home: options.home, action: options.action })}
      <div class="scroll-area"><main class="content">${body}</main></div>${navTabs()}</div>${state.sheet ? renderSheet() : ""}${state.modal ? renderModal() : ""}
    </div>`;
  }

  function render(animate = true, direction = state.transitionDirection) {
    if (!state.focusReturnAction && !state.modal && !state.sheet && app.contains(document.activeElement)) captureFocusReturn();
    setTheme(state.theme);
    app.classList.toggle("no-motion", !animate);
    app.dataset.navDirection = direction;
    app.dataset.overlayOnly = state.modal || state.sheet ? "true" : "false";
    const update = () => {
      app.innerHTML = `${renderScreen()}${state.toast || state.storageError ? renderToast() : ""}`;
      syncRenderedState();
      updateTimerDom();
      manageOverlayFocus();
      if (animate) requestAnimationFrame(() => app.classList.remove("no-motion"));
    };
    const overlayOnly = Boolean(state.modal || state.sheet);
     const frequentRoute = ["home", "history", "roster", "stats"].includes(state.screen);
     const reducedMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
     if (activeViewTransition) activeViewTransition.skipTransition?.();
     if (animate && !overlayOnly && !frequentRoute && !reducedMotion && document.startViewTransition) {
       activeViewTransition = document.startViewTransition(update);
       activeViewTransition.finished.then(() => { activeViewTransition = null; }, () => { activeViewTransition = null; });
     } else {
       if (animate && frequentRoute && !reducedMotion) app.classList.add("route-fade");
       update();
       if (animate && frequentRoute && !reducedMotion) requestAnimationFrame(() => app.classList.remove("route-fade"));
     }
   }

  function syncRenderedState() {
    app.querySelectorAll(".segmented__button, .chip").forEach((control) => {
      control.setAttribute("aria-pressed", String(control.classList.contains("is-active")));
    });
    if (state.currentGame) {
      app.querySelectorAll('[data-action="change-score"]').forEach((control) => {
        const player = state.currentGame.players.find((item) => item.id === control.dataset.playerId);
        if (!player) return;
        const noun = state.currentGame.mode === "dinner" ? `choice ${player.name}` : player.name;
         const amount = Math.abs(Number(control.dataset.delta) || 1);
         control.setAttribute("aria-label", `${Number(control.dataset.delta) > 0 ? "Add" : "Subtract"} ${pluralize(amount, "point")} ${Number(control.dataset.delta) > 0 ? "to" : "from"} ${noun}`);
      });
    }
    app.querySelectorAll(".ledger, .final-ledger, .table").forEach((table) => {
      table.setAttribute("role", "table");
      const rows = [...table.querySelectorAll(":scope > .ledger-row, :scope > .final-row, :scope > .table-row")];
      table.setAttribute("aria-rowcount", String(rows.length));
      rows.forEach((row, index) => {
        row.setAttribute("role", "row");
        row.setAttribute("aria-rowindex", String(index + 1));
        row.querySelectorAll(":scope > *").forEach((cell) => cell.setAttribute("role", "cell"));
      });
    });
    syncRenderedCopy();
    const themeRow = app.querySelector('.settings-row[data-action="toggle-theme"]');
    if (themeRow) themeRow.setAttribute("aria-pressed", String(state.theme === "dark"));
    if (state.screen === "paywall") {
      const card = app.querySelector(".card--pro");
      const title = card?.querySelector(".card-title");
      const rows = card?.querySelector(".row-stack");
      const hint = app.querySelector(".card--pro + .field-hint");
      const stamp = card?.querySelector(".stamp");
      if (stamp) stamp.textContent = "LOCAL ENTITLEMENT";
      if (title) title.textContent = state.proUnlocked ? "Local access is active." : "Prototype access state.";
      if (rows) rows.innerHTML = `<div class="option-row"><div><div class="option-title">Local access</div><div class="option-subtitle">A demo flag stored on this device.</div></div><span class="pip circle accent"></span></div><div class="option-row"><div><div class="option-title">No purchase attached</div><div class="option-subtitle">This static prototype cannot verify a receipt.</div></div><span class="pip square ink"></span></div>`;
      if (hint) hint.textContent = "This screen demonstrates entitlement copy only. It does not sell or unlock a premium feature.";
    }
  }

  function syncRenderedCopy() {
    if (state.screen === "gameOver") {
      const game = state.history.find((item) => item.id === state.lastGameId) || state.history[0];
      const copy = app.querySelector(".winner-lockup p");
      if (game && copy) copy.textContent = `${game.modeName} finished after ${pluralize(game.rounds.length, "round")}. That one is filed in history.`;
    }
    if (state.screen === "detail") {
      const game = state.history.find((item) => item.id === state.detailGameId) || state.history[0];
      const copy = app.querySelector(".hero .lede");
      if (game && copy) copy.textContent = `${pluralize(game.rounds.length, "round")}, ${entityLabel(game, game.players.length)}, one final ledger.`;
      const ledger = app.querySelector(".final-ledger");
      const roundLabel = ledger?.parentElement?.querySelector(".section-heading .section-label");
      if (game && roundLabel) roundLabel.textContent = pluralize(game.rounds.length, "round");
    }
    app.querySelectorAll(".history-item").forEach((item) => {
      const game = state.history.find((entry) => entry.id === item.dataset.gameId);
      const meta = item.querySelector(".history-item__meta");
      if (game && meta) meta.textContent = `${formatDate(game.finishedAt, true)} / ${entityLabel(game, game.players.length)} / ${pluralize(game.rounds.length, "round")}`;
    });
    app.querySelectorAll('.row-button[data-action="open-player-stats"]').forEach((item) => {
      const stats = getPlayerStats(item.dataset.playerName);
      const meta = item.querySelector(".row-button__meta");
      if (meta) meta.textContent = `${pluralize(stats.games.length, "game")} / ${pluralize(stats.wins, "win")}`;
    });
    const latest = state.history.find((item) => item.id === state.lastGameId) || state.history[0];
    const homeMeta = app.querySelector(".latest-result .card-copy, .hero-card .card-copy");
    if (latest && homeMeta) homeMeta.textContent = `${latest.modeName} / ${formatDate(latest.finishedAt, true)} / ${entityLabel(latest, latest.players.length)}`;
  }

  function renderScreen() {
    switch (state.screen) {
      case "onboarding": return renderOnboarding();
      case "home": return renderHome();
      case "choose": return renderChoose();
      case "setup": return renderSetup();
      case "gameSettings": return renderGameSettings();
      case "settings": return renderSettings();
      case "scoring": return renderScoring();
      case "gameOver": return renderGameOver();
      case "history": return renderHistory();
      case "detail": return renderDetail();
      case "roster": return renderRoster();
      case "playerStats": return renderPlayerStats();
      case "stats": return renderStats();
      case "headToHead": return renderHeadToHead();
      case "paywall": return renderPaywall();
      case "legal": return renderLegal();
      default: return renderHome();
    }
  }

  function renderOnboarding() {
    return `<div class="view-shell view-shell--onboarding">
       <header class="topbar topbar--home"><div class="brand-lockup"><span class="brand-mark" aria-hidden="true">SK</span><span><span class="topbar__kicker">SCOREKEEPER</span><strong class="topbar__name">ScoreKeeper</strong></span></div><div class="topbar__actions"><button class="icon-button" data-action="toggle-theme" aria-label="Toggle light and dark theme">${state.theme === "light" ? "Dark" : "Light"}</button></div></header>
      <div class="scroll-area"><main class="onboarding-content">
        <section class="hero"><span class="eyebrow">A paper pad with a memory</span><h1>Keep the table moving.</h1><p>Set up a crew, score the round, keep the timer close, and leave game night with a result worth remembering.</p></section>
         <div class="onboarding-promise" aria-label="ScoreKeeper game loop">
          <div class="promise-row stagger-item"><strong class="promise-index">01</strong><div><strong>Setup in one breath</strong><span>Add a crew and choose the game.</span></div></div>
          <div class="promise-row stagger-item"><strong class="promise-index">02</strong><div><strong>Score without a detour</strong><span>One ledger, one undo, clear leaders.</span></div></div>
          <div class="promise-row stagger-item"><strong class="promise-index">03</strong><div><strong>Keep the night</strong><span>History, rosters, and rematches stay ready.</span></div></div>
        </div>
        <div class="onboarding-actions"><button class="button button--primary button--full" data-action="start-onboarding-game">Start a game</button><button class="text-button" data-action="seed-demo">Load a sample night instead</button><button class="text-button" data-action="skip-onboarding">Skip for now</button></div>
      </main></div>
    </div>`;
  }

  function renderHome() {
    return page("ScoreKeeper", state.history.length ? renderHomeWithHistory(state.history[0]) : renderHomeEmpty(), { home: true, back: false, kicker: "SCOREKEEPER" });
  }

  function renderHomeEmpty() {
    return `<section class="hero"><span class="eyebrow">Your table, in sync</span><h1>Make the score the quiet part.</h1><p>Everything you need for a fast game night, nothing that asks to be the main event.</p></section>
      <div class="stack stack--large"><section class="card card--accent card--split"><div><span class="section-label">First round</span><h2 class="card-title">Start a new game</h2><p class="card-copy">Pick a format, add your crew, and go.</p></div><button class="button button--secondary" data-action="new-game">New game</button></section>
      <button class="timer-banner row-button" data-action="open-timer"><span><strong data-timer-banner-value>${formatTime(state.timer.remainingSeconds)}</strong><span>Table timer / ${state.timer.running ? "running" : "ready"}</span></span><span class="button--small">Open &rarr;</span></button>
      <section class="empty-state"><span class="empty-state__mark">0</span><h2>No games on the ledger yet.</h2><p class="empty-copy">Play one game or load a sample night to see history, stats, and rematches in motion.</p><div class="button-row"><button class="button button--secondary" data-action="seed-demo">Load sample history</button><button class="button button--quiet" data-action="navigate" data-screen="roster">View roster</button></div></section></div>`;
  }

  function renderHomeWithHistory(latest) {
    const topScore = outcomeForPlayers(latest.players).topScore;
    const outcome = latest.result === "tie" ? `${(latest.winnerNames || []).map(escapeHtml).join(" and ")} tied` : `${escapeHtml(latest.winnerName || "No winner")} took it`;
    return `<section class="hero"><span class="eyebrow">Welcome back to the table</span><h1>Keep the streak warm.</h1><p>Your latest result is filed. The next round is one tap away.</p></section>
      <div class="stack stack--large"><button class="latest-result" data-action="open-detail" data-game-id="${latest.id}" aria-label="Open latest result"><div><span class="stamp ${latest.result === "tie" ? "stamp--tie" : "stamp--yellow"}">${latest.result === "tie" ? "TIED RESULT" : "LATEST RESULT"}</span><h2 class="card-title">${outcome}.</h2><p class="card-copy">${escapeHtml(latest.modeName)} / ${formatDate(latest.finishedAt, true)} / ${latest.players.length} players</p></div><div class="history-item__score"><strong>${topScore}</strong><span>final score</span></div></button>
        <section class="card card--accent"><div class="card-split"><div><span class="section-label">Ready when you are</span><h2 class="card-title">Run it back.</h2><p class="card-copy">Same crew, clean slate.</p></div></div><div class="button-row home-actions"><button class="button button--secondary" data-action="rematch" data-game-id="${latest.id}">Rematch now</button><button class="button button--secondary" data-action="new-game">New game</button></div></section>
       <button class="timer-banner row-button" data-action="open-timer"><span><strong data-timer-banner-value>${formatTime(state.timer.remainingSeconds)}</strong><span>Table timer / ${state.timer.running ? "running" : "ready"}</span></span><span class="button--small">Open &rarr;</span></button>
       <div><div class="section-heading"><h2>Recent games</h2><button class="text-button" data-action="navigate" data-screen="history">See all</button></div>${state.history.slice(0, 2).map(renderHistoryItem).join("")}</div></div>`;
  }

  function renderChoose() {
    const covers = Object.entries(MODE_CONFIG).map(([id, config]) => `<button class="game-cover ${state.selectedMode === id ? "is-selected" : ""} stagger-item" data-action="select-mode" data-mode="${id}" aria-pressed="${state.selectedMode === id}"><span class="game-cover__top"><span class="section-label">${config.eyebrow}</span><span class="cover-symbol cover-symbol--${id === "scoreboard" ? "circle" : id === "phases" ? "square" : "triangle"}">${config.symbol}</span></span><span class="game-cover__bottom"><span><strong class="game-cover__title">${config.name}</strong><span class="game-cover__copy">${config.description}</span></span><span class="button--small">${state.selectedMode === id ? "Selected" : "Choose"}</span></span></button>`).join("");
    return page("Choose a game", `<section class="hero"><span class="eyebrow">01 / Format</span><h1 class="page-title">Pick the shape of the night.</h1><p class="lede">Every format keeps the same reliable ledger. Choose the rules that fit the table.</p></section><div class="game-grid">${covers}</div><div class="action-shelf"><button class="button button--primary button--full" data-action="continue-to-setup">Continue to ${state.selectedMode === "dinner" ? "choice" : "player"} setup &rarr;</button></div>`, { kicker: "NEW GAME" });
  }

  function renderSetup() {
    const isDinner = state.selectedMode === "dinner";
    const entityLabel = isDinner ? "choice" : "player";
    const rows = state.draftPlayers.map((player, index) => `<div class="player-edit-row stagger-item"><span class="pip ${player.shape} ${player.color}" aria-hidden="true"></span><div class="field"><input class="text-input ${state.setupErrors[index] ? "has-error" : ""}" data-player-input="${index}" aria-label="${entityLabel} ${index + 1} name" aria-describedby="${state.setupErrors[index] ? `player-error-${index}` : ""}" aria-invalid="${Boolean(state.setupErrors[index])}" value="${escapeHtml(player.name)}" maxlength="20" />${state.setupErrors[index] ? `<span class="field-error" id="player-error-${index}">${escapeHtml(state.setupErrors[index])}</span>` : ""}</div><button class="remove-button" data-action="remove-player" data-index="${index}" aria-label="Remove ${entityLabel} ${index + 1}" ${state.draftPlayers.length <= 2 ? "disabled" : ""}>x</button></div>`).join("");
    return page(isDinner ? "Add dinner choices" : "Add your crew", `<section class="hero"><span class="eyebrow">02 / ${isDinner ? "Choices" : "Players"}</span><h1 class="page-title">${isDinner ? "What is on the line?" : "Who is at the table?"}</h1><p class="lede">Two ${isDinner ? "choices" : "players"} minimum. Eight maximum. Names stay with the game history.</p></section><section class="card"><div class="section-heading section-heading--flush"><h2>${state.draftPlayers.length} ${isDinner ? "choices" : "players"}</h2><span class="section-label">${modeConfig().name}</span></div><div class="row-stack">${rows}</div><button class="button button--secondary button--full" style="margin-top:12px" data-action="add-player" ${state.draftPlayers.length >= 8 ? "disabled" : ""}>+ Add ${isDinner ? "choice" : "player"}</button></section><p class="field-hint" style="margin:12px 2px">Each ${entityLabel} gets a shape so the ledger stays easy to spot across the table.</p><div class="action-shelf"><button class="button button--primary button--full" data-action="continue-to-settings">Set the rules &rarr;</button></div>`, { kicker: "NEW GAME" });
  }

  function renderGameSettingsLegacy() {
    const config = modeConfig();
    const roundMode = state.selectedMode !== "scoreboard";
    const setting = roundMode ? "roundCount" : "targetScore";
    const value = roundMode ? state.gameSettings.roundCount : state.gameSettings.targetScore;
     return page("Set the rules", `<section class="hero"><span class="eyebrow">03 / Settings</span><h1 class="page-title">One last call before the first turn.</h1><p class="lede">Make the win condition clear now so the table can stay in the moment.</p></section><section class="card form-grid"><div class="section-heading" style="margin-top:0"><h2>${config.name}</h2><span class="stamp">${roundMode ? `${value} ROUNDS` : `TARGET ${value}`}</span></div><div class="option-row"><div><div class="option-title">${config.settingLabel}</div><div class="option-subtitle">${config.settingHint}</div></div><div class="stepper-inline"><button data-action="change-setting" data-setting="${setting}" data-delta="-1" aria-label="Decrease ${config.settingLabel}">-</button><span class="stepper-value">${value}</span><button data-action="change-setting" data-setting="${setting}" data-delta="1" aria-label="Increase ${config.settingLabel}">+</button></div></div>${state.selectedMode === "dinner" ? `<p class="field-hint">Dinner mode scores the choices above. The highest total becomes the table's decision.</p>` : `<div><div class="field-label" style="margin-bottom:7px">Turn order</div><div class="segmented"><button class="segmented__button ${state.gameSettings.turnOrder === "seat" ? "is-active" : ""}" data-action="set-turn-order" data-order="seat">Seat order</button><button class="segmented__button ${state.gameSettings.turnOrder === "winner" ? "is-active" : ""}" data-action="set-turn-order" data-order="winner">Winner starts</button></div></div>`}</section><section class="card" style="margin-top:12px"><div class="section-heading" style="margin-top:0"><h2>Ready check</h2><span class="section-label">${state.draftPlayers.length} pips</span></div><div class="finish-preview"><strong>${state.draftPlayers.map((player) => escapeHtml(player.name || "Unnamed")).join(" / ")}</strong><span>${roundMode ? `${value}R` : `${value}P`}</span></div><p class="field-hint">You can always undo a score during play. Finishing the game is the only action that asks for confirmation.</p></section><button class="button button--primary button--full" style="margin-top:16px" data-action="start-game">Start scoring &rarr;</button>`, { kicker: "NEW GAME" });
  }

  function renderGameSettings() {
    const config = modeConfig();
    const roundMode = state.selectedMode !== "scoreboard";
    const setting = roundMode ? "roundCount" : "targetScore";
    const value = roundMode ? state.gameSettings.roundCount : state.gameSettings.targetScore;
    const starterCopy = state.gameSettings.turnOrder === "winner" ? "Leader starts the next round when there is one clear leader." : "Players keep the order they were added.";
    return page("Set the rules", `<section class="hero"><span class="eyebrow">03 / Settings</span><h1 class="page-title">One last call before the first turn.</h1><p class="lede">Make the win condition clear now so the table can stay in the moment.</p></section><section class="card form-grid"><div class="section-heading section-heading--flush"><h2>${config.name}</h2><span class="stamp">${roundMode ? `${value} ROUNDS` : `TARGET ${value}`}</span></div><div class="option-row"><div><div class="option-title">${config.settingLabel}</div><div class="option-subtitle">${config.settingHint}</div></div><div class="stepper-inline"><button data-action="change-setting" data-setting="${setting}" data-delta="-1" aria-label="Decrease ${config.settingLabel}">-</button><span class="stepper-value">${value}</span><button data-action="change-setting" data-setting="${setting}" data-delta="1" aria-label="Increase ${config.settingLabel}">+</button></div></div>${state.selectedMode === "dinner" ? `<p class="field-hint">Dinner mode scores the choices above. The highest total becomes the table's decision.</p>` : `<div><div class="field-label" style="margin-bottom:7px">Round starter</div><div class="segmented"><button class="segmented__button ${state.gameSettings.turnOrder === "seat" ? "is-active" : ""}" data-action="set-turn-order" data-order="seat">Seat order</button><button class="segmented__button ${state.gameSettings.turnOrder === "winner" ? "is-active" : ""}" data-action="set-turn-order" data-order="winner">Leader starts</button></div><p class="field-hint setting-hint">${starterCopy}</p></div>`}</section><section class="card card--compact"><div class="section-heading section-heading--flush"><h2>Ready check</h2><span class="section-label">${state.draftPlayers.length} pips</span></div><div class="finish-preview"><strong>${state.draftPlayers.map((player) => escapeHtml(player.name || "Unnamed")).join(" / ")}</strong><span>${roundMode ? `${value}R` : `${value}P`}</span></div><p class="field-hint">Scores stay editable, and Undo is always available during play.</p></section><div class="action-shelf"><button class="button button--primary button--full" data-action="start-game">Start scoring &rarr;</button></div>`, { kicker: "NEW GAME" });
  }

  function renderScoring() {
    const game = state.currentGame;
    if (!game) return renderHome();
    const leaderScore = Math.max(...game.players.map((player) => player.score));
    const leaders = game.players.filter((player) => player.score === leaderScore);
    const config = modeConfig(game.mode);
    const entityNoun = game.mode === "dinner" ? "choice" : "player";
    const progress = game.mode === "scoreboard"
      ? Math.min(100, Math.round((leaderScore / game.targetScore) * 100))
      : Math.min(100, Math.round(((game.round - 1) / game.roundCount) * 100));
    const activePlayer = game.players[game.activePlayerIndex] || game.players[0];
    const roundLabel = game.mode === "phases" ? "PHASE" : "ROUND";
    const ledger = game.players.map((player) => `<div class="ledger-row ${player.score === leaderScore ? "is-leader" : ""} ${player.id === activePlayer.id ? "is-active-turn" : ""}" data-player-row="${player.id}" role="row">
      <span class="pip ${player.shape} ${player.color}" aria-hidden="true"></span>
      <div class="ledger-row__name" role="cell"><strong>${escapeHtml(player.name)}</strong><span class="leader-mark" data-leader-mark ${player.score === leaderScore ? "" : "hidden"}>LEAD</span><span class="turn-mark" data-turn-mark ${player.id === activePlayer.id ? "" : "hidden"}>START</span></div>
      <div class="pip-stepper" role="cell"><button data-action="change-score" data-player-id="${player.id}" data-delta="-1" aria-label="Subtract one point from ${escapeHtml(player.name)} ${entityNoun}">-</button><button data-action="change-score" data-player-id="${player.id}" data-delta="1" aria-label="Add one point to ${escapeHtml(player.name)} ${entityNoun}">+</button></div>
       <button class="score score-entry" data-action="edit-score" data-player-id="${player.id}" data-score-for="${player.id}" data-focus-key="score-${player.id}" aria-label="Edit ${escapeHtml(player.name)} ${entityNoun} score" role="cell" id="score-${player.id}">${player.score}</button>
    </div>`).join("");
    const leadText = leaders.length > 1
      ? `${leaders.map((player) => escapeHtml(player.name)).join(" and ")} are tied for the lead.`
      : `${escapeHtml(leaders[0].name)} leads with ${leaderScore} points.`;
    const targetText = game.mode === "scoreboard" ? `Target ${game.targetScore}. Finish whenever the table calls it.` : `${roundLabel[0] + roundLabel.slice(1).toLowerCase()} ${game.round} of ${game.roundCount}.`;
    const hint = state.scoreHintSeen ? "" : `<p class="score-hint" data-score-hint>Tap a score to edit it. Press and hold + or - to repeat.</p>`;
    return page("Score the round", `<section class="content--flow"><div class="scoring-header"><div><span class="eyebrow">${escapeHtml(config.name)} / live</span><h1>${game.mode === "dinner" ? "Find the table's answer." : game.players.length > 2 ? "Keep the ledger moving." : "One point at a time."}</h1><p>${targetText}</p></div><div class="round-marker"><span class="stamp">${roundLabel}</span><strong class="round-number">${game.round}</strong></div></div><div class="ledger" role="table" aria-label="Live score ledger">${ledger}</div>${hint}<div class="progress-rule"><span style="transform:scaleX(${progress / 100})"></span></div><p class="status-note" data-score-live aria-live="polite">${leadText} Round starter: ${escapeHtml(activePlayer.name)}.</p><div class="round-actions"><button class="round-actions__undo" data-action="undo" ${game.undoStack.length ? "" : "disabled"}>Undo last score</button><button class="button button--primary round-button" data-action="finish-round">Finish round &rarr;</button></div><div class="button-row" style="margin-top:14px"><button class="button button--secondary" data-action="open-timer">Open timer</button><button class="button button--quiet" data-action="open-end-game">End game</button></div></section>`, { kicker: "LIVE GAME", back: false, action: { action: "open-end-game", label: "End" } });
  }

  function syncScoringDom() {
    const game = state.currentGame;
    if (!game || state.screen !== "scoring") return;
    const leaderScore = Math.max(...game.players.map((player) => Number(player.score) || 0), 0);
    const leaders = game.players.filter((player) => (Number(player.score) || 0) === leaderScore);
    const activePlayer = game.players[game.activePlayerIndex] || game.players[0];
    game.players.forEach((player) => {
      const row = app.querySelector(`[data-player-row="${player.id}"]`);
      if (!row) return;
      row.classList.toggle("is-leader", player.score === leaderScore);
      row.classList.toggle("is-active-turn", player.id === activePlayer.id);
       const score = row.querySelector(`[data-score-for="${player.id}"]`);
       if (score) score.textContent = String(player.score);
      const leaderMark = row.querySelector("[data-leader-mark]");
      if (leaderMark) leaderMark.hidden = player.score !== leaderScore;
      const turnMark = row.querySelector("[data-turn-mark]");
      if (turnMark) turnMark.hidden = player.id !== activePlayer.id;
    });
    const progress = game.mode === "scoreboard"
      ? Math.min(100, Math.round((leaderScore / game.targetScore) * 100))
      : Math.min(100, Math.round(((game.round - 1) / game.roundCount) * 100));
    const progressBar = app.querySelector(".progress-rule span");
    if (progressBar) progressBar.style.transform = `scaleX(${progress / 100})`;
    const leadText = leaders.length > 1
      ? `${leaders.map((player) => player.name).join(" and ")} are tied for the lead.`
      : `${leaders[0]?.name || "Nobody"} leads with ${leaderScore} points.`;
    const live = app.querySelector("[data-score-live]");
    if (live) live.textContent = `${leadText} Round starter: ${activePlayer.name}.`;
    const undo = app.querySelector('[data-action="undo"]');
    if (undo) undo.disabled = game.undoStack.length === 0;
    const hint = app.querySelector("[data-score-hint]");
    if (hint) hint.hidden = state.scoreHintSeen;
  }

  function renderGameOver() {
    const game = state.history.find((item) => item.id === state.lastGameId) || state.history[0];
    if (!game) return renderHome();
    const ranked = [...game.players].sort((a, b) => b.score - a.score);
    const tied = game.result === "tie" || (game.winnerNames || []).length > 1;
    const names = (game.winnerNames || []).map(escapeHtml).join(" and ");
    return page("Game over", `<section class="winner-lockup"><span class="winner-stamp ${tied ? "winner-stamp--tie" : ""}">${tied ? "TIE" : "WINNER"}</span><h1>${tied ? `${names} finish level.` : `${escapeHtml(game.winnerName)} takes the table.`}</h1><p>${escapeHtml(game.modeName)} finished after ${game.rounds.length} rounds. That one is filed in history.</p></section><section class="card" style="padding:0"><div class="section-heading" style="padding:0 12px"><h2>Final ledger</h2><span class="stamp ${tied ? "stamp--tie" : "stamp--yellow"}">${tied ? "TIED" : "FINAL"}</span></div><div class="final-ledger" role="table" aria-label="Final score ledger">${ranked.map((player, index) => `<div class="final-row ${game.winnerNames?.includes(player.name) ? "is-result" : ""}" role="row"><span class="rank" role="cell">0${index + 1}</span><span class="pip ${player.shape} ${player.color}" aria-hidden="true"></span><strong role="cell">${escapeHtml(player.name)}</strong><span class="final-score" role="cell">${player.score}</span></div>`).join("")}</div></section><div class="button-row" style="margin-top:14px"><button class="button button--primary" data-action="rematch" data-game-id="${game.id}">Rematch now</button><button class="button button--secondary" data-action="new-game">New game</button></div><div class="secondary-actions"><button class="text-button" data-action="edit-rematch" data-destination="setup" data-game-id="${game.id}">Edit players</button><button class="text-button" data-action="edit-rematch" data-destination="gameSettings" data-game-id="${game.id}">Edit rules</button></div><button class="text-button" style="margin-top:8px" data-action="done-home">Done, back to home</button>`, { kicker: "RESULT" });
  }

  function renderHistory() {
    const body = state.history.length
      ? `<section class="hero"><span class="eyebrow">The ledger remembers</span><h1 class="page-title">Game history.</h1><p class="lede">Every finished game is a clean reference for the next rematch.</p></section><div class="row-stack">${state.history.map(renderHistoryItem).join("")}</div>`
      : `<section class="hero"><span class="eyebrow">Archive / empty</span><h1 class="page-title">Nothing filed yet.</h1><p class="lede">Finish a game and it will land here with its final ledger intact.</p></section><section class="empty-state"><span class="empty-state__mark">R</span><h2>History starts with one result.</h2><p class="empty-copy">Load the sample night if you want to see the archive before your first game.</p><button class="button button--secondary" data-action="seed-demo">Load sample history</button></section>`;
    return page("History", body, { kicker: "ARCHIVE", back: false });
  }

  function renderHistoryItem(game) {
    const outcome = outcomeForPlayers(game.players);
    return `<button class="history-item stagger-item" data-action="open-detail" data-game-id="${game.id}"><span class="history-item__title"><strong>${escapeHtml(resultLabel(game))} ${game.result === "tie" ? "in" : "in"} ${escapeHtml(game.modeName)}</strong><span class="history-item__meta">${formatDate(game.finishedAt, true)} / ${game.players.length} players / ${game.rounds.length} rounds</span></span><span class="history-item__score"><strong>${outcome.topScore}</strong><span>${game.result === "tie" ? "tied" : "final"}</span></span></button>`;
  }

  function renderDetail() {
    const game = state.history.find((item) => item.id === state.detailGameId) || state.history[0];
    if (!game) return renderHistory();
    const ranked = [...game.players].sort((a, b) => b.score - a.score);
    const rounds = game.rounds.map((round) => `<div class="table-row table-row--round"><strong>Round ${round.number}</strong><span>${round.scores.map((score) => `${escapeHtml(score.name)} ${score.score}`).join(" / ")}</span><span class="table-number">${round.scores.reduce((sum, player) => sum + player.score, 0)}</span></div>`).join("");
    const tied = game.result === "tie" || (game.winnerNames || []).length > 1;
    const names = (game.winnerNames || []).map(escapeHtml).join(" and ");
    return page("Game detail", `<section class="hero"><span class="eyebrow">${formatDate(game.finishedAt, true)} / ${escapeHtml(game.modeName)}</span><h1 class="page-title">${tied ? `${names} tied the night.` : `${escapeHtml(game.winnerName)} won the night.`}</h1><p class="lede">${game.rounds.length} rounds, ${game.players.length} players, one final ledger.</p></section><div class="card ${tied ? "card--result" : "card--yellow"} card--split"><div><span class="section-label">Stamped result</span><h2 class="card-title">${tied ? names : escapeHtml(game.winnerName)}</h2><p class="card-copy">${tied ? `Top score / ${outcomeForPlayers(game.players).topScore} points` : `Top score / ${ranked[0].score} points`}</p></div><span class="winner-stamp ${tied ? "winner-stamp--tie" : ""}">${tied ? "TIE" : "WINNER"}</span></div><section class="card" style="padding:0;margin-top:12px"><div class="section-heading" style="padding:0 12px"><h2>Final ledger</h2><span class="section-label">${game.rounds.length} rounds</span></div><div class="final-ledger" role="table" aria-label="Final score ledger">${ranked.map((player, index) => `<div class="final-row ${game.winnerNames?.includes(player.name) ? "is-result" : ""}" role="row"><span class="rank" role="cell">0${index + 1}</span><span class="pip ${player.shape} ${player.color}" aria-hidden="true"></span><strong role="cell">${escapeHtml(player.name)}</strong><span class="final-score" role="cell">${player.score}</span></div>`).join("")}</div></section><div class="section-heading"><h2>Round trail</h2><span class="section-label">scores at close</span></div><div class="table" role="table" aria-label="Round score trail">${rounds}</div><button class="button button--primary button--full" style="margin-top:16px" data-action="rematch" data-game-id="${game.id}">Rematch now</button><div class="secondary-actions"><button class="text-button" data-action="edit-rematch" data-destination="setup" data-game-id="${game.id}">Edit players</button><button class="text-button" data-action="edit-rematch" data-destination="gameSettings" data-game-id="${game.id}">Edit rules</button></div>`, { kicker: "ARCHIVE" });
  }

  function allRosterPlayers() {
    const roster = new Map();
    [...state.history, state.currentGame].filter(Boolean).forEach((game) => game.players.forEach((player) => {
      const key = player.name.trim().toLowerCase();
      if (key && !roster.has(key)) roster.set(key, { ...player, name: player.name.trim() });
    }));
    return [...roster.values()].sort((a, b) => a.name.localeCompare(b.name));
  }

  function getPlayerStats(name) {
    const appearances = state.history.flatMap((game) => {
      const player = game.players.find((item) => item.name === name);
      return player ? [{ game, player }] : [];
    });
    const wins = appearances.filter(({ game }) => game.result === "win" && game.winnerName === name).length;
    const total = appearances.reduce((sum, item) => sum + item.player.score, 0);
    const ties = appearances.filter(({ game }) => game.result === "tie" && game.winnerNames?.includes(name)).length;
    const modes = new Set(appearances.map(({ game }) => game.mode));
    const comparableAverage = appearances.length && modes.size === 1 ? Number((total / appearances.length).toFixed(1)) : null;
    return {
      appearances,
      games: appearances.map((item) => item.game),
      wins,
      ties,
      average: comparableAverage,
      winRate: appearances.length ? Math.round((wins / appearances.length) * 100) : 0,
      best: appearances.length ? Math.max(...appearances.map((item) => item.player.score)) : 0,
    };
  }

  function renderRoster() {
    const roster = allRosterPlayers();
    const body = roster.length
      ? `<section class="hero"><span class="eyebrow">The people behind the pips</span><h1 class="page-title">Roster.</h1><p class="lede">Tap a name for the numbers. Everyone who has played stays easy to find.</p></section><div class="row-stack">${roster.map((player) => { const stats = getPlayerStats(player.name); return `<button class="row-button" data-action="open-player-stats" data-player-name="${escapeHtml(player.name)}"><span class="row-button__title"><strong><span class="pip pip--small ${player.shape} ${player.color}" style="margin-right:7px;vertical-align:middle"></span>${escapeHtml(player.name)}</strong><span class="row-button__meta">${stats.games.length} games / ${stats.wins} wins</span></span><span class="button--small">Stats &rarr;</span></button>`; }).join("")}</div><section class="card" style="margin-top:14px"><div class="section-heading" style="margin-top:0"><h2>Compare two</h2><span class="section-label">head-to-head</span></div><p class="card-copy">Put any two names on the same line.</p><button class="button button--secondary" style="margin-top:10px" data-action="navigate" data-screen="headToHead">Open comparison</button></section>`
      : `<section class="hero"><span class="eyebrow">Roster / empty</span><h1 class="page-title">Your crew is waiting.</h1><p class="lede">Players appear here after the first finished game.</p></section><section class="empty-state"><span class="empty-state__mark">P</span><h2>No players yet.</h2><p class="empty-copy">Start a game or load a sample night to give this roster a little history.</p><div class="button-row"><button class="button button--primary" data-action="new-game">Start a game</button><button class="button button--secondary" data-action="seed-demo">Load sample</button></div></section>`;
    return page("Roster", body, { kicker: "PEOPLE", back: false });
  }

  function versus(nameA, nameB) {
    const games = state.history.filter((game) => game.players.some((player) => player.name === nameA) && game.players.some((player) => player.name === nameB));
    let aWins = 0;
    let bWins = 0;
    let ties = 0;
    games.forEach((game) => {
      const playerA = game.players.find((player) => player.name === nameA);
      const playerB = game.players.find((player) => player.name === nameB);
      if (!playerA || !playerB) return;
      if (playerA.score > playerB.score) aWins += 1;
      else if (playerB.score > playerA.score) bWins += 1;
      else ties += 1;
    });
    return { games: games.length, aWins, bWins, ties };
  }

  function renderPlayerStats() {
    const name = state.selectedPlayerName || allRosterPlayers()[0]?.name;
    if (!name) return renderRoster();
    const player = allRosterPlayers().find((item) => item.name === name) || { name, color: "accent", shape: "circle" };
    const stats = getPlayerStats(name);
    const opponents = allRosterPlayers().filter((item) => item.name !== name).slice(0, 4);
    const opponentRows = opponents.map((opponent) => { const result = versus(name, opponent.name); return `<div class="table-row"><strong>${escapeHtml(opponent.name)}</strong><span class="table-number">${result.aWins}</span><span class="table-number">${result.games}</span></div>`; }).join("") || `<div class="table-row"><span>No opponents yet</span><span>-</span><span>-</span></div>`;
      const recent = stats.appearances.map(({ game, player: result }) => { const gameResult = game.winnerNames?.includes(name) ? (game.result === "tie" ? "tied" : "won") : game.winnerNames?.length ? `won by ${escapeHtml(game.winnerNames.join(" and "))}` : "no winner"; return `<button class="row-button" data-action="open-detail" data-game-id="${game.id}"><span class="row-button__title"><strong>${escapeHtml(game.modeName)}</strong><span class="row-button__meta">${formatDate(game.finishedAt, true)} / ${gameResult}</span></span><span class="table-number">${result.score}</span></button>`; }).join("");
     return page("Player stats", `<section class="hero"><span class="eyebrow">Roster / player card</span><div class="stats-card__header"><span class="pip ${player.shape} ${player.color}" style="width:28px;height:28px;flex-basis:28px" aria-hidden="true"></span><div><h1 class="page-title">${escapeHtml(name)}.</h1><p>One player, fully legible.</p></div></div></section><div class="stat-grid"><div class="stat-card"><span class="stat-label">Games played</span><strong class="stat-value">${stats.games.length}</strong></div><div class="stat-card"><span class="stat-label">Wins</span><strong class="stat-value">${stats.wins}</strong></div><div class="stat-card"><span class="stat-label">Avg score</span><strong class="stat-value">${stats.average ?? "Mixed"}</strong></div><div class="stat-card"><span class="stat-label">Win rate</span><strong class="stat-value">${stats.winRate}%</strong></div><div class="stat-card stat-card--wide"><span class="stat-label">Ties</span><strong class="stat-value">${stats.ties}</strong></div></div><p class="field-hint stats-disclaimer">${stats.average === null ? "Average score is shown only within one game mode so unlike ledgers are not blended." : "Average score is calculated within this player's game mode."}</p><div class="section-heading"><h2>Head-to-head snapshot</h2><button class="text-button" data-action="navigate" data-screen="headToHead">Open full</button></div><div class="table"><div class="table-row table-row--head"><span>Opponent</span><span>Wins</span><span>Games</span></div>${opponentRows}</div><div class="section-heading"><h2>Recent finishes</h2><span class="section-label">${stats.appearances.length}</span></div><div class="row-stack">${recent}</div>`, { kicker: "PLAYER", action: { action: "navigate", label: "Roster", screen: "roster" } });
  }

  function renderStats() {
    const roster = allRosterPlayers();
    const totalRounds = state.history.reduce((sum, game) => sum + game.rounds.length, 0);
    const topWinnerCandidate = roster.map((player) => ({ name: player.name, wins: getPlayerStats(player.name).wins })).sort((a, b) => b.wins - a.wins)[0];
    const topWinner = topWinnerCandidate?.wins ? topWinnerCandidate : null;
    const body = state.history.length
     ? `<section class="hero"><span class="eyebrow">Patterns from the table</span><h1 class="page-title">Stats, without the spreadsheet.</h1><p class="lede">A quick read on the nights and names that keep showing up.</p></section><div class="stat-grid"><div class="stat-card"><span class="stat-label">Games logged</span><strong class="stat-value">${state.history.length}</strong></div><div class="stat-card"><span class="stat-label">Rounds scored</span><strong class="stat-value">${totalRounds}</strong></div><div class="stat-card stat-card--wide"><span class="stat-label">Most wins</span><strong class="stat-value">${topWinner ? escapeHtml(topWinner.name) : "-"}</strong></div></div><section class="promo-card" style="margin-top:12px"><div class="section-heading" style="margin-top:0"><h2>Head-to-head</h2><span class="stamp">COMPARE</span></div><p class="card-copy">See how two players perform across every shared game.</p><button class="button button--primary" style="margin-top:10px" data-action="navigate" data-screen="headToHead">Compare players &rarr;</button></section><div class="section-heading"><h2>Win board</h2><span class="section-label">all players</span></div><div class="table"><div class="table-row table-row--head"><span>Player</span><span>Wins</span><span>Avg / same mode</span></div>${roster.map((player) => { const stats = getPlayerStats(player.name); return `<button class="table-row" data-action="open-player-stats" data-player-name="${escapeHtml(player.name)}"><strong>${escapeHtml(player.name)}</strong><span class="table-number">${stats.wins}</span><span class="table-number">${stats.average ?? "-"}</span></button>`; }).join("")}</div>`
      : `<section class="hero"><span class="eyebrow">Stats / empty</span><h1 class="page-title">The numbers need a night.</h1><p class="lede">Finish a game and ScoreKeeper will turn it into a small, useful history.</p></section><section class="empty-state"><span class="empty-state__mark">S</span><h2>No stats yet.</h2><p class="empty-copy">Load the sample night to see wins, averages, and a head-to-head table.</p><button class="button button--secondary" data-action="seed-demo">Load sample history</button></section>`;
    return page("Stats", body, { kicker: "INSIGHT", back: false });
  }

  function renderHeadToHead() {
    const roster = allRosterPlayers();
    if (roster.length < 2) return page("Head-to-head", `<section class="hero"><span class="eyebrow">Compare / waiting</span><h1 class="page-title">Two names make a story.</h1><p class="lede">Play or load one finished game with at least two players to unlock comparisons.</p></section><section class="empty-state"><span class="empty-state__mark">VS</span><h2>Not enough players yet.</h2><p class="empty-copy">The comparison surface will fill itself from the roster.</p><button class="button button--primary" data-action="seed-demo">Load sample history</button></section>`, { kicker: "COMPARE" });
    const first = state.headToHeadIds[0] && roster.some((player) => player.name === state.headToHeadIds[0]) ? state.headToHeadIds[0] : roster[0].name;
    const second = state.headToHeadIds[1] && roster.some((player) => player.name === state.headToHeadIds[1]) && state.headToHeadIds[1] !== first ? state.headToHeadIds[1] : roster.find((player) => player.name !== first).name;
    state.headToHeadIds = [first, second];
    const result = versus(first, second);
    const winsLabel = result.games ? `${result.games} shared game${result.games === 1 ? "" : "s"}` : "No shared games yet";
    const tiesLabel = result.ties ? ` ${result.ties} tie${result.ties === 1 ? "" : "s"}` : "";
    return page("Head-to-head", `<section class="hero"><span class="eyebrow">Stats / direct comparison</span><h1 class="page-title">Put two names on the line.</h1><p class="lede">Only shared finished games count. No vibes, just the ledger.</p></section><section class="card"><div class="select-row"><label class="field"><span class="field-label">Player one</span><select class="select-input" data-field="head-a">${roster.map((player) => `<option value="${escapeHtml(player.name)}" ${player.name === first ? "selected" : ""}>${escapeHtml(player.name)}</option>`).join("")}</select></label><span class="versus">VS</span><label class="field"><span class="field-label">Player two</span><select class="select-input" data-field="head-b">${roster.map((player) => `<option value="${escapeHtml(player.name)}" ${player.name === second ? "selected" : ""}>${escapeHtml(player.name)}</option>`).join("")}</select></label></div><div class="stat-grid" style="margin-top:18px"><div class="stat-card"><span class="stat-label">${escapeHtml(first)} wins</span><strong class="stat-value">${result.aWins}</strong></div><div class="stat-card"><span class="stat-label">${escapeHtml(second)} wins</span><strong class="stat-value">${result.bWins}</strong></div><div class="stat-card stat-card--wide"><span class="stat-label">Shared games</span><strong class="stat-value">${result.games}</strong></div></div><p class="field-hint" style="margin-top:12px">${winsLabel}. Winner is based on the final score.</p><button class="button button--secondary button--full" style="margin-top:12px" data-action="swap-head">Swap players</button></section><div class="section-heading"><h2>Shared ledger</h2><span class="section-label">${result.games} games</span></div><div class="row-stack">${state.history.filter((game) => game.players.some((player) => player.name === first) && game.players.some((player) => player.name === second)).map((game) => `<button class="row-button" data-action="open-detail" data-game-id="${game.id}"><span class="row-button__title"><strong>${escapeHtml(game.modeName)}</strong><span class="row-button__meta">${formatDate(game.finishedAt, true)} / winner ${escapeHtml(game.winnerName)}</span></span><span class="table-number">${game.players.find((player) => player.name === first).score}-${game.players.find((player) => player.name === second).score}</span></button>`).join("") || `<div class="empty-state"><p class="empty-copy">Play together to make this table useful.</p></div>`}</div>`, { kicker: "COMPARE" });
  }

   function renderHeadToHead() {
     const roster = allRosterPlayers();
     if (roster.length < 2) return page("Head-to-head", `<section class="hero"><span class="eyebrow">Compare / waiting</span><h1 class="page-title">Two names make a story.</h1><p class="lede">Play or load one finished game with at least two players to unlock comparisons.</p></section><section class="empty-state"><span class="empty-state__mark">VS</span><h2>Not enough players yet.</h2><p class="empty-copy">The comparison surface will fill itself from the roster.</p><button class="button button--primary" data-action="seed-demo">Load sample history</button></section>`, { kicker: "COMPARE" });
     const first = state.headToHeadIds[0] && roster.some((player) => player.name === state.headToHeadIds[0]) ? state.headToHeadIds[0] : roster[0].name;
     const second = state.headToHeadIds[1] && roster.some((player) => player.name === state.headToHeadIds[1]) && state.headToHeadIds[1] !== first ? state.headToHeadIds[1] : roster.find((player) => player.name !== first).name;
     state.headToHeadIds = [first, second];
     const result = versus(first, second);
     const sharedGames = state.history.filter((game) => game.players.some((player) => player.name === first) && game.players.some((player) => player.name === second));
     const sharedRows = sharedGames.map((game) => `<button class="row-button" data-action="open-detail" data-game-id="${game.id}"><span class="row-button__title"><strong>${escapeHtml(game.modeName)}</strong><span class="row-button__meta">${formatDate(game.finishedAt, true)} / ${game.result === "tie" ? "tied" : `${escapeHtml(game.winnerName)} won`}</span></span><span class="table-number">${outcomeForPlayers(game.players).topScore}</span></button>`).join("") || `<div class="empty-state"><h2>No shared games yet.</h2><p class="empty-copy">Play a game with both names to build this comparison.</p></div>`;
     return page("Head-to-head", `<section class="hero"><span class="eyebrow">Stats / direct comparison</span><h1 class="page-title">Put two names on the line.</h1><p class="lede">Only shared finished games count. No vibes, just the ledger.</p></section><section class="card"><div class="select-row"><label class="field"><span class="field-label">Player one</span><select class="select-input" data-field="head-a">${roster.map((player) => `<option value="${escapeHtml(player.name)}" ${player.name === first ? "selected" : ""}>${escapeHtml(player.name)}</option>`).join("")}</select></label><span class="versus">VS</span><label class="field"><span class="field-label">Player two</span><select class="select-input" data-field="head-b">${roster.map((player) => `<option value="${escapeHtml(player.name)}" ${player.name === second ? "selected" : ""}>${escapeHtml(player.name)}</option>`).join("")}</select></label></div><div class="stat-grid" style="margin-top:18px"><div class="stat-card"><span class="stat-label">${escapeHtml(first)} wins</span><strong class="stat-value">${result.aWins}</strong></div><div class="stat-card"><span class="stat-label">${escapeHtml(second)} wins</span><strong class="stat-value">${result.bWins}</strong></div><div class="stat-card"><span class="stat-label">Ties</span><strong class="stat-value">${result.ties}</strong></div><div class="stat-card stat-card--wide"><span class="stat-label">Shared games</span><strong class="stat-value">${result.games}</strong></div></div><p class="field-hint" style="margin-top:12px">${result.games ? `${result.games} shared game${result.games === 1 ? "" : "s"}` : "No shared games yet"}. Ties stay separate from wins.</p><button class="button button--secondary button--full" style="margin-top:12px" data-action="swap-head">Swap players</button></section><div class="section-heading"><h2>Shared ledger</h2><span class="section-label">${result.games} games</span></div><div class="row-stack">${sharedRows}</div>`, { kicker: "COMPARE" });
   }

  function renderSettingsLegacy() {
     return page("Settings", `<section class="hero"><span class="eyebrow">The quiet controls</span><h1 class="page-title">Settings.</h1><p class="lede">Tune the paper, keep the table yours, and find the things that should stay out of the way.</p></section><div class="settings-list"><button class="settings-row" data-action="toggle-theme"><span class="settings-row__copy"><strong>Dark paper</strong><span>${state.theme === "dark" ? "Coal field is on" : "Warm paper is on"}</span></span><span class="toggle ${state.theme === "dark" ? "is-on" : ""}" aria-hidden="true"></span></button><button class="settings-row" data-action="open-paywall"><span class="settings-row__copy"><strong>Go Pro <span class="pro-mark">PRO</span></strong><span>${state.proUnlocked ? "Pro is active on this device." : "Keep the night distraction-free with Pro tools."}</span></span><span class="settings-row__trailing">&rarr;</span></button><button class="settings-row" data-action="seed-demo"><span class="settings-row__copy"><strong>Load sample night</strong><span>Add two finished games to history without replacing your ledger.</span></span><span class="settings-row__trailing">+</span></button><button class="settings-row" data-action="open-legal"><span class="settings-row__copy"><strong>Legal &amp; support</strong><span>About, credits, restore, and contact.</span></span><span class="settings-row__trailing">&rarr;</span></button><button class="settings-row" data-action="reset-history"><span class="settings-row__copy"><strong>Clear local history</strong><span>Reset this prototype's saved ledger.</span></span><span class="settings-row__trailing">x</span></button></div><section class="promo-card" style="margin-top:14px"><span class="section-label">PIPCOUNT / PAPER BAUHAUS</span><p class="support-copy" style="margin-top:8px">Designed to feel faster than paper, with enough memory to make the next game better.</p></section>`, { kicker: "MORE" });
  }

  function renderPaywallLegacy() {
      return page("ScoreKeeper access", `<section class="hero"><span class="eyebrow">Optional / never in the way</span><h1 class="page-title">A clear entitlement demo.</h1><p class="lede">This prototype records local state only. It does not sell or unlock a premium feature.</p></section><button class="text-button" data-action="back">Back to settings</button>`, { kicker: "LOCAL DEMO" });
  }

  function renderLegalLegacy() {
      return page("Legal & support", `<section class="hero"><span class="eyebrow">About the pad</span><h1 class="page-title">Help, without the maze.</h1><p class="lede">Small answers for a small app. Every row below opens a real next step.</p></section><div class="settings-list"><button class="settings-row" data-action="open-about"><span class="settings-row__copy"><strong>About ScoreKeeper</strong><span>Why the app is shaped this way.</span></span><span class="settings-row__trailing">&rarr;</span></button><button class="settings-row" data-action="open-contact"><span class="settings-row__copy"><strong>Contact support</strong><span>Get a human at hello@pipcount.app.</span></span><span class="settings-row__trailing">&rarr;</span></button><button class="settings-row" data-action="restore-pro"><span class="settings-row__copy"><strong>Restore local access</strong><span>${state.proUnlocked ? "Local access is already active." : "Check for a saved local demo flag."}</span></span><span class="settings-row__trailing">&rarr;</span></button><button class="settings-row" data-action="open-credits"><span class="settings-row__copy"><strong>Credits</strong><span>Paper, pips, and the people behind the pad.</span></span><span class="settings-row__trailing">&rarr;</span></button></div>`, { kicker: "MORE" });
  }

  function renderSettings() {
    const proRow = state.history.length ? `<button class="settings-row" data-action="open-paywall"><span class="settings-row__copy"><strong>Local access demo</strong><span>${state.proUnlocked ? "A local entitlement is active." : "See how an entitlement state reads."}</span></span><span class="settings-row__trailing">&rarr;</span></button>` : "";
     return page("Settings", `<section class="hero"><span class="eyebrow">The quiet controls</span><h1 class="page-title">Settings.</h1><p class="lede">Tune the paper, keep the table yours, and find the things that should stay out of the way.</p></section><div class="settings-list"><button class="settings-row" data-action="toggle-theme" data-focus-key="theme-row" aria-pressed="${state.theme === "dark"}"><span class="settings-row__copy"><strong>Dark paper</strong><span>${state.theme === "dark" ? "Coal field is on" : "Warm paper is on"}</span></span><span class="toggle ${state.theme === "dark" ? "is-on" : ""}" aria-hidden="true"></span></button>${proRow}<button class="settings-row" data-action="seed-demo"><span class="settings-row__copy"><strong>Load sample night</strong><span>Add two finished games to history without replacing your ledger.</span></span><span class="settings-row__trailing">+</span></button><button class="settings-row" data-action="open-legal"><span class="settings-row__copy"><strong>Legal &amp; support</strong><span>About, credits, restore, and contact.</span></span><span class="settings-row__trailing">&rarr;</span></button><button class="settings-row" data-action="reset-history"><span class="settings-row__copy"><strong>Clear local history</strong><span>Reset this prototype's saved ledger.</span></span><span class="settings-row__trailing">x</span></button></div><section class="promo-card" style="margin-top:14px"><span class="section-label">SCOREKEEPER / PAPER BAUHAUS</span><p class="support-copy" style="margin-top:8px">Designed to feel faster than paper, with enough memory to make the next game better.</p></section>`, { kicker: "MORE" });
  }

  function renderPaywall() {
    return page("ScoreKeeper access", `<section class="hero"><span class="eyebrow">Optional / after a first game</span><h1 class="page-title">A clear entitlement demo.</h1><p class="lede">This prototype keeps the purchase surface honest: it can show local state, but it cannot verify a payment or unlock a premium capability.</p></section><section class="card card--pro"><span class="stamp">LOCAL ENTITLEMENT</span><h2 class="card-title" style="margin-top:13px">${state.proUnlocked ? "Local access is active." : "No local access yet."}</h2><div class="row-stack" style="margin-top:12px"><div class="option-row"><div><div class="option-title">Stored on this device</div><div class="option-subtitle">A reload can preserve the demo flag.</div></div><span class="pip circle accent"></span></div><div class="option-row"><div><div class="option-title">No receipt or feature gate</div><div class="option-subtitle">There is no purchase flow behind this static screen.</div></div><span class="pip square ink"></span></div></div><button class="button button--primary button--full" style="margin-top:15px" data-action="upgrade-pro" ${state.proUnlocked ? "disabled aria-disabled=\"true\"" : ""}>${state.proUnlocked ? "Local access is active" : "Mark local access"}</button></section><p class="field-hint" style="margin:12px 2px">Use this only to exercise entitlement copy and restore states during review.</p><button class="text-button" data-action="back">Back to settings</button>`, { kicker: "LOCAL DEMO" });
  }

  function renderLegal() {
    return page("Legal & support", `<section class="hero"><span class="eyebrow">About the pad</span><h1 class="page-title">Help, without the maze.</h1><p class="lede">Small answers for a small app. Every row below opens a real next step.</p></section><div class="settings-list"><button class="settings-row" data-action="open-about"><span class="settings-row__copy"><strong>About ScoreKeeper</strong><span>Why the app is shaped this way.</span></span><span class="settings-row__trailing">&rarr;</span></button><button class="settings-row" data-action="open-contact"><span class="settings-row__copy"><strong>Contact support</strong><span>Get a human at hello@pipcount.app.</span></span><span class="settings-row__trailing">&rarr;</span></button><button class="settings-row" data-action="restore-pro"><span class="settings-row__copy"><strong>Restore local access</strong><span>${state.proUnlocked ? "Local access is already active." : "Check for a saved local demo flag."}</span></span><span class="settings-row__trailing">&rarr;</span></button><button class="settings-row" data-action="open-credits"><span class="settings-row__copy"><strong>Credits</strong><span>Paper, pips, and the people behind the pad.</span></span><span class="settings-row__trailing">&rarr;</span></button></div>`, { kicker: "MORE" });
  }

  function renderSheet() {
    if (state.sheet !== "timer") return "";
    const status = state.timer.completed ? "Time is up" : state.timer.running ? "Timer running" : "Ready when you are";
    const cueCopy = state.timer.cueUnavailable ? "No audio cue is available in this browser." : "Use a small tone; haptics depend on device support.";
      return `<div class="sheet-wrap"><button class="sheet-backdrop" data-action="close-sheet" aria-label="Close timer"></button><section class="sheet" role="dialog" aria-modal="true" aria-labelledby="timer-title"><button class="sheet__handle" data-sheet-handle aria-label="Drag down to close timer"></button><div class="sheet__header"><div><span class="eyebrow">Tool / mid-game</span><h2 class="sheet-title" id="timer-title">Table timer.</h2><p class="sheet-copy">Keep the pace visible without leaving the score.</p></div><button class="close-button" data-action="close-sheet" aria-label="Close timer">Close</button></div><div class="timer-sheet__display">${state.timer.completed ? `<div class="completion-stamp"><strong>TIME</strong><span>the table has a decision</span></div>` : `<strong class="timer-value" data-timer-value>${formatTime(state.timer.remainingSeconds)}</strong>`}<span class="timer-status" data-timer-status aria-live="polite">${status}</span><span class="sr-only" data-timer-live aria-live="assertive"></span></div><div class="timer-presets">${[5, 10, 15].map((minutes) => `<button class="chip ${state.timer.totalSeconds === minutes * 60 ? "is-active" : ""}" data-action="set-timer" data-minutes="${minutes}">${minutes} min</button>`).join("")}</div><div class="button-row"><button class="button button--primary" data-action="toggle-timer" data-timer-start>${state.timer.running ? "Pause" : state.timer.completed ? "Start fresh" : "Start"}</button><button class="button button--secondary" data-action="reset-timer">Reset</button></div><button class="cue-toggle ${state.timer.cueUnavailable ? "is-unavailable" : ""}" data-action="toggle-timer-cue" aria-pressed="${state.timer.cueEnabled}" ${state.timer.cueUnavailable ? "aria-disabled=\"true\"" : ""}><span><strong>Completion cue</strong><span>${cueCopy}</span></span><span class="toggle ${state.timer.cueEnabled ? "is-on" : ""}" aria-hidden="true"></span></button></section></div>`;
  }

  function renderModal() {
    if (!state.modal) return "";
    if (state.modal.type === "score-entry") {
      const player = state.currentGame?.players.find((item) => item.id === state.modal.playerId);
      if (!player) return "";
      const noun = state.currentGame.mode === "dinner" ? "choice" : "player";
      return `<div class="overlay"><button class="overlay__backdrop" data-action="close-modal" aria-label="Close score editor"></button><section class="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title"><span class="eyebrow">LIVE LEDGER / EDIT</span><h2 class="modal-title" id="modal-title">Edit ${escapeHtml(player.name)}'s score.</h2><p class="dialog-copy">Enter the current total for this ${noun}. Undo can restore the previous value.</p><label class="field"><span class="field-label">Current score</span><input class="text-input text-input--number" data-score-entry-input data-autofocus type="number" min="0" step="1" inputmode="numeric" value="${player.score}" aria-label="Current score for ${escapeHtml(player.name)}" /></label><div class="modal__actions" style="margin-top:18px"><button class="button button--primary button--full" data-action="commit-score-entry">Save score</button><button class="button button--secondary button--full" data-action="close-modal">Cancel</button></div></section></div>`;
    }
    if (state.modal.type === "end-game") {
      const game = state.currentGame;
      const leader = game ? [...game.players].sort((a, b) => b.score - a.score)[0] : null;
       const outcome = game ? outcomeForPlayers(game.players) : null;
       const leadCopy = outcome?.winnerNames.length > 1 ? `${outcome.winnerNames.map(escapeHtml).join(" and ")} are tied at ${outcome.topScore}.` : leader ? leadingSentence(leader, leader.score) : "The current ledger will be filed.";
       return `<div class="overlay"><button class="overlay__backdrop" data-action="close-modal" aria-label="Close dialog"></button><section class="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title"><span class="stamp stamp--red">FINAL ACTION</span><h2 class="modal-title" id="modal-title">End game?</h2><p class="dialog-copy">${leadCopy} You can rematch the same crew after the result is stamped.</p><div class="modal__actions"><button class="button button--danger button--full" data-action="confirm-end-game" data-autofocus>End and stamp result</button><button class="button button--secondary button--full" data-action="close-modal">Keep scoring</button></div></section></div>`;
    }
    if (state.modal.type === "reset") {
       return `<div class="overlay"><button class="overlay__backdrop" data-action="close-modal" aria-label="Close dialog"></button><section class="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title"><span class="stamp stamp--red">DESTRUCTIVE</span><h2 class="modal-title" id="modal-title">Clear local history?</h2><p class="dialog-copy">This removes finished games, roster names, and stats from the prototype. There is no undo.</p><div class="modal__actions"><button class="button button--danger button--full" data-action="confirm-reset" data-autofocus>Clear history</button><button class="button button--secondary button--full" data-action="close-modal">Keep it</button></div></section></div>`;
    }
    if (state.modal.type === "contact") {
      return `<div class="overlay"><button class="overlay__backdrop" data-action="close-modal" aria-label="Close dialog"></button><section class="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title"><span class="eyebrow">SCOREKEEPER / SUPPORT</span><h2 class="modal-title" id="modal-title">Talk to the table.</h2><p class="dialog-copy">Email hello@pipcount.app with the game format and what happened. The address can also be copied for later.</p><div class="modal__actions"><a class="button button--primary button--full" href="mailto:hello@pipcount.app" data-autofocus>Email support</a><button class="button button--secondary button--full" data-action="copy-support-email">Copy address</button><button class="text-button" data-action="close-modal">Close</button></div></section></div>`;
    }
    const modal = state.modal;
    return `<div class="overlay"><button class="overlay__backdrop" data-action="close-modal" aria-label="Close dialog"></button><section class="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title"><span class="eyebrow">SCOREKEEPER / NOTE</span><h2 class="modal-title" id="modal-title">${escapeHtml(modal.title)}</h2><p class="dialog-copy">${escapeHtml(modal.copy)}</p><div class="modal__actions"><button class="button button--primary button--full" data-action="close-modal" data-autofocus>Close</button></div></section></div>`;
  }

  function renderToast() {
    const persistentError = Boolean(state.storageError);
    const message = persistentError ? state.storageError : state.toast?.message;
    const kind = persistentError ? "error" : state.toast?.kind || "error";
    return `<div class="toast toast--${kind} ${persistentError ? "toast--persistent" : ""}" role="${kind === "error" ? "alert" : "status"}"><span>${escapeHtml(message)}</span>${persistentError ? `<button class="toast-retry" data-action="retry-save">Try again</button>` : ""}</div>`;
  }

  function beginNewGame() {
    if (state.currentGame) {
      openEndGameModal();
      return;
    }
    state.selectedMode = "scoreboard";
    state.draftPlayers = clone(DEFAULT_PLAYERS);
    state.gameSettings = { targetScore: 100, roundCount: 6, turnOrder: "seat" };
    state.setupErrors = {};
    navigate("choose");
  }

  function selectMode(mode) {
    state.selectedMode = mode;
    const config = modeConfig(mode);
    state.gameSettings.targetScore = config.defaultTarget;
    state.gameSettings.roundCount = config.defaultRounds;
    state.setupErrors = {};
    persist();
    render(false);
  }

  function addPlayer() {
    if (state.draftPlayers.length >= 8) return;
    const index = state.draftPlayers.length;
    state.draftPlayers.push({ name: `Guest ${index + 1}`, color: PLAYER_COLORS[index % PLAYER_COLORS.length], shape: PLAYER_SHAPES[index % PLAYER_SHAPES.length] });
    persist();
    render(false);
    requestAnimationFrame(() => document.querySelector(`[data-player-input="${index}"]`)?.focus());
  }

  function removePlayer(index) {
    if (state.draftPlayers.length <= 2) return;
    state.draftPlayers.splice(index, 1);
    state.setupErrors = {};
    persist();
    render(false);
  }

  function validateDraftPlayers() {
    const errors = {};
    const seen = new Map();
    state.draftPlayers.forEach((player, index) => {
      const name = player.name.trim();
      const key = name.toLowerCase();
      if (!name) errors[index] = "Add a name before continuing.";
      else if (seen.has(key)) {
        errors[index] = "Use a different name.";
        errors[seen.get(key)] = "Use a different name.";
      } else seen.set(key, index);
    });
    state.setupErrors = errors;
    return Object.keys(errors).length === 0;
  }

  function createCurrentGame() {
    const config = modeConfig();
    return {
      id: uid("live"), mode: state.selectedMode, modeName: config.name,
      targetScore: state.gameSettings.targetScore, roundCount: state.gameSettings.roundCount,
      turnOrder: state.selectedMode === "dinner" ? "seat" : state.gameSettings.turnOrder, round: 1, rounds: [], undoStack: [], activePlayerIndex: 0,
      players: state.draftPlayers.map((player, index) => ({ ...player, color: PLAYER_COLORS.includes(player.color) ? player.color : "ink", id: uid(`p${index}`), score: 0 })),
      startedAt: new Date().toISOString(),
    };
  }

  function startGame(options = {}) {
    if (state.currentGame && !options.allowOverwrite) {
      openEndGameModal();
      return;
    }
    if (!options.skipValidation && !validateDraftPlayers()) {
      render(false);
      requestAnimationFrame(() => document.querySelector(".has-error")?.focus());
      return;
    }
    state.currentGame = createCurrentGame();
    state.scoreHintSeen = false;
    state.setupErrors = {};
    persist();
    navigate("scoring", {}, { replace: Boolean(options.replace) });
  }

  function changeScore(playerId, delta, options = {}) {
    const game = state.currentGame;
    if (!game) return;
    const player = game.players.find((item) => item.id === playerId);
    if (!player) return;
    const previous = player.score;
    const next = Math.max(0, player.score + delta);
    if (next === player.score) {
      if (options.notifyBoundary !== false) showToast("A score cannot go below zero.", "warning", { preserveScoring: true });
      return false;
    }
    game.undoStack.push({ playerId, previous: player.score, delta });
    player.score = next;
    state.scoreHintSeen = true;
    const saved = persist();
    syncScoringDom();
    if (options.animate !== false && !window.matchMedia?.("(prefers-reduced-motion: reduce)").matches) requestAnimationFrame(() => {
      const score = document.querySelector(`[data-score-for="${playerId}"]`);
      if (score) {
        score.animate([{ transform: "scale(1)" }, { transform: "scale(1.04)" }, { transform: "scale(1)" }], { duration: 140, easing: "cubic-bezier(0.23, 1, 0.32, 1)" });
      }
    });
    if (saved && game.mode === "scoreboard" && previous < game.targetScore && player.score >= game.targetScore) showToast(`Target reached for ${player.name}. Review and end the game when ready.`, "success", { preserveScoring: true });
    return true;
  }

  function openScoreEntry(playerId) {
    const player = state.currentGame?.players.find((item) => item.id === playerId);
    if (!player) return;
    captureFocusReturn();
    state.modal = { type: "score-entry", playerId };
    render(true);
  }

  function commitScoreEntry() {
    const game = state.currentGame;
    const player = game?.players.find((item) => item.id === state.modal?.playerId);
    const input = app.querySelector("[data-score-entry-input]");
    const value = Number(input?.value);
    if (!game || !player || !Number.isFinite(value) || value < 0) {
      input?.focus();
      return;
    }
    const next = Math.floor(value);
    const changed = next !== player.score;
    if (changed) {
      game.undoStack.push({ playerId: player.id, previous: player.score, delta: next - player.score });
      player.score = next;
      state.scoreHintSeen = true;
    }
    const saved = changed ? persist() : true;
    state.modal = null;
    render(false);
    if (changed && saved) showToast("Score updated.", "success", { preserveScoring: true });
  }

  function undoLast() {
    const game = state.currentGame;
    const action = game?.undoStack.pop();
    if (!action) return;
    const player = game.players.find((item) => item.id === action.playerId);
    if (player) player.score = action.previous;
    const saved = persist();
    syncScoringDom();
    if (saved) showToast("Last score undone.", "success", { preserveScoring: true });
  }

  function snapshotRound(game, number = game.round) {
    const snapshot = { number, phase: game.mode === "phases" ? number : null, scores: game.players.map((player) => ({ name: player.name, score: player.score })) };
    const existingIndex = game.rounds.findIndex((round) => round.number === number);
    if (existingIndex >= 0) game.rounds[existingIndex] = snapshot;
    else game.rounds.push(snapshot);
    game.rounds.sort((a, b) => a.number - b.number);
  }

   function finishRound() {
     const game = state.currentGame;
     if (!game) return;
     if (game.mode !== "scoreboard" && game.round > game.roundCount) return;
     if (game.mode !== "scoreboard" && game.round >= game.roundCount) {
       openEndGameModal();
       return;
     }
     snapshotRound(game, game.round);
     const leaderScore = Math.max(...game.players.map((player) => player.score));
    const leaders = game.players.filter((player) => player.score === leaderScore);
    const leader = leaders.length === 1 ? leaders[0] : null;
    game.undoStack = [];
    game.activePlayerIndex = game.turnOrder === "winner" && leader ? game.players.indexOf(leader) : (game.activePlayerIndex + 1) % game.players.length;
    game.round += 1;
     if (persist()) {
       showToast(`Round ${game.round - 1} filed.${game.turnOrder === "winner" && leader ? ` ${leader.name} starts the next round.` : game.turnOrder === "winner" ? " Leaders tied; seat order continues." : ""}`, "success");
     }
  }

  function openEndGameModal() {
    if (!state.currentGame) return;
    captureFocusReturn();
    state.modal = { type: "end-game" };
    render(true);
  }

  function serializeGame(game) {
    const outcome = outcomeForPlayers(game.players);
    return {
      id: uid("game"), mode: game.mode, modeName: game.modeName, targetScore: game.targetScore,
      roundCount: game.roundCount, turnOrder: game.turnOrder, finishedAt: new Date().toISOString(),
      rounds: clone(game.rounds), players: clone(game.players), result: outcome.result, winnerNames: outcome.winnerNames, winnerName: outcome.winnerName,
    };
  }

   function finishGame() {
     const game = state.currentGame;
     if (!game) return;
     const finalRound = game.mode === "scoreboard" ? game.round : Math.min(game.round, game.roundCount);
     snapshotRound(game, finalRound);
     const result = serializeGame(game);
    state.history = [result, ...state.history].sort((a, b) => new Date(b.finishedAt) - new Date(a.finishedAt));
    state.lastGameId = result.id;
    state.currentGame = null;
    state.modal = null;
    persist();
    navigate("gameOver");
  }

  function prepareRematch(gameId) {
    const source = state.history.find((game) => game.id === gameId) || state.history[0];
    if (!source) return null;
    state.selectedMode = source.mode;
    state.gameSettings = { targetScore: source.targetScore, roundCount: source.roundCount, turnOrder: source.turnOrder || "seat" };
    state.draftPlayers = source.players.map(({ name, color, shape }) => ({ name, color, shape }));
    state.setupErrors = {};
    return source;
  }

  function rematch(gameId) {
    const source = prepareRematch(gameId);
    if (!source) return;
    startGame({ skipValidation: true });
    showToast("Fresh scorecard ready.", "success", { preserveScoring: true });
  }

  function editRematch(gameId, destination) {
    const source = prepareRematch(gameId);
    if (!source) return;
    navigate(destination === "gameSettings" ? "gameSettings" : "setup");
  }

  function seedDemo() {
    const players = [
      { name: "Maya", color: "accent", shape: "circle" },
      { name: "Theo", color: "ink", shape: "square" },
      { name: "June", color: "ink", shape: "triangle" },
      { name: "Sam", color: "ink", shape: "diamond" },
    ];
    const makeDemo = (id, date, scores, mode, rounds) => ({
      id, demo: true, mode, modeName: modeConfig(mode).name, targetScore: mode === "scoreboard" ? 100 : rounds,
      roundCount: rounds, turnOrder: "seat", finishedAt: date,
      players: players.map((player, index) => ({ ...player, id: `${id}-p${index}`, score: scores[index] })),
      rounds: Array.from({ length: rounds }, (_, index) => ({ number: index + 1, scores: players.map((player, playerIndex) => ({ name: player.name, score: Math.round(scores[playerIndex] * ((index + 1) / rounds)) })) })),
       ...outcomeForPlayers(players.map((player, index) => ({ ...player, score: scores[index] }))),
     });
     const demoGames = [
      makeDemo("demo-rematch", "2026-08-15T20:25:00.000Z", [96, 74, 67, 51], "phases", 6),
      makeDemo("demo-first", "2026-08-15T19:10:00.000Z", [84, 92, 58, 47], "scoreboard", 4),
    ];
    const existingIds = new Set(state.history.map((game) => game.id));
    const additions = demoGames.filter((game) => !existingIds.has(game.id));
    state.history = [...state.history, ...additions].sort((a, b) => new Date(b.finishedAt) - new Date(a.finishedAt));
      state.lastGameId = state.history[0]?.id || null;
      state.draftPlayers = players.map(({ name, color, shape }) => ({ name, color, shape }));
      state.onboardingComplete = true;
      const saved = persist();
      if (state.screen === "onboarding" || state.screen === "home") navigate("home");
      else {
        render(false);
        if (saved) showToast(additions.length ? `${additions.length} sample game${additions.length === 1 ? "" : "s"} added.` : "Sample night is already in the ledger.", additions.length ? "success" : "info");
      }
    }

  function setTimer(minutes) {
    stopTimer();
    state.timer.totalSeconds = minutes * 60;
    state.timer.remainingSeconds = minutes * 60;
    state.timer.completed = false;
    state.timer.deadline = null;
    persist();
    render(false);
  }

  function timerAudioContext() {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return null;
    if (!state.timer.audioContext) state.timer.audioContext = new AudioContext();
    if (state.timer.audioContext.state === "suspended") state.timer.audioContext.resume?.();
    return state.timer.audioContext;
  }

  function stopTimer() {
    if (state.timer.interval) window.clearInterval(state.timer.interval);
    state.timer.interval = null;
    state.timer.running = false;
    state.timer.deadline = null;
  }

  function playTimerCue() {
    if (!state.timer.cueEnabled) return;
    try {
      const context = timerAudioContext();
      if (!context) {
        state.timer.cueUnavailable = true;
        state.timer.cueEnabled = false;
        persist();
        if (state.sheet === "timer") render(false);
        return;
      }
      navigator.vibrate?.([80, 40, 80]);
      const oscillator = context.createOscillator();
      const gain = context.createGain();
      oscillator.frequency.value = 880;
      gain.gain.setValueAtTime(0.04, context.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, context.currentTime + 0.22);
      oscillator.connect(gain).connect(context.destination);
      oscillator.start();
      oscillator.stop(context.currentTime + 0.22);
    } catch (error) {
      state.timer.cueUnavailable = true;
      state.timer.cueEnabled = false;
      persist();
      if (state.sheet === "timer") render(false);
    }
  }

  function syncTimerClock(announce = true) {
    if (!state.timer.running || !state.timer.deadline) return;
    const next = Math.max(0, Math.ceil((state.timer.deadline - Date.now()) / 1000));
    state.timer.remainingSeconds = next;
    if (next > 0) {
      updateTimerDom();
      return;
    }
    state.timer.running = false;
    state.timer.deadline = null;
    state.timer.completed = true;
    if (state.timer.interval) window.clearInterval(state.timer.interval);
    state.timer.interval = null;
    persist();
    playTimerCue();
    if (state.sheet === "timer") render(false);
    else updateTimerDom();
    if (announce) showToast("Timer complete. The table has a decision.", "success");
  }

  function startTimerLoop() {
    if (state.timer.interval) window.clearInterval(state.timer.interval);
    state.timer.interval = window.setInterval(() => syncTimerClock(), 250);
  }

  function toggleTimer() {
    if (state.timer.running) {
      syncTimerClock(false);
      stopTimer();
      persist();
      updateTimerDom();
      return;
    }
    if (state.timer.completed || state.timer.remainingSeconds <= 0) {
      state.timer.remainingSeconds = state.timer.totalSeconds;
      state.timer.completed = false;
    }
    if (state.timer.cueEnabled) {
      try { timerAudioContext(); } catch (error) { state.timer.cueUnavailable = true; state.timer.cueEnabled = false; }
    }
    state.timer.running = true;
    state.timer.deadline = Date.now() + (state.timer.remainingSeconds * 1000);
    persist();
    updateTimerDom();
    startTimerLoop();
  }

  function resetTimer() {
    stopTimer();
    state.timer.remainingSeconds = state.timer.totalSeconds;
    state.timer.completed = false;
    persist();
    render(false);
  }

  function openInfo(title, copy) {
    captureFocusReturn();
    state.modal = { type: "info", title, copy };
    render(true);
  }

  function openContact() {
    captureFocusReturn();
    state.modal = { type: "contact" };
    render(true);
  }

  function openResetModal() {
    captureFocusReturn();
    state.modal = { type: "reset" };
    render(true);
  }

  function closeOverlay() {
    if (!state.modal && !state.sheet) return;
    const surface = app.querySelector(".modal, .sheet");
    const backdrop = app.querySelector(".overlay__backdrop, .sheet-backdrop");
    surface?.style.removeProperty("transform");
    surface?.style.removeProperty("transition");
    surface?.setAttribute("data-closing", "true");
    backdrop?.setAttribute("data-closing", "true");
    window.setTimeout(() => {
      state.modal = null;
      state.sheet = null;
      render(false);
    }, 180);
  }

  function manageOverlayFocus() {
    const overlay = state.modal ? `modal:${state.modal.type}` : state.sheet ? `sheet:${state.sheet}` : null;
    if (overlay && overlay !== state.lastOverlayKey) {
      const dialog = app.querySelector('[role="dialog"]');
      const first = dialog?.querySelector("[data-autofocus], button, a, input, select, textarea");
      first?.focus();
    }
    if (!overlay && state.focusReturnAction) {
      const target = state.focusReturnAction.startsWith("#")
        ? app.querySelector(state.focusReturnAction)
        : state.focusReturnAction.startsWith("focus-key:")
          ? [...app.querySelectorAll("[data-focus-key]")].find((item) => item.dataset.focusKey === state.focusReturnAction.slice(10))
          : app.querySelector(`[data-action="${state.focusReturnAction}"]`);
      target?.focus();
      if (target) state.focusReturnAction = null;
    }
    state.lastOverlayKey = overlay;
  }

  function updateTimerDom() {
    const value = app.querySelector("[data-timer-value]");
    const status = app.querySelector("[data-timer-status]");
    const start = app.querySelector("[data-timer-start]");
    const live = app.querySelector("[data-timer-live]");
    const bannerValues = app.querySelectorAll("[data-timer-banner-value]");
    bannerValues.forEach((node) => { node.textContent = formatTime(state.timer.remainingSeconds); });
    if (value) value.textContent = formatTime(state.timer.remainingSeconds);
    if (status) status.textContent = state.timer.completed ? "Time is up" : state.timer.running ? "Timer running" : "Ready when you are";
    if (start) start.textContent = state.timer.running ? "Pause" : state.timer.completed ? "Start fresh" : "Start";
    if (live && state.timer.completed && live.textContent !== "Timer complete. The table has a decision.") live.textContent = "Timer complete. The table has a decision.";
    if (state.sheet === "timer" && !value && !state.timer.completed) render(false);
  }

  async function copySupportEmail() {
    const email = "hello@pipcount.app";
    let copied = false;
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(email);
        copied = true;
      }
    } catch (error) {
      copied = false;
    }
    if (!copied) {
      const fallback = document.createElement("textarea");
      fallback.value = email;
      fallback.setAttribute("readonly", "true");
      fallback.style.position = "fixed";
      fallback.style.opacity = "0";
      document.body.appendChild(fallback);
      fallback.select();
      try { copied = document.execCommand("copy") === true; } catch (error) { copied = false; }
      fallback.remove();
    }
    closeOverlay();
    showToast(copied ? "Support address copied." : "Could not copy the address. Use Email support instead.", copied ? "success" : "error");
  }

  function handleClick(event) {
    const target = event.target.closest("[data-action]");
    if (!target || !app.contains(target)) return;
    const action = target.dataset.action;
    switch (action) {
      case "toggle-theme":
        state.followsSystemTheme = false;
        setTheme(state.theme === "light" ? "dark" : "light");
        persist();
        render(false);
        break;
      case "open-settings":
        navigate("settings");
        break;
      case "navigate":
        if (target.dataset.screen) navigate(target.dataset.screen);
        break;
      case "back":
        goBack();
        break;
      case "start-onboarding-game":
        state.draftPlayers = clone(DEFAULT_PLAYERS);
        state.onboardingComplete = true;
        persist();
        navigate("choose");
        break;
      case "skip-onboarding":
        state.onboardingComplete = true;
        persist();
        navigate("home");
        break;
      case "seed-demo":
        seedDemo();
        break;
      case "retry-save":
        if (persist()) showToast("Changes saved on this device.", "success");
        break;
      case "new-game":
        beginNewGame();
        break;
      case "select-mode":
        selectMode(target.dataset.mode);
        break;
      case "continue-to-setup":
        navigate("setup");
        break;
      case "continue-to-settings":
        if (validateDraftPlayers()) navigate("gameSettings");
        else {
          render(false);
          requestAnimationFrame(() => document.querySelector(".has-error")?.focus());
        }
        break;
      case "add-player":
        addPlayer();
        break;
      case "remove-player":
        removePlayer(Number(target.dataset.index));
        break;
      case "change-setting": {
        const setting = target.dataset.setting;
        const delta = Number(target.dataset.delta);
        const step = setting === "targetScore" ? 10 : 1;
        state.gameSettings[setting] = Math.max(setting === "targetScore" ? 10 : 2, state.gameSettings[setting] + (delta * step));
        persist();
        render(false);
        break;
      }
      case "set-turn-order":
        state.gameSettings.turnOrder = target.dataset.order;
        persist();
        render(false);
        break;
      case "start-game":
        startGame();
        break;
      case "change-score":
        if (state.scoreRepeatSuppress) {
          state.scoreRepeatSuppress = false;
          break;
        }
        changeScore(target.dataset.playerId, Number(target.dataset.delta), { animate: event.detail > 0 });
        break;
      case "edit-score":
        openScoreEntry(target.dataset.playerId);
        break;
      case "commit-score-entry":
        commitScoreEntry();
        break;
      case "undo":
        undoLast();
        break;
      case "finish-round":
        finishRound();
        break;
      case "open-end-game":
        openEndGameModal();
        break;
      case "confirm-end-game":
        finishGame();
        break;
      case "open-timer":
        captureFocusReturn();
        state.sheet = "timer";
        render(true);
        break;
      case "close-sheet":
        closeOverlay();
        break;
      case "toggle-timer":
        toggleTimer();
        break;
      case "reset-timer":
        resetTimer();
        break;
      case "set-timer":
        setTimer(Number(target.dataset.minutes));
        break;
      case "toggle-timer-cue":
        if (state.timer.cueEnabled) {
          state.timer.cueEnabled = false;
        } else {
          try {
            const context = timerAudioContext();
            state.timer.cueUnavailable = !context;
            state.timer.cueEnabled = Boolean(context);
          } catch (error) {
            state.timer.cueUnavailable = true;
            state.timer.cueEnabled = false;
          }
        }
        persist();
        updateTimerDom();
        render(false);
        break;
      case "close-modal":
        closeOverlay();
        break;
      case "open-detail":
        state.detailGameId = target.dataset.gameId;
        navigate("detail", { detailGameId: target.dataset.gameId });
        break;
      case "rematch":
        rematch(target.dataset.gameId);
        break;
      case "edit-rematch":
        editRematch(target.dataset.gameId, target.dataset.destination);
        break;
      case "done-home":
        navigate("home");
        break;
      case "open-player-stats":
        state.selectedPlayerName = target.dataset.playerName;
        navigate("playerStats", { selectedPlayerName: target.dataset.playerName });
        break;
      case "swap-head":
        state.headToHeadIds = [state.headToHeadIds[1], state.headToHeadIds[0]];
        render(false);
        break;
      case "open-paywall":
        navigate("paywall");
        break;
      case "upgrade-pro":
        if (state.proUnlocked) break;
        state.proUnlocked = true;
        persist();
        showToast("Local access marked for this device.", "success");
        break;
      case "open-legal":
        navigate("legal");
        break;
      case "open-about":
        openInfo("Paper, not a spreadsheet.", "ScoreKeeper keeps a game-night score legible, quick to change, and easy to trust. The Paper Bauhaus system gives every state a clear mark without turning the phone into a stage.");
        break;
      case "open-contact":
        openContact();
        break;
      case "copy-support-email":
        copySupportEmail();
        break;
      case "restore-pro":
        if (state.proUnlocked) showToast("Local access is already active.", "info");
        else showToast("No local entitlement was found on this device.", "warning");
        break;
      case "open-credits":
        openInfo("Made for game night.", "ScoreKeeper is a Register concept. The visual language borrows from printed ledgers, Bauhaus geometry, and the satisfying finality of an ink stamp.");
        break;
      case "reset-history":
        openResetModal();
        break;
      case "confirm-reset":
        state.history = [];
        state.currentGame = null;
        state.lastGameId = null;
        state.detailGameId = null;
        state.modal = null;
        state.onboardingComplete = true;
        persist();
        navigate("home");
        showToast("Local history cleared.", "success");
        break;
      default:
        break;
    }
  }

  app.addEventListener("click", handleClick);

  let sheetDrag = null;

  function finishSheetDrag(event) {
    if (!sheetDrag || event.pointerId !== sheetDrag.pointerId) return;
    const drag = sheetDrag;
    sheetDrag = null;
    const sheet = app.querySelector(".sheet");
    if (!sheet) return;
    const elapsed = Math.max(1, performance.now() - drag.startedAt);
    const velocity = Math.max(0, drag.distance) / elapsed;
    if (drag.distance > 96 || velocity > 0.11) {
      closeOverlay();
      return;
    }
    sheet.style.transition = "transform 240ms var(--ease-drawer)";
    sheet.style.transform = "translateY(0)";
    window.setTimeout(() => {
      if (!sheetDrag && sheet.isConnected) sheet.style.removeProperty("transition");
    }, 240);
  }

  app.addEventListener("pointerdown", (event) => {
    const handle = event.target.closest?.("[data-sheet-handle]");
    if (!handle || state.sheet !== "timer" || sheetDrag) return;
    event.preventDefault();
    handle.setPointerCapture?.(event.pointerId);
    sheetDrag = { pointerId: event.pointerId, startY: event.clientY, distance: 0, startedAt: performance.now() };
    const sheet = app.querySelector(".sheet");
    if (sheet) sheet.style.transition = "none";
  });

  app.addEventListener("pointermove", (event) => {
    if (!sheetDrag || event.pointerId !== sheetDrag.pointerId) return;
    event.preventDefault();
    const rawDistance = event.clientY - sheetDrag.startY;
    sheetDrag.distance = rawDistance >= 0 ? rawDistance : rawDistance * 0.25;
    const sheet = app.querySelector(".sheet");
    if (sheet) sheet.style.transform = `translateY(${Math.max(0, sheetDrag.distance)}px)`;
  });

  app.addEventListener("pointerup", finishSheetDrag);
  app.addEventListener("pointercancel", finishSheetDrag);

  let scoreHold = null;

  function scheduleScoreRepeat() {
    if (!scoreHold) return;
    if (!changeScore(scoreHold.playerId, scoreHold.delta, { notifyBoundary: false })) {
      endScoreHold();
      return;
    }
    scoreHold.repeatCount += 1;
    const delay = scoreHold.repeatCount > 20 ? 55 : scoreHold.repeatCount > 8 ? 80 : 110;
    scoreHold.interval = window.setTimeout(scheduleScoreRepeat, delay);
  }

  function endScoreHold() {
    if (!scoreHold) return;
    window.clearTimeout(scoreHold.timeout);
    window.clearTimeout(scoreHold.interval);
    if (scoreHold.repeating) {
      state.scoreRepeatSuppress = true;
      window.setTimeout(() => { state.scoreRepeatSuppress = false; }, 140);
    }
    scoreHold = null;
  }

  app.addEventListener("pointerdown", (event) => {
    const target = event.target.closest?.('[data-action="change-score"]');
    if (!target || scoreHold) return;
    target.setPointerCapture?.(event.pointerId);
    const playerId = target.dataset.playerId;
    const delta = Number(target.dataset.delta);
    scoreHold = {
      pointerId: event.pointerId,
      timeout: window.setTimeout(() => {
        if (!scoreHold) return;
        scoreHold.repeating = true;
        scoreHold.repeatCount = 0;
        scheduleScoreRepeat();
      }, 450),
      interval: null,
      repeating: false,
      repeatCount: 0,
    };
  });
  app.addEventListener("pointerup", endScoreHold);
  app.addEventListener("pointercancel", endScoreHold);
  app.addEventListener("pointerleave", endScoreHold);
  window.addEventListener("pointerup", endScoreHold);
  window.addEventListener("pointercancel", endScoreHold);
  app.addEventListener("contextmenu", (event) => {
    if (event.target.closest?.('[data-action="change-score"]')) event.preventDefault();
  });

  app.addEventListener("input", (event) => {
    const input = event.target.closest("[data-player-input]");
    if (!input) return;
    const index = Number(input.dataset.playerInput);
    if (state.draftPlayers[index]) {
      state.draftPlayers[index].name = input.value;
      if (input.value.trim()) delete state.setupErrors[index];
      persist();
    }
  });

  app.addEventListener("change", (event) => {
    const field = event.target.dataset.field;
    if (field === "head-a") {
      state.headToHeadIds[0] = event.target.value;
      persist();
      render(false);
    }
    if (field === "head-b") {
      state.headToHeadIds[1] = event.target.value;
      persist();
      render(false);
    }
  });

  document.addEventListener("keydown", (event) => {
    if (!state.modal && !state.sheet) return;
    if (event.key === "Escape") {
      event.preventDefault();
      closeOverlay();
      return;
    }
    if (event.key === "Enter" && state.modal?.type === "score-entry") {
      event.preventDefault();
      commitScoreEntry();
      return;
    }
    if (event.key !== "Tab") return;
    const dialog = app.querySelector('[role="dialog"]');
    if (!dialog) return;
    const focusable = [...dialog.querySelectorAll("button:not(:disabled), a[href], input:not(:disabled), select:not(:disabled), textarea:not(:disabled)")];
    if (!focusable.length) return;
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  });

  window.addEventListener("popstate", (event) => {
    if (state.currentGame && !state.modal && !state.sheet && event.state?.screen !== "scoring") {
      restoreScoringHistoryEntry();
      openEndGameModal();
      return;
    }
    if (event.state?.app !== "pipcount") {
      const homeRoute = { app: "pipcount", screen: state.currentGame ? "scoring" : "home", depth: 0 };
      window.history.pushState(homeRoute, "", `#${homeRoute.screen}`);
      applyRoute(homeRoute.screen, {}, false, "back");
      return;
    }
    const route = event.state;
    const { app: ignored, screen, depth: ignoredDepth, ...extra } = route;
    if (screen === "scoring" && !state.currentGame) {
      applyRoute("home", {}, true, "back");
      return;
    }
    applyRoute(VALID_SCREENS.has(screen) ? screen : "home", extra, true, "back");
  });

  const systemThemeQuery = window.matchMedia?.("(prefers-color-scheme: dark)");
  systemThemeQuery?.addEventListener?.("change", (event) => {
    if (!state.followsSystemTheme) return;
    setTheme(event.matches ? "dark" : "light");
    render(false);
  });

  document.addEventListener("visibilitychange", () => {
    if (!state.timer.running) return;
    syncTimerClock(false);
    if (state.timer.running && document.visibilityState === "visible") startTimerLoop();
  });

  hydrate();
  if (state.timer.running) {
    syncTimerClock(false);
    if (state.timer.running) startTimerLoop();
  }
  if (window.history.state?.app !== "pipcount") {
    window.history.replaceState({ app: "pipcount", screen: state.screen, depth: 0 }, "", `#${state.screen}`);
  }
  window.addEventListener("beforeunload", persist);
  render();
})();
