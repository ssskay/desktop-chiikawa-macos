#!/usr/bin/env bash
#
# release.sh - build the macOS ChiikawaPet app, then produce a signed, notarized,
# stapled DMG for EACH architecture (Apple Silicon + Intel).
#
# Godot ships a universal export template only, so single-arch `--export-release`
# isn't available. Instead we export the universal build once and `lipo -thin`
# a copy down to each architecture, then sign + notarize each independently.
# Everything downstream is the proven Yaha-Pet inside-out signing flow.
#
# Requirements:
#   - Godot 4.4.1 at /Applications/Godot.app (or GODOT=/path/to/Godot) + templates.
#   - a "Developer ID Application" cert in the login keychain (no ad-hoc fallback).
#   - a notarytool keychain profile (NOTARY_PROFILE), created once with
#       xcrun notarytool store-credentials "AC_NOTARY" --apple-id ... --team-id ... --password ...
#   - create-dmg (brew install create-dmg)
#
# Per architecture: thin -> sign -> verify -> zip -> notarize+staple app -> gate
#   -> build dmg -> sign dmg -> notarize+staple dmg -> gate dmg
#
# Flags:  --dry-run  (build + sign locally, never contact Apple)   -h|--help

set -euo pipefail

# ============================================================================
# CONFIG
# ============================================================================
APP_NAME="ChiikawaPet"
APP_BUNDLE="${APP_NAME}.app"
BUNDLE_ID="me.sarakay.ChiikawaPet"
PROJECT_DIR="recovered"
EXPORT_PRESET="macOS"               # the single universal preset
ENTITLEMENTS="entitlements.plist"
NOTARY_PROFILE="AC_NOTARY"
OUT_DIR="_build"

# One line per architecture:  lipo_arch | subdir | dmg_basename
ARCHES=(
  "arm64|arm64|ChiikawaPet-AppleSilicon"
  "x86_64|intel|ChiikawaPet-Intel"
)

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
GODOT_VERSION_EXPECT="4.4.1.stable"

# ============================================================================
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'
  YLW=$'\033[33m'; BLU=$'\033[34m'; RST=$'\033[0m'
else BOLD=""; DIM=""; RED=""; GRN=""; YLW=""; BLU=""; RST=""; fi
phase() { printf '\n%s== %s ==%s\n' "$BOLD$BLU" "$1" "$RST"; }
log()   { printf '%s*%s %s\n' "$DIM" "$RST" "$1"; }
ok()    { printf '%s+%s %s\n' "$GRN" "$RST" "$1"; }
warn()  { printf '%s! %s%s\n' "$YLW" "$1" "$RST"; }
die()   { printf '%sx %s%s\n' "$RED" "$1" "$RST" >&2; exit 1; }
roundtrip_banner() {
  printf '\n%s+--------------------------------------------+%s\n' "$YLW" "$RST"
  printf '%s|  APPLE ROUND-TRIP: %-23s |%s\n' "$YLW" "$1" "$RST"
  printf '%s+--------------------------------------------+%s\n' "$YLW" "$RST"
}

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,29p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $arg (see --help)" ;;
  esac
done
[ "$DRY_RUN" -eq 1 ] && warn "DRY RUN - build and sign locally but never contact Apple."

# ============================================================================
phase "Preflight"
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"
log "repo root: $REPO_ROOT"

[ -f "$PROJECT_DIR/project.godot" ]      || die "project.godot not found in $PROJECT_DIR/"
[ -f "$PROJECT_DIR/export_presets.cfg" ] || die "export_presets.cfg not found in $PROJECT_DIR/"
[ -f "$ENTITLEMENTS" ]                   || die "entitlements not found: $ENTITLEMENTS"
for tool in codesign xcrun ditto spctl security lipo /usr/libexec/PlistBuddy; do
  command -v "$tool" >/dev/null 2>&1 || [ -x "$tool" ] || die "missing required tool: $tool"
done
command -v create-dmg >/dev/null 2>&1 || die "create-dmg not found. Install: brew install create-dmg"
[ -x "$GODOT" ] || die "Godot not found/executable at: $GODOT (set GODOT=/path/to/Godot)"
GODOT_VER="$("$GODOT" --version 2>/dev/null | head -1)"
log "godot: $GODOT_VER"
case "$GODOT_VER" in "$GODOT_VERSION_EXPECT"*) : ;; *) warn "expected Godot $GODOT_VERSION_EXPECT, got '$GODOT_VER'." ;; esac

