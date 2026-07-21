export const STATE_MACHINE_SPEC = Object.freeze({
  integrationLevel: "mapping-only",
  name: "ScoreKeeper Cup Hybrid A Behaviors v1",
  layerName: "Behavior",
  defaultState: "Idle",
  states: [
    { name: "Idle", animation: "idle", x: 140, y: 120 },
    { name: "Celebrate", animation: "celebrate", x: 390, y: 120 },
    { name: "Hair Sway", animation: "hair_sway", x: 640, y: 120 },
  ],
  inputs: [],
  transitions: [{ from: "{Entry State}", to: "Idle" }],
  automatedBehaviorInputs: false,
});
