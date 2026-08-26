#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${PIPCOUNT_DERIVED_DATA:-${RUNNER_TEMP:-/tmp}/PipCountDerivedData}"
PRODUCTS_DIR="$DERIVED_DATA/Build/Products/Debug-iphonesimulator"
EVIDENCE_DIR="$ROOT_DIR/build-evidence"

mkdir -p "$EVIDENCE_DIR"

APP_PATH="$(find "$PRODUCTS_DIR" -maxdepth 1 -type d -name '*.app' -print -quit)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Unable to find a built .app in $PRODUCTS_DIR" >&2
  exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"

RUNTIME_ID="$(xcrun simctl list runtimes -j | python3 -c '
import json, re, sys
payload = json.load(sys.stdin)
runtimes = [r for r in payload.get("runtimes", []) if r.get("isAvailable") and ".iOS-" in r.get("identifier", "")]
if not runtimes:
    raise SystemExit("No available iOS simulator runtime")
def key(item):
    version = item.get("version", "0")
    return tuple(int(part) for part in re.findall(r"\d+", version))
print(max(runtimes, key=key)["identifier"])
')"

TYPES_LINE="$(xcrun simctl list devicetypes -j | python3 -c '
import json, re, sys
items = [d for d in json.load(sys.stdin).get("devicetypes", []) if d.get("identifier")]

def choose(preferred, pattern):
    by_name = {d.get("name", ""): d["identifier"] for d in items}
    for name in preferred:
        if name in by_name:
            return by_name[name]
    matches = [d for d in items if re.search(pattern, d.get("name", ""), re.I)]
    if not matches:
        raise SystemExit(f"No simulator device type matching {pattern}")
    return matches[-1]["identifier"]

print(choose(
    ["iPhone 16 Pro", "iPhone 16", "iPhone 15 Pro", "iPhone 15"],
    r"^iPhone (?!SE)"
))
print(choose(
    ["iPad Pro 13-inch (M4)", "iPad Pro (13-inch) (M4)", "iPad Pro 12.9-inch (6th generation)", "iPad Air 13-inch (M2)"],
    r"^iPad"
))
')"

# bash 3.2 (macOS/GitHub runners) has no readarray; parse a single line instead.
DEVICE_TYPES=($TYPES_LINE)
IPHONE_TYPE="${DEVICE_TYPES[0]:-}"
IPAD_TYPE="${DEVICE_TYPES[1]:-}"
IPHONE_UDID=""
IPAD_UDID=""

cleanup() {
  for udid in "$IPHONE_UDID" "$IPAD_UDID"; do
    if [[ -n "$udid" ]]; then
      xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
      xcrun simctl delete "$udid" >/dev/null 2>&1 || true
    fi
  done
}
trap cleanup EXIT

launch_and_capture() {
  local label="$1"
  local device_type="$2"
  local output="$3"
  local udid

  udid="$(xcrun simctl create "PipCount-${label}-${GITHUB_RUN_ID:-local}" "$device_type" "$RUNTIME_ID")"
  if [[ "$label" == "iPhone" ]]; then
    IPHONE_UDID="$udid"
  else
    IPAD_UDID="$udid"
  fi

  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl ui "$udid" appearance light
  xcrun simctl install "$udid" "$APP_PATH"
  xcrun simctl launch "$udid" "$BUNDLE_ID" -in-memory-store
  sleep 7
  xcrun simctl io "$udid" screenshot "$output"

  if [[ ! -s "$output" ]]; then
    echo "$label screenshot was not produced" >&2
    exit 1
  fi
}

launch_and_capture "iPhone" "$IPHONE_TYPE" "$EVIDENCE_DIR/iphone-home-light.png"
launch_and_capture "iPad" "$IPAD_TYPE" "$EVIDENCE_DIR/ipad-home-light.png"

echo "Universal light-mode simulator smoke test passed."
echo "Evidence: $EVIDENCE_DIR/iphone-home-light.png"
echo "Evidence: $EVIDENCE_DIR/ipad-home-light.png"
