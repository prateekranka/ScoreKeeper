import { useEffect, useRef, useState } from "react"
import { ArrowLeft, Check, ShieldCheck } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

type Connection = {
  configured: boolean
  mode: "local" | "awaiting_evaluation" | "verify"
  csrfToken: string
  error?: string | null
  engineering?: { choice: string; confidence: number } | null
  evaluation?: { samples: number; valid: number; accepted: number; wrongAccepted: number; eligible: boolean; p95Seconds: number; userSamples: number; userCandidatesCorrect: number; userAcceptedCorrect: number } | null
}

const errors: Record<string, string> = {
  authentication: "TypeSafe could not accept that key, so please check it and try again",
  invalid_key: "Please enter the complete TypeSafe API key",
  keychain: "Please unlock the login Keychain on your Mac and try again",
  forbidden: "Please reload this page before connecting Jev",
  model_changed: "TypeSafe returned a different model, so we need to review it before connecting",
}
const recommendations: Record<string, string> = {
  evaluate_veto: "Jev recommends measuring an independent check before it affects score acceptance",
  evaluate_primary: "Jev recommends measuring whether it can read scores that the local models reject",
  collect_writers: "Jev recommends collecting handwriting from more people before changing acceptance",
  retain_local: "Jev recommends keeping local recognition while we gather more evidence",
}

export function JevSetup() {
  const [connection, setConnection] = useState<Connection | null>(null)
  const [key, setKey] = useState("")
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState("")
  const controller = useRef<AbortController | null>(null)

  useEffect(() => {
    document.title = "Connect Jev · PipCount"
    const request = new AbortController()
    fetch("/api/jev/status", { signal: request.signal, cache: "no-store" })
      .then(response => { if (!response.ok) throw new Error(); return response.json() as Promise<Connection> })
      .then(value => { setConnection(value); if (value.error) setMessage(errors[value.error] ?? "The connection is unavailable, so please try again shortly") })
      .catch(() => { if (!request.signal.aborted) setMessage("The connection is unavailable, so please reload this page") })
    return () => { request.abort(); controller.current?.abort() }
  }, [])

  async function connect(event: React.FormEvent) {
    event.preventDefault()
    if (!connection || !key.trim() || busy) return
    const submitted = key
    setKey("")
    setBusy(true)
    setMessage("")
    const request = new AbortController()
    controller.current = request
    const deadline = setTimeout(() => request.abort(), 20000)
    try {
      const response = await fetch("/api/jev/connect", {
        method: "POST", signal: request.signal,
        headers: { "Content-Type": "application/json", "X-Pipcount-CSRF": connection.csrfToken },
        body: JSON.stringify({ apiKey: submitted }),
      })
      const result = await response.json()
      if (!response.ok) { setMessage(errors[result.reason] ?? "Jev could not connect, so please try again shortly"); return }
      setConnection({ ...result, csrfToken: connection.csrfToken })
      setMessage("Jev is connected and ready for evaluation")
    } catch {
      setMessage("Jev could not connect, so please try again shortly")
    } finally {
      clearTimeout(deadline)
      setBusy(false)
    }
  }

  return <main className="jev-setup">
    <div className="jev-setup-card">
      <a className="jev-back" href="/?state=write&preset=softer"><ArrowLeft aria-hidden="true" />Back to your game</a>
      <div className="jev-mark" aria-hidden="true"><ShieldCheck /></div>
      <h1>Connect Jev to PipCount</h1>
      <p>Jev can help us choose how to improve recognition and independently check a handwritten score</p>
      <p>Your key stays in the login Keychain on this Mac and never enters the game’s saved data</p>
      <form onSubmit={connect} aria-label="Connect Jev">
        <label htmlFor="jev-api-key">TypeSafe API key</label>
        <Input id="jev-api-key" name="api-key" type="password" autoComplete="new-password" autoCapitalize="none" spellCheck={false} value={key} onChange={event => setKey(event.target.value)} disabled={busy} aria-describedby="jev-key-help" />
        <p id="jev-key-help" className="jev-help">Connecting makes one request for Jev’s engineering advice and confirms your key works</p>
        <Button type="submit" className="jev-connect" disabled={!connection || !key.trim() || busy}>{busy ? "Connecting Jev" : connection?.configured ? "Replace key" : "Connect Jev"}</Button>
      </form>
      <p className="jev-message" role="status" aria-live="polite">{message || (connection?.mode === "verify" ? "Jev is checking accepted readings after passing the evaluation gate" : connection?.evaluation && !connection.evaluation.eligible ? "Jev is connected, but this handwriting check needs more work" : connection?.configured ? "Jev is connected and waiting for evaluation" : connection ? "Your game is using local recognition while Jev is disconnected" : "We’re checking the connection")}</p>
      {connection?.engineering && <p className="jev-recommendation" data-testid="jev-recommendation"><Check aria-hidden="true" />{recommendations[connection.engineering.choice]}</p>}
      <a className="collection-link" href="/handwriting">Add handwriting samples</a>
      {connection?.evaluation && <section className="jev-disclosure" aria-label="Latest handwriting evaluation">
        <h2>Here’s what the handwriting check found</h2>
        <p>Jev accepted {connection.evaluation.accepted} of {connection.evaluation.valid} valid scores in a comparison of {connection.evaluation.samples} drawings</p>
        <p>{connection.evaluation.wrongAccepted === 0 ? "None of the accepted readings was wrong on this set" : `${connection.evaluation.wrongAccepted} accepted readings were wrong on this set`}</p>
        <p>Before filtering, its best reading matched {connection.evaluation.userCandidatesCorrect} of your {connection.evaluation.userSamples} examples, but only {connection.evaluation.userAcceptedCorrect} passed the acceptance filters</p>
        {!connection.evaluation.eligible && <p>Your game will keep local recognition while we improve this check</p>}
      </section>}
      <div className="jev-disclosure">
        <h2>We’ll measure it before it checks your scores</h2>
        <p>Evaluation sends score drawings to TypeSafe and compares the readings with known answers</p>
        <p>If the evaluation passes, Jev will receive each locally accepted drawing to check it independently</p>
        <p>Player names, totals and game history stay on your device</p>
        <p>TypeSafe’s image support is experimental and no recogniser can promise every reading will be correct</p>
      </div>
    </div>
  </main>
}
