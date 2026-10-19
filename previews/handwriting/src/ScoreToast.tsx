import { useEffect, useLayoutEffect, useRef, useState } from "react"
import { Check, X } from "lucide-react"
import { Button } from "@/components/ui/button"

export type Notification = { id: number; message: string; undo: boolean }
type Props = { notification: Notification; onUndo: () => void; onDismiss: () => void }

export function ScoreToast({ notification, onUndo, onDismiss }: Props) {
  const ref = useRef<HTMLDivElement>(null)
  const [paused, setPaused] = useState(false)
  useLayoutEffect(() => {
    const element = ref.current
    if (!element) return
    if (typeof element.showPopover === "function") {
      if (!element.matches(":popover-open")) element.showPopover()
    } else element.dataset.fallback = "true"
    return () => { if (element.matches(":popover-open")) element.hidePopover() }
  }, [notification.id])
  useEffect(() => {
    if (paused) return
    const timer = setTimeout(onDismiss, 8000)
    return () => clearTimeout(timer)
  }, [notification.id, paused, onDismiss])
  return <div ref={ref} popover="manual" className="score-toast" data-testid="score-toast" onPointerEnter={() => setPaused(true)} onPointerLeave={() => setPaused(false)} onFocus={() => setPaused(true)} onBlur={event => {
    if (!event.currentTarget.contains(event.relatedTarget)) setPaused(false)
  }}>
    <Check className="toast-check" aria-hidden="true" />
    <p role="status" aria-live="polite" aria-atomic="true">{notification.message}</p>
    {notification.undo && <Button variant="ghost" className="toast-undo" onClick={onUndo}>Undo</Button>}
    <Button variant="ghost" size="icon" className="toast-close" aria-label="Dismiss message" onClick={onDismiss}><X aria-hidden="true" /></Button>
  </div>
}
