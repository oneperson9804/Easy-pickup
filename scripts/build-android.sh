#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
signing_env="${EASY_PICKUP_SIGNING_ENV:-${XDG_DATA_HOME:-$HOME/.local/share}/easy-pickup-signing/signing.env}"
if [[ ! -f "$signing_env" ]]; then
  printf 'Release signing is not configured. Run scripts/create-local-signing.sh first.\n' >&2
  exit 1
fi
source "$signing_env"
flutter pub get
flutter build apk --release --split-per-abi
printf 'Signed APKs: build/app/outputs/flutter-apk/\n'
