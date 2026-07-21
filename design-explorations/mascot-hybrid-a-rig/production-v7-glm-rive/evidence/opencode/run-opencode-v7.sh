#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/prateekranka/Cowork/ScoreKeeper"
V7="$ROOT/design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive"
EVIDENCE="$V7/evidence/opencode"
BRIEF="${OPENCODE_BRIEF:-$EVIDENCE/implementation-brief.md}"
STATUS="$EVIDENCE/opencode-status.md"
OPENCODE="/Users/prateekranka/.opencode/bin/opencode"
TIMEOUT_SECONDS="${OPENCODE_TIMEOUT_SECONDS:-1800}"
CONTINUE_SESSION="${OPENCODE_CONTINUE_SESSION:-}"
FOLLOWUP_MESSAGE="${OPENCODE_FOLLOWUP_MESSAGE:-Execute the attached implementation brief exactly. Stay within its local and live scopes, keep the status backchannel current, and stop rather than guessing.}"
FOLLOWUP_FILE="${OPENCODE_FOLLOWUP_FILE:-}"
USE_PURE="${OPENCODE_PURE:-0}"
PRIMARY_AGENT="${OPENCODE_AGENT:-}"
if [[ -n "$FOLLOWUP_FILE" ]]; then
  FOLLOWUP_MESSAGE="$(<"$FOLLOWUP_FILE")"
fi
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$EVIDENCE/runs/$STAMP-$$"
LOCK_DIR="$EVIDENCE/.run-lock"
export OPENCODE_RUN_ID="$STAMP-$$"
export RIVE_V3_TEMP_NAME="__V3_TEMP__ ScoreKeeper Cup Hybrid A $OPENCODE_RUN_ID"
export RIVE_V3_MACHINE_NAME="__V3_TEMP__ ScoreKeeper Cup Behaviors $OPENCODE_RUN_ID"

OPENCODE_COMMAND=(
  "$OPENCODE" run
  "$FOLLOWUP_MESSAGE"
  --model opencode-go/glm-5.2
  --variant max
  --format json
  --dir "$ROOT"
)
if [[ "$USE_PURE" == "1" ]]; then
  OPENCODE_COMMAND+=(--pure)
fi
if [[ -n "$PRIMARY_AGENT" ]]; then
  OPENCODE_COMMAND+=(--agent "$PRIMARY_AGENT")
fi
if [[ -n "$CONTINUE_SESSION" ]]; then
  OPENCODE_COMMAND+=(--session "$CONTINUE_SESSION")
else
  OPENCODE_COMMAND+=(--file "$BRIEF")
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "OpenCode v7 pass lock is already held: $LOCK_DIR" >&2
  exit 2
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

mkdir -p "$RUN_DIR"
cp "$BRIEF" "$RUN_DIR/brief.md"
git -C "$ROOT" status --short --branch --untracked-files=all > "$RUN_DIR/git-status-before.txt"
find "$ROOT" -type f -not -path "$ROOT/.git/*" -print0 \
  | sort -z \
  | xargs -0 shasum -a 256 > "$RUN_DIR/manifest-before.tsv"

cat > "$RUN_DIR/command.txt" <<EOF
$OPENCODE run <bounded message> --model opencode-go/glm-5.2 --variant max --format json --dir $ROOT ${CONTINUE_SESSION:+--session $CONTINUE_SESSION} ${CONTINUE_SESSION:---file $BRIEF}
EOF

cat > "$RUN_DIR/metadata.json" <<EOF
{
  "task": "scorekeeper-production-v7-glm-rive",
  "startedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "model": "opencode-go/glm-5.2",
  "variant": "max",
  "format": "json",
  "opencodeVersion": "$($OPENCODE --version)",
  "timeoutSeconds": $TIMEOUT_SECONDS,
  "continuationSession": "$CONTINUE_SESSION",
  "followupFile": "$FOLLOWUP_FILE",
  "pure": "$USE_PURE",
  "primaryAgent": "$PRIMARY_AGENT",
  "allowedPaths": [
    "design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/generated/",
    "design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/opencode/opencode-status.md",
    "design-explorations/mascot-hybrid-a-rig/production-v7-glm-rive/evidence/opencode/runs/"
  ],
  "runId": "$OPENCODE_RUN_ID",
  "tempArtboardName": "$RIVE_V3_TEMP_NAME",
  "tempMachineName": "$RIVE_V3_MACHINE_NAME",
  "liveScope": "new uniquely named v3 temporary artboard in Rive file 2434585 only"
}
EOF

set +e
python3 "$EVIDENCE/run-with-timeout.py" \
  "$TIMEOUT_SECONDS" \
  "$RUN_DIR/stdout.jsonl" \
  "$RUN_DIR/stderr.log" \
  "${OPENCODE_COMMAND[@]}"
OPENCODE_EXIT=$?
set -e

git -C "$ROOT" status --short --branch --untracked-files=all > "$RUN_DIR/git-status-after.txt"
find "$ROOT" -type f -not -path "$ROOT/.git/*" -print0 \
  | sort -z \
  | xargs -0 shasum -a 256 > "$RUN_DIR/manifest-after.tsv"

python3 - "$RUN_DIR/manifest-before.tsv" "$RUN_DIR/manifest-after.tsv" "$RUN_DIR/changed-during-run.txt" <<'PY'
import sys

def load(path):
    result = {}
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            digest, filename = line.rstrip("\n").split("  ", 1)
            result[filename] = digest
    return result

before = load(sys.argv[1])
after = load(sys.argv[2])
changed = sorted(path for path in set(before) | set(after) if before.get(path) != after.get(path))
with open(sys.argv[3], "w", encoding="utf-8") as handle:
    for path in changed:
        handle.write(path + "\n")
PY

python3 - "$RUN_DIR/changed-during-run.txt" "$RUN_DIR/scope-violations.txt" \
  "$V7/generated/" "$STATUS" "$RUN_DIR/" <<'PY'
import sys

source, output, *allowed = sys.argv[1:]
with open(source, encoding="utf-8") as handle:
    paths = [line.rstrip("\n") for line in handle if line.strip()]
violations = [path for path in paths if not any(path == prefix or path.startswith(prefix) for prefix in allowed)]
with open(output, "w", encoding="utf-8") as handle:
    for path in violations:
        handle.write(path + "\n")
PY

SCOPE_COUNT="$(wc -l < "$RUN_DIR/scope-violations.txt" | tr -d ' ')"
if [[ "$OPENCODE_EXIT" -eq 124 ]]; then
  STATUS_VALUE="timeout"
elif [[ "$OPENCODE_EXIT" -ne 0 ]]; then
  STATUS_VALUE="opencode_failed"
elif [[ "$SCOPE_COUNT" -ne 0 ]]; then
  STATUS_VALUE="scope_violation"
else
  STATUS_VALUE="done"
fi

cat > "$RUN_DIR/result.json" <<EOF
{
  "status": "$STATUS_VALUE",
  "opencodeExitCode": $OPENCODE_EXIT,
  "scopeViolationCount": $SCOPE_COUNT,
  "finishedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "evidenceDir": "$RUN_DIR"
}
EOF

echo "$RUN_DIR"
if [[ "$STATUS_VALUE" == "scope_violation" ]]; then
  exit 3
fi
exit "$OPENCODE_EXIT"
