#!/usr/bin/env bash
set -euo pipefail
# This helper stores release credentials outside the checkout and never prints them.
signing_dir="${XDG_DATA_HOME:-$HOME/.local/share}/easy-pickup-signing"
mkdir -p "$signing_dir"
chmod 700 "$signing_dir"
if [[ -f "$signing_dir/signing.env" ]]; then
  printf 'Signing configuration already exists: %s/signing.env\n' "$signing_dir"
  exit 0
fi
umask 077
store_password=$(openssl rand -hex 32)
cat > "$signing_dir/signing.env" <<EOF
export EASY_PICKUP_KEYSTORE_PATH='$signing_dir/release.jks'
export EASY_PICKUP_KEY_ALIAS='easy-pickup'
export EASY_PICKUP_STORE_PASSWORD='$store_password'
export EASY_PICKUP_KEY_PASSWORD='$store_password'
EOF
source "$signing_dir/signing.env"
keytool -genkeypair -keystore "$EASY_PICKUP_KEYSTORE_PATH" -alias "$EASY_PICKUP_KEY_ALIAS" \
  -storepass:env EASY_PICKUP_STORE_PASSWORD -keypass:env EASY_PICKUP_KEY_PASSWORD \
  -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Easy Pickup, OU=Open Source, O=Easy Pickup'
printf 'Created signing configuration outside repository: %s/signing.env\n' "$signing_dir"
