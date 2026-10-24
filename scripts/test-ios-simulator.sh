#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

simulator="$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
devices = []
for runtime, entries in json.load(sys.stdin)["devices"].items():
    if ".iOS-" not in runtime:
        continue
    version = tuple(map(int, re.findall(r"\d+", runtime.split(".iOS-", 1)[1])))
    for device in entries:
        if device.get("isAvailable") and "iPhone" in device.get("name", ""):
            devices.append((device["state"] == "Booted", version, device["udid"], device["state"]))
if not devices:
    raise SystemExit("An available iPhone simulator is required.")
_, _, udid, state = max(devices)
print(udid, state)
')"
read -r simulator_udid simulator_state <<< "$simulator"
started_simulator=false
cleanup() {
  if [[ "$started_simulator" == true ]]; then
    xcrun simctl shutdown "$simulator_udid" || true
  fi
}
trap cleanup EXIT
if [[ "$simulator_state" != Booted ]]; then
  xcrun simctl boot "$simulator_udid"
  started_simulator=true
fi
xcrun simctl bootstatus "$simulator_udid" -b
flutter test integration_test/core_smoke_test.dart -d "$simulator_udid" --reporter expanded
