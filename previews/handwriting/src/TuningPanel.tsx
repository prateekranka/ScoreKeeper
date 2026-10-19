import { DialRoot } from "dialkit"
import { Button } from "@/components/ui/button"
import { SCORE_PRESETS, type ScoreTuningController } from "./score-tuning"

type Props = {
  dial: ScoreTuningController
  mode: "write" | "type"
  onModeChange: (mode: "write" | "type") => void
  onReset: () => void
}

export function TuningPanel({ dial, mode, onModeChange, onReset }: Props) {
  const sideWidth = (100 - dial.values.layout.confirmWidth) / 2
  return <aside className="tuning-panel" aria-label="Design controls" data-testid="tuning-panel">
    <header>
      <p className="tuning-kicker">PIPCOUNT DESIGN PREVIEW</p>
      <h1>Dial in score entry</h1>
      <p>Compare the presets or adjust a value while you watch the preview</p>
    </header>
    <div className="tuning-presets" aria-label="Design presets">
      <Button variant="outline" onClick={() => dial.setValues(SCORE_PRESETS.current)}>Current</Button>
      <Button variant="outline" onClick={() => dial.setValues(SCORE_PRESETS.softer)}>Softer</Button>
      <Button variant="outline" onClick={() => dial.setValues(SCORE_PRESETS.compact)}>Compact</Button>
    </div>
    <div className="tuning-state" aria-label="Preview state">
      <Button variant={mode === "write" ? "secondary" : "ghost"} aria-pressed={mode === "write"} onClick={() => onModeChange("write")}>Writing</Button>
      <Button variant={mode === "type" ? "secondary" : "ghost"} aria-pressed={mode === "type"} onClick={() => onModeChange("type")}>Typing</Button>
    </div>
    <p className="tuning-ratio" data-testid="tuning-ratio">Button widths <strong>{sideWidth} : {dial.values.layout.confirmWidth} : {sideWidth}</strong></p>
    <DialRoot mode="inline" theme="light" productionEnabled />
    <footer>
      <a href={`/?state=${mode}`} target="_blank" rel="noreferrer">Open clean preview</a>
      <Button variant="ghost" className="reset-preview" onClick={onReset}>Reset preview</Button>
      <p>Your changes and saved versions stay in this browser</p>
    </footer>
  </aside>
}
