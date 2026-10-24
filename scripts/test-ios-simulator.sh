#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
printf '[iOS smoke] Selected simulator SDK: %s\n' "$sdk_version"
simulator="$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys

def version_tuple(value):
    parts = list(map(int, re.findall(r"\d+", value)))
    return tuple((parts + [0, 0, 0])[:3])

sdk_version = version_tuple(sys.argv[1])
devices = []
for runtime, entries in json.load(sys.stdin)["devices"].items():
    if ".iOS-" not in runtime:
        continue
    version = version_tuple(runtime.split(".iOS-", 1)[1])
    if version < (17, 0, 0) or version > sdk_version:
        continue
    for device in entries:
        if device.get("isAvailable") and "iPhone" in device.get("name", ""):
            devices.append((device["state"] == "Booted", version, runtime, device["udid"], device["state"]))
if not devices:
    raise SystemExit(f"An available iPhone simulator between iOS 17 and SDK {sys.argv[1]} is required.")
_, _, runtime, udid, state = max(devices)
print(runtime, udid, state)
' "$sdk_version")"
read -r simulator_runtime simulator_udid simulator_state <<< "$simulator"
printf '[iOS smoke] Runtime: %s; UDID: %s; state: %s\n' "$simulator_runtime" "$simulator_udid" "$simulator_state"
started_simulator=false
cleanup() {
  if [[ "$started_simulator" == true ]]; then
    xcrun simctl shutdown "$simulator_udid" || true
  fi
}
trap cleanup EXIT
if [[ "$simulator_state" != Booted ]]; then
  printf '[iOS smoke] Booting simulator\n'
  xcrun simctl boot "$simulator_udid"
  started_simulator=true
fi
printf '[iOS smoke] Waiting for boot readiness (180 seconds maximum)\n'
python3 - "$simulator_udid" <<'PY'
import subprocess
import sys

try:
    subprocess.run(["xcrun", "simctl", "bootstatus", sys.argv[1], "-b"], check=True, timeout=180)
except subprocess.TimeoutExpired:
    raise SystemExit("Simulator boot readiness timed out after 180 seconds.")
PY
printf '[iOS smoke] Running core integration test (5 minutes per test)\n'
flutter test integration_test/core_smoke_test.dart -d "$simulator_udid" --reporter expanded --timeout 5m
printf '[iOS smoke] Core integration test passed\n'
