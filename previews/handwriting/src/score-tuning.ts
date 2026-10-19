import { useEffect, useLayoutEffect } from "react"
import { useDialKitController, type DialConfig, type DialKitValueUpdates } from "dialkit"

export const SCORE_DIAL_CONFIG = {
  layout: {
    canvasHeight: [340, 260, 400, 4],
    dialogPadding: [20, 16, 28, 1],
    controlGap: [12, 8, 20, 1],
    confirmWidth: [60, 40, 65, 1],
  },
  corners: {
    dialog: [32, 20, 44, 1],
    buttons: [18, 8, 26, 1],
  },
  tone: {
    _collapsed: true,
    backdrop: [24, 10, 35, 1],
    shadow: [10, 0, 18, 1],
  },
  motion: {
    _collapsed: true,
    opening: [200, 120, 280, 10],
    press: [140, 80, 180, 10],
    replay: { type: "action", label: "Replay opening" },
  },
} satisfies DialConfig

type ScorePreset = DialKitValueUpdates<typeof SCORE_DIAL_CONFIG>

export const SCORE_PRESETS: Record<"current" | "softer" | "compact", ScorePreset> = {
  current: {
    layout: { canvasHeight: 340, dialogPadding: 20, controlGap: 12, confirmWidth: 60 },
    corners: { dialog: 32, buttons: 18 },
    tone: { backdrop: 24, shadow: 10 },
    motion: { opening: 200, press: 140 },
  },
  softer: {
    layout: { canvasHeight: 340, dialogPadding: 22, controlGap: 10, confirmWidth: 60 },
    corners: { dialog: 36, buttons: 22 },
    tone: { backdrop: 22, shadow: 8 },
    motion: { opening: 220, press: 130 },
  },
  compact: {
    layout: { canvasHeight: 300, dialogPadding: 18, controlGap: 10, confirmWidth: 60 },
    corners: { dialog: 28, buttons: 16 },
    tone: { backdrop: 24, shadow: 8 },
    motion: { opening: 180, press: 120 },
  },
}

export function useScoreTuning(onReplay: () => void) {
  const query = new URLSearchParams(window.location.search)
  const enabled = query.get("tune") === "1"
  const requestedPreset = query.get("preset")
  const dial = useDialKitController("PipCount score entry", SCORE_DIAL_CONFIG, {
    id: "pipcount-score-entry-v1",
    persist: true,
    onAction: path => {
      if (path === "motion.replay") onReplay()
    },
  })

  useEffect(() => {
    if (requestedPreset === "current" || requestedPreset === "softer" || requestedPreset === "compact") {
      dial.setValues(SCORE_PRESETS[requestedPreset])
    }
  }, [requestedPreset])

  useLayoutEffect(() => {
    const values = dial.values
    const sideWidth = (100 - values.layout.confirmWidth) / 2
    const properties = {
      "--pc-canvas-height": `${values.layout.canvasHeight}px`,
      "--pc-dialog-padding": `${values.layout.dialogPadding}px`,
      "--pc-control-gap": `${values.layout.controlGap}px`,
      "--pc-action-columns": `minmax(44px,${sideWidth}fr) minmax(44px,${values.layout.confirmWidth}fr) minmax(44px,${sideWidth}fr)`,
      "--pc-dialog-radius": `${values.corners.dialog}px`,
      "--pc-button-radius": `${values.corners.buttons}px`,
      "--pc-backdrop-opacity": String(values.tone.backdrop / 100),
      "--pc-shadow-opacity": String(values.tone.shadow / 100),
      "--pc-opening-duration": `${values.motion.opening}ms`,
      "--pc-press-duration": `${values.motion.press}ms`,
    }
    for (const [name, value] of Object.entries(properties)) {
      document.documentElement.style.setProperty(name, value)
    }
    document.documentElement.classList.toggle("is-tuning", enabled)
  }, [dial.values, enabled])

  return { dial, enabled }
}

export type ScoreTuningController = ReturnType<typeof useScoreTuning>["dial"]
