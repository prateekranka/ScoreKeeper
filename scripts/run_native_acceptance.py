import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "scripts" / "simslim-acceptance.json"


def execute(command, env=None, capture=False, check=True, timeout=600):
    print("+ " + " ".join(map(str, command)), flush=True)
    result = subprocess.run(command, cwd=ROOT, env=env, text=True,
                            capture_output=capture, timeout=timeout)
    if check and result.returncode:
        if capture:
            sys.stderr.write(result.stderr)
        raise RuntimeError(f"Command failed with exit {result.returncode}: {command[0]}")
    return result


def payload(command):
    return json.loads(execute(command, capture=True).stdout)


def booted_devices(simslim):
    return payload([simslim, "list", "--booted", "--json"])


def choose_device(kind):
    types = payload(["xcrun", "simctl", "list", "devicetypes", "-j"])["devicetypes"]
    runtimes = payload(["xcrun", "simctl", "list", "runtimes", "-j"])["runtimes"]
    available = [r for r in runtimes if r.get("isAvailable") and ".iOS-" in r["identifier"]]
    if not available:
        raise RuntimeError("No available iOS runtime")
    runtime = max(available, key=lambda r: tuple(int(p) for p in r["version"].split(".")))
    prefix = "iPad" if kind == "ipad" else "iPhone"
    candidates = [t for t in types if t["name"].startswith(prefix) and "Duo" not in t["name"]]
    if not candidates:
        raise RuntimeError(f"No available {kind} device type")
    preferred = ["iPhone 16 Pro", "iPhone 17 Pro", "iPhone 18 Pro"] if kind == "iphone" else [
        "iPad Pro 11-inch (M4)", "iPad Pro 11-inch (M5)", "iPad Air 11-inch (M3)"]
    device_type = next((t for name in preferred for t in candidates if t["name"] == name), candidates[0])
    identifier = execute(["xcrun", "simctl", "create", f"PipCount-{kind}-{uuid.uuid4().hex[:8]}",
                          device_type["identifier"], runtime["identifier"]], capture=True).stdout.strip()
    return identifier


def validate_report(path):
    report = json.loads(path.read_text())["run"]
    counts = report["summary"]
    if report["exitCode"] or report.get("errors") or counts["passed"] != counts["selected"] or not counts["selected"]:
        raise RuntimeError(f"Acceptance did not pass every selected case: {path}")
    for result in report["results"]:
        for attempt in result["attempts"]:
            if attempt.get("secondaryErrors") or attempt.get("cleanup") != "complete":
                raise RuntimeError(f"Acceptance cleanup was incomplete: {path}")
    return counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--devices", default="iphone,ipad")
    parser.add_argument("--udid")
    parser.add_argument("--app", default=os.environ.get("PIPCOUNT_APP"))
    parser.add_argument("--output", default=".e2e-native-acceptance")
    parser.add_argument("--files", nargs="+", default=["tests/paywall.e2e.ts", "tests/native-release-smoke.e2e.ts", "tests/native-glass-rotation.e2e.ts"])
    parser.add_argument("--video", action="store_true")
    parser.add_argument("--allow-fold", action="store_true")
    parser.add_argument("--grep")
    args = parser.parse_args()
    simslim = shutil.which("simslim")
    if not simslim:
        raise RuntimeError("Install SimSlim before running native acceptance")
    app = Path(args.app or ROOT / ".build/DerivedData/Build/Products/Debug-iphonesimulator/ScoreKeeper.app").resolve()
    if not app.is_dir():
        raise RuntimeError(f"Built app is missing: {app}")
    output = (ROOT / args.output).resolve()
    if not output.is_relative_to(ROOT) or output == ROOT:
        raise RuntimeError("Acceptance output must be inside this worktree")
    if output.exists():
        raise RuntimeError("Use a new output directory to preserve earlier acceptance evidence")
    output.mkdir(parents=True)
    kinds = ["selected"] if args.udid else args.devices.split(",")
    if any(kind not in {"iphone", "ipad", "selected"} for kind in kinds):
        raise RuntimeError("Supported device kinds are iphone and ipad")
    results = []
    try:
        for kind in kinds:
            running = booted_devices(simslim)
            if any(d["udid"] != args.udid for d in running):
                raise RuntimeError("Another simulator is running; leave it unchanged and close it before this run")
            identifier = args.udid or choose_device(kind)
            started_here = not any(d["udid"] == identifier for d in running)
            case_output = output / kind
            case_output.mkdir()
            try:
                match = execute([simslim, "verify", identifier, "--profile", str(PROFILE)], capture=True, check=False) if not started_here else None
                if match is None or match.returncode:
                    execute([simslim, "on", identifier, "--profile", str(PROFILE)])
                execute([simslim, "verify", identifier, "--profile", str(PROFILE)])
                execute([simslim, "doctor", identifier, "--requires", "storekit,push,siri,icloud,keychain-sync,universal-links"])
                active = booted_devices(simslim)
                if len(active) != 1 or active[0]["udid"] != identifier:
                    raise RuntimeError("The acceptance run must have exactly its selected simulator booted")
                env = os.environ.copy()
                env.update({
                    "DO_NOT_TRACK": "1",
                    "PIPCOUNT_DEVICE": identifier,
                    "PIPCOUNT_SESSION": f"pipcount-{kind}-{uuid.uuid4().hex[:8]}",
                    "PIPCOUNT_APP": str(app),
                    "PIPCOUNT_NO_FOLD": "1",
                    "PIPCOUNT_JOURNEY_MANIFEST": str(case_output / "manifest.jsonl"),
                    "AGENT_DEVICE_STATE_DIR": str(case_output / "driver-state"),
                })
                if args.allow_fold:
                    env.pop("PIPCOUNT_NO_FOLD", None)
                command = ["npx", "--no-install", "e2e", "run", *args.files, "--target", "ios",
                           "--output", str(case_output.relative_to(ROOT)), "--reporter", "list,markdown",
                           "--trace", "retain-on-failure", "--max-failures", "1"]
                if args.video:
                    command.extend(["--video", "on"])
                if args.grep:
                    command.extend(["--grep", args.grep])
                outcome = execute(command, env=env, check=False, timeout=1800)
                if outcome.returncode:
                    raise RuntimeError(f"TesterArmy failed for {identifier}; inspect {case_output}")
                counts = validate_report(case_output / "report.json")
            finally:
                if (case_output / "driver-state" / "daemon.json").exists():
                    execute(["npx", "--no-install", "agent-device", "daemon", "stop", "--state-dir",
                             str(case_output / "driver-state"), "--clean"], timeout=120)
                if started_here:
                    execute([simslim, "shutdown", identifier], timeout=120)
                    if any(d["udid"] == identifier for d in booted_devices(simslim)):
                        raise RuntimeError("The acceptance simulator did not shut down")
            results.append({"device": kind, "udid": identifier, "summary": counts, "driverCleanup": "complete"})
    finally:
        (output / "matrix.json").write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps({"passed": results}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