identity_line="$(security find-identity -v -p codesigning | grep 'Developer ID Application' | head -1 || true)"
[ -n "$identity_line" ] || die \
  "No 'Developer ID Application' certificate found in the keychain.
   This app ships signed + notarized - there is no ad-hoc fallback."
SIGN_ID="$(printf '%s' "$identity_line" | awk '{print $2}')"
SIGN_NAME="$(printf '%s' "$identity_line" | sed -E 's/^[^"]*"([^"]+)".*/\1/')"
ok "signing identity: $SIGN_NAME"

# ============================================================================
phase "Export (universal, once)"
# ============================================================================
UNIVERSAL="$REPO_ROOT/$OUT_DIR/universal/$APP_BUNDLE"
mkdir -p "$OUT_DIR/universal"
rm -rf "$UNIVERSAL"
"$GODOT" --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1 || true
export_log="$(mktemp)"
"$GODOT" --headless --path "$PROJECT_DIR" \
  --export-release "$EXPORT_PRESET" "$UNIVERSAL" 2>&1 | tee "$export_log" | grep -E '^export:|ERROR' || true
if grep -qiE 'export .*(failed|error)|configuration errors' "$export_log" || [ ! -d "$UNIVERSAL" ]; then
  rm -f "$export_log"; die "Godot universal export failed (see above)."
fi
rm -f "$export_log"
got_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$UNIVERSAL/Contents/Info.plist" 2>/dev/null || echo '')"
[ "$got_id" = "$BUNDLE_ID" ] || die "exported bundle id '$got_id' != '$BUNDLE_ID'"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$UNIVERSAL/Contents/Info.plist" 2>/dev/null || echo '0.0.0')"
ok "exported universal $APP_BUNDLE (v$VERSION): $(lipo -archs "$UNIVERSAL/Contents/MacOS/$APP_NAME" | xargs)"

# ---------------------------------------------------------------------------
notarize() {
  local file="$1" label="$2"
  roundtrip_banner "notarize $label"
  log "submitting $file (1-5 min)..."
  local out submission status
  out="$(xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)"
  printf '%s\n' "$out"
  submission="$(printf '%s\n' "$out" | awk '/id:/ {print $2; exit}')"
  status="$(printf '%s\n' "$out" | awk -F': *' '/status:/ {print $2}' | tail -1)"
  if [ "$status" = "Accepted" ]; then ok "notarization ACCEPTED ($label, id $submission)"; return 0; fi
  warn "notarization NOT accepted (status: ${status:-unknown}). Apple log:"
  [ -n "$submission" ] && xcrun notarytool log "$submission" --keychain-profile "$NOTARY_PROFILE" || true
  return 1
}

