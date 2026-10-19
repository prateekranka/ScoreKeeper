import { useEffect, useRef } from "react"
import { scoreImage } from "./ScoreCanvas"
import { validScore, type Draft, type Reading } from "./scoring"

export function useRecognition(draft: Draft, enabled: boolean, onResult: (reading: Reading) => void) {
  const callback = useRef(onResult)
  callback.current = onResult
  useEffect(() => {
    if (!enabled || draft.mode !== "write" || !draft.strokes.length) return
    let active = true
    let deadline: ReturnType<typeof setTimeout> | undefined
    const controller = new AbortController()
    const applyResult = callback.current
    applyResult({ status: "waiting", value: null })
    const timer = setTimeout(async () => {
      applyResult({ status: "reading", value: null })
      deadline = setTimeout(() => {
        if (active) applyResult({ status: "error", value: null })
        controller.abort()
      }, 30000)
      try {
        const image = await scoreImage(draft.strokes)
        const response = await fetch("/api/recognise", { method: "POST", headers: { "Content-Type": "image/png" }, body: image, signal: controller.signal })
        if (!response.ok) throw new Error("Recognition unavailable")
        const result = await response.json() as { status?: string; value?: unknown }
        if (active && !controller.signal.aborted) applyResult(result.status === "ready" && validScore(result.value)
          ? { status: "ready", value: result.value }
          : { status: result.status === "error" ? "error" : "unreadable", value: null })
      } catch {
        if (active && !controller.signal.aborted) applyResult({ status: "error", value: null })
      } finally {
        clearTimeout(deadline)
      }
    }, 450)
    return () => { active = false; clearTimeout(timer); clearTimeout(deadline); controller.abort() }
  }, [draft.strokes, draft.mode, enabled])
}
