import React, { useCallback, useEffect, useRef, useState } from "react"
import ReactDOM from "react-dom/client"
import { ArrowLeft, Check, Keyboard, MoreHorizontal, PencilLine, Eraser, Undo2, X } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { TuningPanel } from "./TuningPanel"
import { useScoreTuning } from "./score-tuning"
import { ScoreCanvas } from "./ScoreCanvas"
import { ScoreToast, type Notification } from "./ScoreToast"
import { useRecognition } from "./useRecognition"
import { JevSetup } from "./JevSetup"
import { HandwritingCollection } from "./HandwritingCollection"
import { BASE_TOTALS, PLAYERS, SESSION_KEY, draftValue, freshSession, loadSession, totalFor, type Draft, type EntryMode, type Player } from "./scoring"
import "@fontsource-variable/manrope"
import "dialkit/styles.css"
import "./index.css"

function App() {
  const [session, setSession] = useState(loadSession)
  const sessionRef = useRef(session)
  sessionRef.current = session
  const [open, setOpen] = useState(!PLAYERS.every(player => session.roundScores[player] !== undefined))
  const [drawing, setDrawing] = useState(false)
  const [notification, setNotification] = useState<Notification | null>(null)
  const titleRef = useRef<HTMLHeadingElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const pendingReplay = useRef(false)
  const { dial, enabled: tuning } = useScoreTuning(() => {
    if (open) { pendingReplay.current = true; setOpen(false) }
    else setOpen(true)
  })
  const player = session.player
  const draft = session.drafts[player]
  const value = draftValue(draft)
  const current = totalFor(session, player)
  const allSaved = PLAYERS.every(name => session.roundScores[name] !== undefined)

  const patchDraft = useCallback((name: Player, edit: (previous: Draft) => Draft) => {
    setSession(previous => ({ ...previous, drafts: { ...previous.drafts, [name]: edit(previous.drafts[name]) } }))
  }, [])

  useRecognition(draft, open && !drawing, reading => {
    const strokes = draft.strokes
    patchDraft(player, previous => previous.strokes === strokes ? { ...previous, reading } : previous)
  })

  useEffect(() => {
    const timer = setTimeout(() => {
      try { localStorage.setItem(SESSION_KEY, JSON.stringify(session)) } catch {}
    }, 200)
    return () => clearTimeout(timer)
  }, [session])

  useEffect(() => {
    const save = () => { try { localStorage.setItem(SESSION_KEY, JSON.stringify(sessionRef.current)) } catch {} }
    window.addEventListener("pagehide", save)
    return () => { window.removeEventListener("pagehide", save) }
  }, [])

  const dismissToast = useCallback(() => setNotification(null), [])

  function changeOpen(next: boolean) {
    if (!next) setDrawing(false)
    setOpen(next)
  }

  function openPlayer(name: Player) {
    setDrawing(false)
    setSession(previous => ({ ...previous, player: name }))
    setOpen(true)
  }

  function setMode(mode: EntryMode) {
    setDrawing(false)
    patchDraft(player, previous => ({
      ...previous, mode,
      ...(mode === "write" && previous.typed && previous.reading.value !== Number(previous.typed) ? { strokes: [], reading: { status: "empty" as const, value: null } } : {}),
      typed: mode === "type" && !previous.typed && previous.reading.value !== null ? String(previous.reading.value) : previous.typed,
    }))
  }

  function saveScore() {
    if (value === null || drawing) return
    const updated = { ...session.roundScores, [player]: value }
    const index = PLAYERS.indexOf(player)
    const ordered = [...PLAYERS.slice(index + 1), ...PLAYERS.slice(0, index)]
    const next = ordered.find(name => updated[name] === undefined)
    setSession(previous => ({
      ...previous, player: next ?? player, roundScores: updated,
      undo: [...previous.undo, { player, previous: previous.roundScores[player] ?? null }].slice(-20),
    }))
    setNotification({ id: Date.now(), message: `${player}’s total is now ${BASE_TOTALS[player] + value}`, undo: true })
    if (next) {
      requestAnimationFrame(() => {
        if (session.drafts[next].mode === "type") inputRef.current?.focus({ preventScroll: true })
        else titleRef.current?.focus({ preventScroll: true })
      })
    } else setOpen(false)
  }

  function undoScore() {
    const previous = sessionRef.current
    const entry = previous.undo.at(-1)
    if (!entry) return
    const scores = { ...previous.roundScores }
    if (entry.previous === null) delete scores[entry.player]
    else scores[entry.player] = entry.previous
    setSession({ ...previous, player: entry.player, roundScores: scores, undo: previous.undo.slice(0, -1) })
    setDrawing(false)
    setOpen(true)
    setNotification({ id: Date.now(), message: `${entry.player}’s total is back to ${BASE_TOTALS[entry.player] + (entry.previous ?? 0)}`, undo: false })
  }

  function resetPreview() {
    setSession(freshSession())
    setDrawing(false)
    setOpen(true)
    setNotification(null)
  }

  const status = value !== null
    ? `A score of ${value} will bring ${player}’s total to ${BASE_TOTALS[player] + value}`
    : draft.mode === "type" ? "Enter a score, then tap the tick to save it"
    : draft.reading.status === "reading" ? "We’re reading your score"
    : draft.reading.status === "waiting" || drawing ? "Your score will appear when you finish writing"
    : draft.reading.status === "unreadable" ? "Please write the score again or use the keyboard"
    : draft.reading.status === "error" ? "Reading is unavailable, so please type this score"
    : "Write a score, then tap the tick to save it"

  const toast = notification && <ScoreToast notification={notification} onUndo={undoScore} onDismiss={dismissToast} />

  return <><main className="app-shell" data-testid="preview-root" data-state={draft.mode}>
    <header className="topbar"><Button variant="ghost" size="icon" aria-label="Back to games"><ArrowLeft /></Button><span className="brand"><i />PipCount</span><Button variant="ghost" size="icon" aria-label="Game options"><MoreHorizontal /></Button></header>
    <section className="scoreboard" aria-label="Game scoreboard">
      <div className="game-heading"><div><p className="eyebrow">SCOREBOARD</p><h1>Game night</h1></div><span className="round-tag">Round 2</span></div>
      <p className="board-help">Tap a player to add or edit their score</p>
      <div className="ledger-head"><span>Player</span><span>Total</span></div>
      {PLAYERS.map(name => <button className="player-row" data-testid={`player-${name.toLowerCase()}`} key={name} onClick={() => openPlayer(name)}><span className={`token ${name.toLowerCase()}`} /><span>{name}</span><span className="round-entry-label">{session.roundScores[name] === undefined ? "Add score" : `Round 2 · ${session.roundScores[name]}`}</span><strong>{totalFor(session, name)}</strong><PencilLine size={18} aria-hidden="true" /></button>)}
      <div className="round-summary"><span>Round 1</span><span>Maya <b>7</b></span><span>Leo <b>9</b></span></div>
      <div className="round-summary current-round"><span>Round 2</span>{PLAYERS.map(name => <span key={name}>{name} <b>{session.roundScores[name] ?? "—"}</b></span>)}</div>
      {allSaved && <p className="round-complete" role="status">Everyone’s score has been saved for this round</p>}
      {session.undo.length > 0 && <Button variant="ghost" className="board-undo" onClick={undoScore}><Undo2 aria-hidden="true" />Undo last score</Button>}
    </section>
    <footer className="board-footer"><span className="footer-shapes"><i /><i /><i /></span><p>Everyone’s scores stay together</p></footer>
    <Dialog open={open} modal={!tuning} disablePointerDismissal={tuning} onOpenChange={changeOpen} onOpenChangeComplete={next => {
      if (!next && pendingReplay.current) { pendingReplay.current = false; setOpen(true) }
    }}>
      <DialogContent className="score-dialog" data-testid="score-dialog" showCloseButton={false} initialFocus={draft.mode === "type" ? inputRef : titleRef}>
        <div className="dialog-topline"><span className="dialog-round">Round 2</span><Button variant="ghost" size="icon" className="close-button" aria-label="Close score entry" onClick={() => changeOpen(false)}><X size={20} /></Button></div>
        <div className="player-heading"><span className={`token large ${player.toLowerCase()}`} /><div><DialogTitle ref={titleRef} tabIndex={-1} className="player-title" aria-live="polite">{player}</DialogTitle><DialogDescription className="sr-only">Add or edit this player’s score for round 2 by writing or typing a number from 0 to 99</DialogDescription></div><div className="current-total"><span>Current total</span><strong>{current}</strong></div></div>
        <div className="score-entry-body">
          <div className={`writing-surface ${draft.mode === "type" ? "typing" : ""}`}>
            {draft.mode === "type" ? <div className="typed-entry"><label htmlFor="score-value">Score for this round</label><Input ref={inputRef} id="score-value" data-testid="score-input" aria-label="Score for this round" inputMode="numeric" pattern="[0-9]*" maxLength={2} autoFocus value={draft.typed} onChange={event => patchDraft(player, previous => ({ ...previous, typed: event.target.value.replace(/[^0-9]/g, "").slice(0, 2) }))} /><span>Enter a number from 0 to 99</span></div> : <>
              {!draft.strokes.length && <span className="canvas-label">Write {player}’s score here</span>}
              <ScoreCanvas key={player} player={player} strokes={draft.strokes} onDrawing={setDrawing} onChange={strokes => patchDraft(player, previous => ({ ...previous, strokes, typed: "", reading: { status: strokes.length ? "waiting" : "empty", value: null } }))} />
              <span className="canvas-baseline" />
            </>}
          </div>
          <p className={`recognition-status ${value !== null ? "is-ready" : ""}`} data-testid="recognition-status" data-reading-state={draft.mode === "type" ? (value === null ? "empty" : "ready") : draft.reading.status} role="status" aria-live="polite" aria-atomic="true">{status}</p>
          <div className="entry-action-row">
            <Button variant="outline" className="entry-secondary entry-clear" data-testid="clear-score" aria-label="Clear score" title="Clear score" onClick={() => { setDrawing(false); patchDraft(player, previous => ({ ...previous, strokes: [], typed: "", reading: { status: "empty", value: null } })) }}><Eraser className="size-5" aria-hidden="true" /></Button>
            <Button className="primary-action approve-action" data-testid="primary-action" aria-label="Save score" disabled={value === null || drawing} onClick={event => { if (event.detail < 2) saveScore() }}><Check className="size-7" aria-hidden="true" /></Button>
            <Button variant="outline" className="entry-secondary entry-mode" data-testid="switch-entry-mode" aria-label={draft.mode === "type" ? "Write score" : "Type score"} title={draft.mode === "type" ? "Write score" : "Type score"} onClick={() => setMode(draft.mode === "type" ? "write" : "type")}>{draft.mode === "type" ? <PencilLine className="size-5" aria-hidden="true" /> : <Keyboard className="size-5" aria-hidden="true" />}</Button>
          </div>
        </div>
        {open && toast}
      </DialogContent>
    </Dialog>
    {!open && toast}
  </main>{tuning && <TuningPanel dial={dial} mode={draft.mode} onModeChange={mode => { setMode(mode); setOpen(true) }} onReset={resetPreview} />}</>
}

ReactDOM.createRoot(document.getElementById("root")!).render(<React.StrictMode>{window.location.pathname.startsWith("/handwriting") ? <HandwritingCollection /> : window.location.pathname === "/setup/jev" ? <JevSetup /> : <App />}</React.StrictMode>)