# ---------------------------------------------------------------------------
# thin_and_ship ARCH SUBDIR DMG_BASE
# ---------------------------------------------------------------------------
thin_and_ship() {
  local arch="$1" subdir="$2" dmg_base="$3"
  local app_path="$REPO_ROOT/$OUT_DIR/$subdir/$APP_BUNDLE"

  phase "[$arch]  Thin"
  rm -rf "$REPO_ROOT/$OUT_DIR/$subdir"
  mkdir -p "$REPO_ROOT/$OUT_DIR/$subdir"
  cp -R "$UNIVERSAL" "$app_path"
  local exe="$app_path/Contents/MacOS/$APP_NAME"
  lipo "$exe" -thin "$arch" -output "$exe.thin" || die "lipo -thin $arch failed"
  mv "$exe.thin" "$exe"
  chmod +x "$exe"
  local have; have="$(lipo -archs "$exe" 2>/dev/null | xargs)"
  [ "$have" = "$arch" ] || die "expected only $arch, got '$have'"
  ok "thinned to $arch"

  phase "[$arch]  Sign"
  # Godot bundles no nested code; still scan for nested Mach-O to be safe.
  local inner=0
  while IFS= read -r -d '' f; do
    [ "$f" = "$exe" ] && continue
    if file -b "$f" 2>/dev/null | grep -q 'Mach-O'; then
      codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$f"; inner=$((inner+1))
    fi
  done < <(find "$app_path" -type f -print0)
  [ "$inner" -gt 0 ] && log "signed $inner nested Mach-O binaries"
  codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGN_ID" "$app_path"
  codesign --verify --deep --strict --verbose=2 "$app_path" || die "codesign verify failed for $arch"
  ok "signed + verified (hardened runtime)"

  phase "[$arch]  Notarize + staple app"
  local zip_path="$OUT_DIR/$subdir/${APP_NAME}-${VERSION}.zip"
  rm -f "$zip_path"
  ditto -c -k --keepParent "$app_path" "$zip_path"
  if [ "$DRY_RUN" -eq 1 ]; then
    warn "[dry-run] skipping app notarization/stapling/gate."
  else
    notarize "$zip_path" "$dmg_base app" || die "app notarization failed for $arch."
    xcrun stapler staple "$app_path" || die "stapler failed for $arch app"
    printf '%s\n' "$(spctl -a -t exec -vvv "$app_path" 2>&1 || true)" | grep -q 'source=Notarized Developer ID' \
      || die "$arch app did NOT pass Gatekeeper"
    ok "app notarized + stapled + Gatekeeper-accepted"
  fi

  phase "[$arch]  Build + notarize DMG"
  local dmg_path="$OUT_DIR/${dmg_base}.dmg"
  rm -f "$dmg_path"
  local stage; stage="$(mktemp -d)"
  cp -R "$app_path" "$stage/"
  # create-dmg drives Finder via AppleScript to lay out the window; that step is
  # flaky when two DMGs are built back-to-back. Clean stale mounts/temp images
  # and retry.
  local made=0 attempt dmg_log
  for attempt in 1 2 3; do
    rm -f "$dmg_path" "$OUT_DIR"/rw.*.dmg 2>/dev/null || true
    for v in /Volumes/dmg.*; do [ -d "$v" ] && hdiutil detach "$v" -force >/dev/null 2>&1 || true; done
    dmg_log="$(mktemp)"
    if create-dmg --volname "$dmg_base" --app-drop-link 480 170 --icon "$APP_BUNDLE" 160 170 \
        --window-size 640 360 --hide-extension "$APP_BUNDLE" --no-internet-enable \
        "$dmg_path" "$stage" >"$dmg_log" 2>&1 && [ -f "$dmg_path" ]; then
      made=1; rm -f "$dmg_log"; break
    fi
    warn "create-dmg attempt $attempt failed (Finder AppleScript); cleaning up and retrying..."
    tail -2 "$dmg_log" | sed 's/^/    /'; rm -f "$dmg_log"
    sleep 4
  done
  rm -rf "$stage"
  [ "$made" -eq 1 ] || die "create-dmg failed for $arch after 3 attempts"
  codesign --force --timestamp --sign "$SIGN_ID" "$dmg_path"
  ok "built + signed $dmg_path"
  if [ "$DRY_RUN" -eq 1 ]; then
    warn "[dry-run] skipping DMG notarization/stapling/gate."
  else
    notarize "$dmg_path" "$dmg_base dmg" || die "DMG notarization failed for $arch."
    xcrun stapler staple "$dmg_path" || die "stapler failed for $arch dmg"
    printf '%s\n' "$(spctl -a -t install -vvv "$dmg_path" 2>&1 || true)" | grep -q 'source=Notarized Developer ID' \
      || die "$arch DMG did NOT pass Gatekeeper"
    ok "DMG notarized + stapled + Gatekeeper-accepted"
  fi
  SHIPPED+=("$dmg_path")
}

# ============================================================================
SHIPPED=()
for entry in "${ARCHES[@]}"; do
  IFS='|' read -r arch subdir dmg_base <<< "$entry"
  thin_and_ship "$arch" "$subdir" "$dmg_base"
done

printf '\n%s%s complete.%s\n' "$BOLD$GRN" "$([ "$DRY_RUN" -eq 1 ] && echo 'Dry run' || echo 'Release')" "$RST"
for d in "${SHIPPED[@]}"; do log "  $d"; done
[ "$DRY_RUN" -eq 1 ] && warn "Nothing was sent to Apple." || log "Both DMGs are signed, notarized, and stapled - ship them."
