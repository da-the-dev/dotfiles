#!/usr/bin/env bash
# Build ZoomIt from my fork and install it as /Applications/ZoomIt.app (macOS only).
# Safe to re-run: skipped if the fork build is installed (UPDATE=1 to pull and rebuild).
set -euo pipefail

REPO="https://github.com/da-the-dev/Zoomit-Mac.git"
SRC="$HOME/.local/src/zoomit"
APP="/Applications/ZoomIt.app"
BUNDLE_ID="com.sysinternals.zoomitmac.dev" # not Microsoft's id, so permissions don't clash
UPDATE="${UPDATE:-0}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*" >&2; }

[ "$(uname -s)" = Darwin ] || { warn "ZoomIt is macOS only"; exit 1; }

if [ -e "$APP" ]; then
  installed="$(defaults read "$APP/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
  if [ "$installed" != "$BUNDLE_ID" ]; then
    warn "$APP isn't the fork build; remove it first (brew uninstall --cask zoomit) and re-run"
    exit 1
  fi
  if [ "$UPDATE" != 1 ]; then
    log "ZoomIt already installed (UPDATE=1 to rebuild)"
    exit 0
  fi
fi

xcrun --find swift >/dev/null 2>&1 || { warn "Swift not found; run: xcode-select --install"; exit 1; }

if [ -d "$SRC/.git" ]; then
  log "ZoomIt: updating $SRC"
  git -C "$SRC" fetch -q origin
  git -C "$SRC" switch -q main
  git -C "$SRC" merge -q --ff-only origin/main
else
  log "ZoomIt: cloning into $SRC"
  mkdir -p "$(dirname "$SRC")"
  git clone -q --branch main "$REPO" "$SRC"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "ZoomIt: building $(git -C "$SRC" rev-parse --short HEAD)"
ZOOMIT_DISPLAY_NAME=ZoomIt ZOOMIT_APP_NAME=ZoomIt.app ZOOMIT_BUNDLE_ID="$BUNDLE_ID" ZOOMIT_SIGN_IDENTITY=- \
  zsh "$SRC/Scripts/build-app.sh" release >"$tmp/build.log" 2>&1 ||
  { tail -30 "$tmp/build.log" >&2; exit 1; }
built="$SRC/.build/ZoomIt.app"

# macOS refuses to launch an ad-hoc signed app that claims the speech recognition
# entitlement, so sign again without it.
cp "$SRC/Scripts/ZoomIt.entitlements" "$tmp/entitlements"
/usr/libexec/PlistBuddy -c "Delete :com.apple.developer.speech-recognition" "$tmp/entitlements" 2>/dev/null || true
codesign --force --deep --sign - --entitlements "$tmp/entitlements" \
  --requirements "=designated => identifier \"$BUNDLE_ID\"" "$built"
codesign --verify --deep --strict "$built"

log "ZoomIt: installing $APP"
pkill -f "$APP/Contents/MacOS/ZoomIt" || true
rm -rf "$APP"
ditto "$built" "$APP"
open "$APP"
log "ZoomIt installed; if zoom doesn't work, allow it in System Settings > Privacy & Security > Screen Recording"
