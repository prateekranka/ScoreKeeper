import { useRef, type PointerEvent } from "react"
import type { Player, Point, Stroke } from "./scoring"

type Props = { player?: Player; label?: string; disabled?: boolean; captureDetails?: boolean; onPointerType?: (kind: string) => void; strokes: Stroke[]; onChange: (strokes: Stroke[]) => void; onDrawing: (drawing: boolean) => void }

export function ScoreCanvas({ player, label, disabled = false, captureDetails = false, onPointerType, strokes, onChange, onDrawing }: Props) {
  const pointer = useRef<number | null>(null)
  const active = useRef<Stroke[]>(strokes)
  active.current = strokes

  function point(event: PointerEvent<SVGSVGElement>): Point {
    const matrix = event.currentTarget.getScreenCTM()
    const position = new DOMPoint(event.clientX, event.clientY).matrixTransform(matrix!.inverse())
    return { x: Math.max(0, Math.min(1000, position.x)), y: Math.max(0, Math.min(1000, position.y)), ...(captureDetails ? { t: event.timeStamp, pressure: event.pressure } : {}) }
  }

  function finish(event: PointerEvent<SVGSVGElement>) {
    if (pointer.current !== event.pointerId) return
    pointer.current = null
    if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId)
    onDrawing(false)
  }

  return <svg className="score-canvas" viewBox="0 0 1000 1000" role="img" aria-label={label ?? `Writing area for ${player}’s score`} aria-disabled={disabled} data-testid="score-canvas" data-stroke-count={strokes.length}
    onPointerDown={event => {
      if (disabled || pointer.current !== null || event.button !== 0 || strokes.length >= 100 || strokes.flat().length >= 10000) return
      event.preventDefault()
      pointer.current = event.pointerId
      event.currentTarget.setPointerCapture(event.pointerId)
      onDrawing(true)
      onPointerType?.(event.pointerType)
      const next = [...active.current, [point(event)]]
      active.current = next
      onChange(next)
    }}
    onPointerMove={event => {
      if (disabled || pointer.current !== event.pointerId) return
      event.preventDefault()
      const current = active.current
      const last = current[current.length - 1]
      if (!last || last.length >= 1500 || current.flat().length >= 10000) return
      const next = [...current.slice(0, -1), [...last, point(event)]]
      active.current = next
      onChange(next)
    }}
    onPointerUp={finish} onPointerCancel={finish} onLostPointerCapture={event => {
      if (pointer.current === event.pointerId) { pointer.current = null; onDrawing(false) }
    }}>
    {strokes.map((stroke, index) => stroke.length === 1
      ? <circle key={index} cx={stroke[0].x} cy={stroke[0].y} r={6} />
      : <polyline key={index} points={stroke.map(value => `${value.x},${value.y}`).join(" ")} />)}
  </svg>
}

export async function scoreImage(strokes: Stroke[]): Promise<Blob> {
  const points = strokes.flat()
  const minX = Math.min(...points.map(point => point.x))
  const minY = Math.min(...points.map(point => point.y))
  const width = Math.max(20, Math.max(...points.map(point => point.x)) - minX)
  const height = Math.max(20, Math.max(...points.map(point => point.y)) - minY)
  const padding = 80
  const scale = 640 / Math.max(width + padding * 2, height + padding * 2)
  const canvas = document.createElement("canvas")
  canvas.width = Math.ceil((width + padding * 2) * scale)
  canvas.height = Math.ceil((height + padding * 2) * scale)
  const context = canvas.getContext("2d")!
  context.fillStyle = "white"
  context.fillRect(0, 0, canvas.width, canvas.height)
  context.strokeStyle = "#191a1c"
  context.fillStyle = "#191a1c"
  context.lineWidth = 12 * scale
  context.lineCap = "round"
  context.lineJoin = "round"
  for (const stroke of strokes) {
    if (stroke.length === 1) {
      context.beginPath()
      context.arc((stroke[0].x - minX + padding) * scale, (stroke[0].y - minY + padding) * scale, 6 * scale, 0, Math.PI * 2)
      context.fill()
    } else {
      context.beginPath()
      stroke.forEach((point, index) => {
        const x = (point.x - minX + padding) * scale
        const y = (point.y - minY + padding) * scale
        if (index === 0) context.moveTo(x, y)
        else context.lineTo(x, y)
      })
      context.stroke()
    }
  }
  return new Promise((resolve, reject) => canvas.toBlob(blob => blob ? resolve(blob) : reject(new Error("Canvas capture failed")), "image/png"))
}
