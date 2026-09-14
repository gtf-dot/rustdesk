#!/bin/bash
# Sign, package, notarize and staple the macOS build produced by ./build_mac.sh.
#
# One-time setup:
#   1. A "Developer ID Application" certificate in the login keychain (already present on this Mac).
#      Override the identity with MACOS_CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)".
#   2. Notarization credentials stored once in the keychain (never in the repo):
#        xcrun notarytool store-credentials "$NOTARY_PROFILE" \
#            --apple-id you@example.com --team-id N7SSWAJRWE --password <app-specific-password>
#      (or --key AuthKey.p8 --key-id KEYID --issuer ISSUER-UUID for an App Store Connect API key)
#
# Usage: ./sign_mac.sh [path/to/App.app]     (defaults to the app in flutter/build/.../Release)
#   SKIP_NOTARIZE=1 ./sign_mac.sh            sign and build the dmg only
set -euo pipefail
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:$PATH"

APP="${1:-$(ls -d flutter/build/macos/Build/Products/Release/*.app | grep -v '\.dSYM$' | head -1)}"
[ -d "$APP" ] || { echo "app bundle not found: $APP" >&2; exit 1; }
NAME="$(basename "$APP" .app)"
VERSION="$(grep -m1 '^version' Cargo.toml | sed -E 's/.*"([^"]+)".*/\1/')"
DMG="${NAME}-${VERSION}.dmg"
ENTITLEMENTS="flutter/macos/Runner/Release.entitlements"
NOTARY_PROFILE="${NOTARY_PROFILE:-horusrd-notary}"

if [ -z "${MACOS_CODESIGN_IDENTITY:-}" ]; then
    MACOS_CODESIGN_IDENTITY="$(security find-identity -v -p codesigning | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')"
fi
[ -n "$MACOS_CODESIGN_IDENTITY" ] || { echo "no Developer ID Application identity in the keychain" >&2; exit 1; }
echo "==> identity: $MACOS_CODESIGN_IDENTITY"

SIGN=(codesign --force --options runtime --timestamp -s "$MACOS_CODESIGN_IDENTITY")

# Sign inside-out: every nested Mach-O first (frameworks, dylibs, helper binaries), then the bundle.
# --deep is avoided on purpose: it would stamp the app's entitlements onto every library.
echo "==> signing nested code"
find "$APP/Contents/Frameworks" -type d -name "*.framework" -maxdepth 1 | while read -r fw; do
    "${SIGN[@]}" "$fw"
done
find "$APP/Contents" \( -name "*.dylib" -o -name "*.so" \) -type f | while read -r lib; do
    "${SIGN[@]}" "$lib"
done
find "$APP/Contents/MacOS" -type f -perm -u+x ! -name "$NAME" | while read -r bin; do
    "${SIGN[@]}" "$bin"
done

echo "==> signing $APP"
"${SIGN[@]}" --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> building $DMG"
rm -f "$DMG"
# Background drawn by res/gen_dmg_background.swift; its arrow sits between the two icon positions below.
DMG_OPTS=(--volname "$NAME Installer" --window-pos 200 120 --window-size 800 400 --icon-size 100
    --background res/dmg-background.png --volicon res/dmg-volume.icns
    --icon "$NAME.app" 200 190 --hide-extension "$NAME.app" --app-drop-link 600 185)
# The Finder-layout AppleScript times out without a GUI session (ssh, agents); fall back to a plain layout.
if ! create-dmg "${DMG_OPTS[@]}" "$DMG" "$APP"; then
    echo "==> create-dmg Finder layout failed, retrying with --skip-jenkins"
    rm -f "$DMG" rw.*.dmg
    create-dmg "${DMG_OPTS[@]}" --skip-jenkins "$DMG" "$APP"
fi
"${SIGN[@]}" "$DMG"
codesign --verify --strict "$DMG"

if [ -n "${SKIP_NOTARIZE:-}" ]; then
    echo "Signed (not notarized): $DMG"
    exit 0
fi

echo "==> notarizing with keychain profile '$NOTARY_PROFILE'"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler staple "$APP"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
echo "Signed, notarized and stapled: $DMG"
