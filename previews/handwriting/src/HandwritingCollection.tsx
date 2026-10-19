import { useCallback, useEffect, useRef, useState } from "react"
import { ArrowLeft, Check, Download, Eraser, Undo2, UserRoundPlus } from "lucide-react"
import { Button } from "@/components/ui/button"
import { ScoreCanvas } from "./ScoreCanvas"
import { validScore, type Stroke } from "./scoring"

const STORAGE_KEY = "pipcount-handwriting-collection-v1"
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
type SampleDraft = { id: string; promptIndex: number; expected: number; strokes: Stroke[]; pointerTypes: string[] }
type Writer = { id: string; label: string; draft: SampleDraft }
type Collection = { current: string; writers: Writer[] }
type Session = { writerId: string; promptIndex: number; expected: number; writerSaved: number; totalSaved: number; writerCount: number; writerTarget: number; lastSample: { id: string; expected: number } | null; csrfToken: string }

function emptyDraft(promptIndex = 0, expected = 0): SampleDraft {
  return { id: crypto.randomUUID(), promptIndex, expected, strokes: [], pointerTypes: [] }
}
function newWriter(index: number): Writer {
  return { id: crypto.randomUUID(), label: `Writer ${index}`, draft: emptyDraft() }
}
function loadCollection(): Collection {
  try {
    const data = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "null") as Collection
    if (!data || !Array.isArray(data.writers) || !data.writers.length || data.writers.length > 20 || !data.writers.some(writer => writer.id === data.current) || new Set(data.writers.map(writer => writer.id)).size !== data.writers.length) throw new Error()
    for (const writer of data.writers) {
      const draft = writer.draft
      if (!uuid.test(writer.id) || typeof writer.label !== "string" || !/^Writer \d{1,2}$/.test(writer.label) || !draft || !uuid.test(draft.id) || !Number.isInteger(draft.promptIndex) || draft.promptIndex < 0 || !validScore(draft.expected) || !Array.isArray(draft.pointerTypes) || draft.pointerTypes.some(kind => !["touch", "pen", "mouse"].includes(kind)) || !Array.isArray(draft.strokes) || draft.strokes.length > 100 || draft.strokes.flat().length > 10000) throw new Error()
      for (const stroke of draft.strokes) if (!Array.isArray(stroke) || !stroke.length || stroke.length > 1500 || stroke.some(point => !Number.isFinite(point.x) || !Number.isFinite(point.y) || point.x < 0 || point.x > 1000 || point.y < 0 || point.y > 1000)) throw new Error()
    }
    return data
  } catch {
    const writer = newWriter(1)
    return { current: writer.id, writers: [writer] }
  }
}

