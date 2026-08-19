#!/bin/bash
# ScoreKeeper Paper Bauhaus redesign loop
# Critic:       openai/gpt-5.6-sol (max)   — blind, judges only the artifact
# Orchestrator: opencode-go/qwen3.8-max    — triages critique into directives
# Implementer:  opencode-go/gpt-5.6-luna (max) — builds/fixes the prototype
set -u
cd "$(dirname "$0")"
export PATH="$HOME/.opencode/bin:$PATH"
MAX_ITERS="${MAX_ITERS:-10}"

status() { echo "$(date '+%F %T') — $1" | tee -a logs/loop.log > STATUS; }

run_agent() { # dir model title promptfile timeout [variant]
  local dir="$1" model="$2" title="$3" pf="$4" tmo="$5" variant="${6:-}"
  local vflag=""
  [ -n "$variant" ] && vflag="--variant $variant"
  for attempt in 1 2 3; do
    [ -f STOP ] && { status "STOP sentinel found, exiting"; exit 0; }
    perl -e 'alarm shift; exec @ARGV' "$tmo" \
      opencode run --dir "$dir" --model "$model" $vflag --auto \
        --title "$title" "$(cat "$pf")" > "logs/${title}.log" 2>&1
    local rc=$?
    if [ $rc -eq 0 ] && ! grep -q 'Insufficient balance' "logs/${title}.log"; then
      return 0
    fi
    status "[$title] attempt $attempt failed (rc=$rc), retry in 3m"
    sleep 180
  done
  status "[$title] FAILED after 3 attempts — continuing anyway"
  return 1
}

mkdir -p logs reports

# ---- iteration 0: bootstrap build if missing ----
if [ ! -f app/index.html ]; then
  status "BOOTSTRAP: implementer (gpt-5.6-luna max) building prototype"
  run_agent app opencode-go/gpt-5.6-luna impl-bootstrap prompts/bootstrap.txt 3600 max
  [ -f app/index.html ] || { status "FATAL: bootstrap produced no index.html"; exit 1; }
  status "Bootstrap complete"
fi

# ---- critique/orchestrate/implement loop ----
i=1
while [ $i -le "$MAX_ITERS" ]; do
  [ -f STOP ] && { status "STOP sentinel found, exiting"; exit 0; }
  SNAP="reports/iter-$i/snapshot"
  rm -rf "$SNAP"; mkdir -p "$SNAP"
  rsync -a --exclude='.context' --exclude='context' --exclude='DIRECTIVE.md' --exclude='CHANGELOG.md' \
        --exclude='node_modules' --exclude='.git' app/ "$SNAP/"
  cp reports/MISSION.md reports/animation-standards.md "$SNAP/"

  status "ITER $i: blind critic (gpt-5.6-sol max) reviewing snapshot"
  run_agent "$SNAP" openai/gpt-5.6-sol "critic-$i" prompts/critic.txt 1800 max
  if grep -q '^VERDICT: AAA' "$SNAP/CRITIC.md" 2>/dev/null; then
    status "ITER $i: CRITIC SAYS AAA — loop complete at iteration $i"
    echo "iter-$i" > reports/AAA-ITER
    exit 0
  fi
  cp app/context/brand-spec.md "$SNAP/brand-spec.md"
  status "ITER $i: verdict NOT YET — orchestrator (qwen3.8-max) triaging"

  run_agent "$SNAP" opencode-go/qwen3.8-max "orch-$i" prompts/orchestrate.txt 1500
  if grep -q 'NO-OP' "$SNAP/DIRECTIVE.md" 2>/dev/null; then
    status "ITER $i: orchestrator says NO-OP — loop complete"
    exit 0
  fi
  cp "$SNAP/DIRECTIVE.md" app/DIRECTIVE.md
  status "ITER $i: implementer (gpt-5.6-luna max) executing directive"

  run_agent app opencode-go/gpt-5.6-luna "impl-$i" prompts/implement.txt 3000 max
  i=$((i+1))
done
status "Reached MAX_ITERS=$MAX_ITERS without AAA verdict — loop ended"
