export const PLAYERS = ["Leo", "Maya"] as const
export type Player = typeof PLAYERS[number]
export const BASE_TOTALS: Record<Player, number> = { Leo: 9, Maya: 7 }
export type EntryMode = "write" | "type"
export type Point = { x: number; y: number; t?: number; pressure?: number }
export type Stroke = Point[]
export type Reading = { status: "empty" | "waiting" | "reading" | "ready" | "unreadable" | "error"; value: number | null }
export type Draft = { mode: EntryMode; typed: string; strokes: Stroke[]; reading: Reading }
export type UndoEntry = { player: Player; previous: number | null }
export type Session = { player: Player; roundScores: Partial<Record<Player, number>>; drafts: Record<Player, Draft>; undo: UndoEntry[] }
export const SESSION_KEY = "pipcount-round-entry-v1"

export function emptyDraft(mode: EntryMode = "write"): Draft {
  return { mode, typed: "", strokes: [], reading: { status: "empty", value: null } }
}

export function freshSession(): Session {
  const mode = new URLSearchParams(window.location.search).get("state") === "type" ? "type" : "write"
  return { player: "Leo", roundScores: {}, drafts: { Leo: emptyDraft(mode), Maya: emptyDraft() }, undo: [] }
}

export function validScore(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 99
}

export function loadSession(): Session {
  try {
    const data = JSON.parse(localStorage.getItem(SESSION_KEY) ?? "null") as Session | null
    if (!data || !PLAYERS.includes(data.player) || !data.drafts || !Array.isArray(data.undo)) return freshSession()
    for (const player of PLAYERS) {
      const draft = data.drafts[player]
      if (data.roundScores[player] !== undefined && !validScore(data.roundScores[player])) return freshSession()
      if (!draft || !["write", "type"].includes(draft.mode) || typeof draft.typed !== "string" || !/^\d{0,2}$/.test(draft.typed) || !Array.isArray(draft.strokes) || draft.strokes.length > 100 || draft.strokes.flat().length > 10000) return freshSession()
      for (const stroke of draft.strokes) {
        if (!Array.isArray(stroke) || !stroke.length || stroke.length > 1500 || stroke.some(point => !Number.isFinite(point.x) || !Number.isFinite(point.y) || point.x < 0 || point.x > 1000 || point.y < 0 || point.y > 1000)) return freshSession()
      }
      draft.reading = { status: draft.strokes.length ? "waiting" : "empty", value: null }
    }
    if (data.undo.length > 20 || data.undo.some(entry => !PLAYERS.includes(entry.player) || (entry.previous !== null && !validScore(entry.previous)))) return freshSession()
    return data
  } catch {
    return freshSession()
  }
}

export function draftValue(draft: Draft): number | null {
  if (draft.mode === "type") return /^\d{1,2}$/.test(draft.typed) ? Number(draft.typed) : null
  return draft.reading.status === "ready" ? draft.reading.value : null
}

export function totalFor(session: Session, player: Player) {
  return BASE_TOTALS[player] + (session.roundScores[player] ?? 0)
}