export function HandwritingCollection() {
  const [collection, setCollection] = useState(loadCollection)
  const current = collection.writers.find(writer => writer.id === collection.current)!
  const draft = current.draft
  const [session, setSession] = useState<Session | null>(null)
  const [busy, setBusy] = useState(false)
  const [drawing, setDrawing] = useState(false)
  const [message, setMessage] = useState("")
  const stateRef = useRef(collection)
  stateRef.current = collection
  const title = useRef<HTMLHeadingElement>(null)
  const requestRef = useRef<AbortController | null>(null)
  const updateWriter = useCallback((id: string, change: (writer: Writer) => Writer) => {
    setCollection(previous => ({ ...previous, writers: previous.writers.map(writer => writer.id === id ? change(writer) : writer) }))
  }, [])
  const conflict = session !== null && (session.promptIndex !== draft.promptIndex || session.expected !== draft.expected)
  const ready = session !== null && session.writerId === current.id

  useEffect(() => {
    document.title = "Handwriting samples · PipCount"
    const timer = setTimeout(() => { try { localStorage.setItem(STORAGE_KEY, JSON.stringify(collection)) } catch {} }, 180)
    return () => clearTimeout(timer)
  }, [collection])
  useEffect(() => {
    const save = () => { try { localStorage.setItem(STORAGE_KEY, JSON.stringify(stateRef.current)) } catch {} }
    window.addEventListener("pagehide", save)
    return () => { save(); window.removeEventListener("pagehide", save); requestRef.current?.abort() }
  }, [])
  useEffect(() => {
    const controller = new AbortController()
    const id = collection.current
    setSession(null)
    setMessage("")
    fetch(`/api/handwriting/session?writer=${encodeURIComponent(id)}`, { signal: controller.signal, cache: "no-store" })
      .then(response => { if (!response.ok) throw new Error(); return response.json() as Promise<Session> })
      .then(value => {
        setSession(value)
        updateWriter(id, writer => {
          if (!writer.draft.strokes.length || writer.draft.id === value.lastSample?.id) return { ...writer, draft: emptyDraft(value.promptIndex, value.expected) }
          return writer
        })
      })
      .catch(() => { if (!controller.signal.aborted) setMessage("We couldn’t open the collection, so please reload this page") })
    return () => controller.abort()
  }, [collection.current, updateWriter])

  function clear() {
    if (!session) return
    setDrawing(false)
    setMessage("")
    updateWriter(current.id, writer => ({ ...writer, draft: emptyDraft(session.promptIndex, session.expected) }))
  }
  async function submit(undo: boolean) {
    if (!ready || !session || busy || drawing || (undo ? !session.lastSample || draft.strokes.length > 0 : conflict || !draft.strokes.length)) return
    const writerId = current.id
    const nonce = session.csrfToken
    const expected = draft.expected
    const controller = new AbortController()
    requestRef.current = controller
    const timeout = setTimeout(() => controller.abort(), 15000)
    setBusy(true)
    setMessage("")
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(stateRef.current))
    } catch {}
    try {
      const body = undo ? { writerId, id: session.lastSample!.id } : { writerId, id: draft.id, promptIndex: draft.promptIndex, expected, strokes: draft.strokes, metadata: { width: innerWidth, height: innerHeight, pixelRatio: devicePixelRatio, pointerTypes: draft.pointerTypes } }
      const response = await fetch(undo ? "/api/handwriting/undo" : "/api/handwriting/samples", { method: "POST", signal: controller.signal, headers: { "Content-Type": "application/json", "X-Pipcount-CSRF": nonce }, body: JSON.stringify(body) })
      const result = await response.json()
      if (!response.ok) {
        if (result.reason === "write_first") setMessage("Please write the score before saving your sample")
        else if (response.status === 409 || result.reason === "forbidden") {
          const fresh = await fetch(`/api/handwriting/session?writer=${encodeURIComponent(writerId)}`, { cache: "no-store", signal: controller.signal })
          if (fresh.ok) setSession(await fresh.json())
          setMessage(result.reason === "forbidden" ? "The connection has been refreshed, so you can try saving this drawing again" : "This writer has moved on in another tab, so clear this drawing to load the current score")
        } else setMessage("We couldn’t save this sample, so your drawing is still here to try again")
        return
      }
      setSession({ ...result.session, csrfToken: nonce })
      updateWriter(writerId, writer => ({ ...writer, draft: { ...emptyDraft(result.session.promptIndex, result.session.expected), ...(undo ? { strokes: result.strokes, pointerTypes: result.metadata.pointerTypes } : {}) } }))
      setMessage(undo ? "Your previous drawing is back here so you can change it" : `Your ${expected} has been saved, and you can write ${result.session.expected} next`)
      requestAnimationFrame(() => title.current?.focus({ preventScroll: true }))
    } catch {
      setMessage("We couldn’t confirm the save, so your drawing is still here to try again")
    } finally {
      clearTimeout(timeout)
      setBusy(false)
    }
  }

  return <main className="handwriting-page">
    <div className="handwriting-shell">
      <header className="handwriting-header">
        <a className="jev-back" href="/?state=write&preset=softer"><ArrowLeft aria-hidden="true" />Back to your game</a>
        <span className="collection-brand"><i aria-hidden="true" />PipCount</span>
      </header>
      <section className="collection-intro">
        <h1>Show us how you write</h1>
        <p>We’ll show you a score to write and save each example for our next evaluation</p>
      </section>
      <div className="writer-controls">
        <label htmlFor="sample-writer">Who’s writing?</label>
        <div><select id="sample-writer" disabled={busy || drawing} value={collection.current} onChange={event => { setDrawing(false); setCollection(previous => ({ ...previous, current: event.target.value })) }}>{collection.writers.map(writer => <option key={writer.id} value={writer.id}>{writer.label}</option>)}</select>
          <Button variant="outline" disabled={busy || drawing || collection.writers.length >= 20} onClick={() => { const writer = newWriter(collection.writers.length + 1); setCollection(previous => ({ current: writer.id, writers: [...previous.writers, writer] })) }}><UserRoundPlus aria-hidden="true" />New writer</Button>
        </div>
        <p>Choose a new writer only when a different person starts</p>
      </div>
      <section className="sample-card" aria-label="Handwriting sample">
        <div className="sample-heading"><div><h2 ref={title} tabIndex={-1}>Write <strong data-testid="sample-expected">{draft.expected}</strong> in your usual handwriting</h2><p>Use your finger or a pen and write it as you would during a game</p></div><span className="sample-token" aria-hidden="true" /></div>
        <div className="sample-workspace">
          <div className="sample-writing-surface">
            {!draft.strokes.length && <span className="sample-canvas-hint">Write {draft.expected} here</span>}
            <ScoreCanvas key={current.id} label={`Writing area for ${draft.expected}`} disabled={!ready || busy} captureDetails strokes={draft.strokes} onDrawing={value => { setDrawing(value); if (value) setMessage("") }} onPointerType={kind => updateWriter(current.id, writer => ({ ...writer, draft: { ...writer.draft, pointerTypes: Array.from(new Set([...writer.draft.pointerTypes, kind])).filter(value => ["touch", "pen", "mouse"].includes(value)) } }))} onChange={strokes => updateWriter(current.id, writer => ({ ...writer, draft: { ...writer.draft, strokes } }))} />
          </div>
          <div className="sample-controls">
            <p className="sample-status" role="status" aria-live="polite">{message || (conflict ? "This writer has moved on in another tab, so clear this drawing to load the current score" : ready ? "Check that your drawing matches the score above, then save it to continue" : "We’re opening your handwriting collection")}</p>
            <div className="sample-action-row">
              <Button variant="outline" aria-label="Clear drawing" title="Clear drawing" disabled={busy || drawing || !ready || (!draft.strokes.length && !conflict)} onClick={clear}><Eraser aria-hidden="true" /></Button>
              <Button className="sample-save" aria-label="Save sample" disabled={busy || drawing || !ready || conflict || !draft.strokes.length} onClick={() => void submit(false)}><Check aria-hidden="true" /><span>{busy ? "Saving" : "Save sample"}</span></Button>
              <Button variant="outline" aria-label="Undo last stroke" title="Undo last stroke" disabled={busy || drawing || !draft.strokes.length} onClick={() => updateWriter(current.id, writer => ({ ...writer, draft: { ...writer.draft, strokes: writer.draft.strokes.slice(0, -1) } }))}><Undo2 aria-hidden="true" /></Button>
            </div>
            <p className="writer-progress" data-testid="writer-progress">{session ? session.writerSaved < 40 ? `You’ve saved ${session.writerSaved} of 40 samples for this writer` : `You’ve saved ${session.writerSaved} samples for this writer` : "Your progress will appear here"}</p>
            <progress aria-label="Progress for this writer" max={40} value={Math.min(40, session?.writerSaved ?? 0)} />
            {session?.lastSample && <Button variant="ghost" className="undo-sample" disabled={busy || drawing || draft.strokes.length > 0} onClick={() => void submit(true)}><Undo2 aria-hidden="true" />Undo last saved sample</Button>}
          </div>
        </div>
      </section>
      <footer className="collection-footer">
        <p data-testid="collection-progress">{session ? `${session.totalSaved} ${session.totalSaved === 1 ? "sample has" : "samples have"} been saved from ${session.writerCount} ${session.writerCount === 1 ? "writer" : "writers"}` : "Your saved samples will appear here"}</p>
        <p>Forty samples from each of three people will help us check more handwriting styles</p>
        <p>Saved drawings stay on your Mac until we run another evaluation and you can leave and return whenever you like</p>
        {Boolean(session?.totalSaved) && <a className="collection-download" href="/api/handwriting/export"><Download aria-hidden="true" />Download samples</a>}
      </footer>
    </div>
  </main>
}
