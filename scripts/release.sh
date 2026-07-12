#!/usr/bin/env bash
#
# release.sh - build, code-sign, notarize, and staple the macOS ChiikawaPet app.
#
# Godot adaptation of the Yaha-Pet reference pipeline. The build step is a
# headless Godot export (no PyInstaller); everything downstream is the same
# inside-out signing + notarization flow.
#
# Requirements:
#   - Godot 4.4.1 editor at /Applications/Godot.app (or set GODOT=/path/to/Godot)
#     plus the matching 4.4.1 export templates installed.
#   - a "Developer ID Application" cert in your login keychain. This app ships
#     signed + notarized; there is NO ad-hoc fallback.
#   - a notarytool keychain profile (see NOTARY_PROFILE) created once with:
#       xcrun notarytool store-credentials "AC_NOTARY" \
#         --apple-id "<apple-id>" --team-id "<team-id>" --password "<app-specific-pw>"
#   - create-dmg (brew install create-dmg)
#
# The pipeline, in order:
#   preflight -> export -> sign -> local verify -> zip
#     -> notarize app -> staple app -> Gatekeeper gate
#     -> build dmg -> sign dmg -> notarize dmg -> staple dmg -> gate dmg
#
# Flags:
#   --dry-run   Do everything EXCEPT submit to Apple (no notarization, no
#               stapling, no notarized Gatekeeper gate). Good for a fast
#               local check that the export + signing are clean.
#   -h|--help   Show usage.
#
# Every step that costs an Apple round-trip prints a "APPLE ROUND-TRIP" banner.

set -euo pipefail

# ============================================================================
# CONFIG  - the only block you edit when copying this to another project.
# ============================================================================
APP_NAME="ChiikawaPet"              # base name, no extension
APP_BUNDLE="${APP_NAME}.app"        # the .app produced by the Godot export
BUNDLE_ID="me.sarakay.ChiikawaPet"  # must match application/bundle_identifier
PROJECT_DIR="recovered"             # Godot project (project.godot + export_presets.cfg)
EXPORT_PRESET="macOS"               # preset name inside export_presets.cfg
ENTITLEMENTS="entitlements.plist"   # hardened-runtime entitlements (repo root)
NOTARY_PROFILE="AC_NOTARY"          # notarytool keychain profile name
OUT_DIR="_build"                    # export output dir (gitignored)
DMG_BASENAME="${APP_NAME}"          # -> _build/ChiikawaPet.dmg

# Godot editor binary. Override with GODOT=/path/to/Godot if not in /Applications.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
GODOT_VERSION_EXPECT="4.4.1.stable" # warn (not fail) if the editor differs

# ============================================================================
# Below here is generic - you should not need to edit it per project.
# ============================================================================

# ---- logging helpers -------------------------------------------------------
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'
  YLW=$'\033[33m'; BLU=$'\033[34m'; RST=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GRN=""; YLW=""; BLU=""; RST=""
fi

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

# ---- args ------------------------------------------------------------------
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,31p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
      exit 0 ;;
    *) die "unknown argument: $arg (see --help)" ;;
  esac
done
[ "$DRY_RUN" -eq 1 ] && warn "DRY RUN - will export and sign locally but never contact Apple."

# ============================================================================
phase "1/8  Preflight"
# ============================================================================

# Run from repo root (parent of scripts/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"
log "repo root: $REPO_ROOT"

[ -f "$PROJECT_DIR/project.godot" ]       || die "project.godot not found in $PROJECT_DIR/"
[ -f "$PROJECT_DIR/export_presets.cfg" ]  || die "export_presets.cfg not found in $PROJECT_DIR/ (needed for --export-release)"
[ -f "$ENTITLEMENTS" ]                    || die "entitlements not found: $ENTITLEMENTS"

# Required tools.
for tool in codesign xcrun ditto spctl security /usr/libexec/PlistBuddy; do
  command -v "$tool" >/dev/null 2>&1 || [ -x "$tool" ] || die "missing required tool: $tool"
done
command -v create-dmg >/dev/null 2>&1 || die "create-dmg not found. Install with: brew install create-dmg"

# Godot editor.
[ -x "$GODOT" ] || die "Godot editor not found/executable at: $GODOT
   Install Godot 4.4.1 (macos.universal) into /Applications, or set GODOT=/path/to/Godot."
GODOT_VER="$("$GODOT" --version 2>/dev/null | head -1)"
log "godot: $GODOT_VER ($GODOT)"
case "$GODOT_VER" in
  "$GODOT_VERSION_EXPECT"*) : ;;
  *) warn "expected Godot $GODOT_VERSION_EXPECT, got '$GODOT_VER' - export may differ." ;;
esac

# Find the Developer ID Application identity. Match the human-readable name and
# extract the 40-char SHA-1 hash (unambiguous even with multiple certs).
# This app SHIPS signed + notarized: a missing cert is a hard failure.
identity_line="$(security find-identity -v -p codesigning \
  | grep 'Developer ID Application' | head -1 || true)"
[ -n "$identity_line" ] || die \
  "No 'Developer ID Application' certificate found in the keychain.
   This app ships signed + notarized - there is no ad-hoc fallback.
   Get one from https://developer.apple.com (Certificates -> Developer ID Application),
   download the .cer, double-click to install into your login keychain, and re-run.
   (\`security find-identity -v -p codesigning\` should then list it.)"

SIGN_ID="$(printf '%s' "$identity_line" | awk '{print $2}')"
SIGN_NAME="$(printf '%s' "$identity_line" | sed -E 's/^[^"]*"([^"]+)".*/\1/')"
ok "signing identity: $SIGN_NAME"
log "identity hash:   $SIGN_ID"

# ============================================================================
phase "2/8  Export (godot --headless --export-release)"
# ============================================================================
APP_PATH="$REPO_ROOT/$OUT_DIR/$APP_BUNDLE"
mkdir -p "$OUT_DIR"
# Clean any previous bundle so a failed export can't leave a stale .app behind
# (Godot's headless exporter can print errors but still exit 0).
rm -rf "$APP_PATH"

log "importing resources..."
"$GODOT" --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1 || true

log "exporting release build..."
export_log="$(mktemp)"
trap 'rm -f "$export_log"' EXIT
"$GODOT" --headless --path "$PROJECT_DIR" \
  --export-release "$EXPORT_PRESET" "$APP_PATH" 2>&1 | tee "$export_log"

if grep -qiE 'export .*(failed|error)|configuration errors' "$export_log" || [ ! -d "$APP_PATH" ]; then
  die "Godot export failed (see output above). No signed build produced."
fi

# Single source of truth for the version: read it back out of the built app.
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' \
  "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo '0.0.0')"
# Sanity: the bundle id in the exported app must match what we expect to sign.
GOT_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' \
  "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo '')"
[ "$GOT_ID" = "$BUNDLE_ID" ] || die "exported bundle id '$GOT_ID' != expected '$BUNDLE_ID' (check export_presets.cfg)"
ok "exported $APP_PATH (version $VERSION, id $GOT_ID)"

# ============================================================================
phase "3/8  Sign"
# ============================================================================
# A Godot export bundles a single universal Mach-O (Contents/MacOS/$APP_NAME)
# and no nested frameworks/dylibs. We still scan for nested Mach-O so this stays
# correct if a future build bundles ANGLE/GDExtension libs: sign the DEEPEST
# code first (no entitlements) and the .app bundle LAST (with entitlements), so
# each container seals contents that are already validly signed. We do NOT use
# --deep (deprecated; silently skips nested code).
#
# Flags on every codesign call:
#   --force            re-sign over Godot's export-time ad-hoc signature
#   --options runtime  enable the hardened runtime (required to notarize)
#   --timestamp        secure timestamp from Apple's TSA (required to notarize)

MAIN_EXE="$APP_PATH/Contents/MacOS/$APP_NAME"

# --- 3a: nested Mach-O (dylibs, .so, helper binaries), excluding the main exe -
inner_count=0
while IFS= read -r -d '' f; do
  [ "$f" = "$MAIN_EXE" ] && continue
  if file -b "$f" 2>/dev/null | grep -q 'Mach-O'; then
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$f"
    inner_count=$((inner_count + 1))
  fi
done < <(find "$APP_PATH" -type f -print0)
ok "signed $inner_count nested Mach-O binaries"

# --- 3b: framework bundles, deepest first (usually none for Godot) ----------
fw_count=0
while IFS= read -r -d '' fw; do
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$fw"
  fw_count=$((fw_count + 1))
done < <(find "$APP_PATH" -name '*.framework' -type d -print0 \
         | awk -F/ '{print NF"\t"$0}' | sort -rn | cut -f2- | tr '\n' '\0')
ok "signed $fw_count framework bundles"

# --- 3c: the .app bundle itself, LAST, WITH entitlements --------------------
log "signing the app bundle with hardened runtime + entitlements"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_ID" "$APP_PATH"
ok "signed $APP_BUNDLE"

# ============================================================================
phase "4/8  Local verification (before spending an Apple round-trip)"
# ============================================================================
codesign --verify --deep --strict --verbose=2 "$APP_PATH" \
  || die "local codesign verification failed - fix before notarizing"
ok "codesign --verify --deep --strict passed"

# team id should now be set (not 'not set'), and it should NOT be ad-hoc.
codesign -dvv "$APP_PATH" 2>&1 | grep -E 'Identifier|TeamIdentifier|Authority|flags' | sed 's/^/    /' || true

# ============================================================================
phase "5/8  Package (ditto zip for notarization)"
# ============================================================================
# ditto -c -k --keepParent preserves symlinks, resource forks, and signatures.
# Plain `zip` breaks signatures - never use it for a signed .app.
ZIP_PATH="$OUT_DIR/${APP_NAME}-${VERSION}.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
ok "wrote $ZIP_PATH"

# ---------------------------------------------------------------------------
# notarize(): submit a file, wait, and on failure auto-dump Apple's log.
# ---------------------------------------------------------------------------
notarize() {
  local file="$1" label="$2"
  roundtrip_banner "notarize $label"
  log "submitting $file to Apple notary service (this can take 1-5 min)..."

  local out submission status
  out="$(xcrun notarytool submit "$file" \
          --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)"
  printf '%s\n' "$out"

  submission="$(printf '%s\n' "$out" | awk '/id:/ {print $2; exit}')"
  status="$(printf '%s\n' "$out" | awk -F': *' '/status:/ {print $2}' | tail -1)"

  if [ "$status" = "Accepted" ]; then
    ok "notarization ACCEPTED ($label, id $submission)"
    return 0
  fi

  warn "notarization NOT accepted (status: ${status:-unknown}). Fetching Apple's log..."
  if [ -n "$submission" ]; then
    xcrun notarytool log "$submission" --keychain-profile "$NOTARY_PROFILE" || true
  else
    warn "could not parse a submission id from the output above."
  fi
  return 1
}

# ============================================================================
phase "6/8  Notarize + staple the app"
# ============================================================================
if [ "$DRY_RUN" -eq 1 ]; then
  warn "[dry-run] skipping app notarization, stapling, and notarized gate."
else
  notarize "$ZIP_PATH" "app" || die "app notarization failed (see Apple log above)."

  log "stapling the notarization ticket into the .app..."
  xcrun stapler staple "$APP_PATH" || die "stapler failed for the app"
  ok "stapled $APP_BUNDLE"

  log "Gatekeeper assessment (spctl -a -t exec) ..."
  app_assess="$(spctl -a -t exec -vvv "$APP_PATH" 2>&1 || true)"
  printf '%s\n' "$app_assess" | sed 's/^/    /'
  if printf '%s\n' "$app_assess" | grep -q 'source=Notarized Developer ID'; then
    ok "app accepted by Gatekeeper as Notarized Developer ID"
  else
    die "app did NOT pass the notarized Gatekeeper gate"
  fi
fi

# ============================================================================
phase "7/8  Build + sign the DMG"
# ============================================================================
DMG_PATH="$OUT_DIR/${DMG_BASENAME}.dmg"
rm -f "$DMG_PATH"

# Stage just the .app so the DMG contains exactly one item + the /Applications link.
STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"; rm -f "$export_log"' EXIT
cp -R "$APP_PATH" "$STAGE_DIR/"

log "building DMG with create-dmg..."
create-dmg \
  --volname "$APP_NAME" \
  --app-drop-link 480 170 \
  --icon "$APP_BUNDLE" 160 170 \
  --window-size 640 360 \
  --hide-extension "$APP_BUNDLE" \
  --no-internet-enable \
  "$DMG_PATH" "$STAGE_DIR" \
  || die "create-dmg failed"
ok "built $DMG_PATH"

# A disk image is not executable code: Developer ID signature only, no runtime.
codesign --force --timestamp --sign "$SIGN_ID" "$DMG_PATH"
ok "signed the DMG"

# ============================================================================
phase "8/8  Notarize + staple the DMG"
# ============================================================================
if [ "$DRY_RUN" -eq 1 ]; then
  warn "[dry-run] skipping DMG notarization, stapling, and gate."
  warn "[dry-run] complete. Nothing was sent to Apple. Artifacts:"
  log  "  app: $APP_PATH (signed, hardened runtime, NOT notarized)"
  log  "  dmg: $DMG_PATH (signed, NOT notarized)"
  exit 0
fi

notarize "$DMG_PATH" "dmg" || die "DMG notarization failed (see Apple log above)."

log "stapling the notarization ticket into the DMG..."
xcrun stapler staple "$DMG_PATH" || die "stapler failed for the DMG"
ok "stapled the DMG"

log "Gatekeeper assessment of the DMG (spctl -a -t install) ..."
dmg_assess="$(spctl -a -t install -vvv "$DMG_PATH" 2>&1 || true)"
printf '%s\n' "$dmg_assess" | sed 's/^/    /'
if printf '%s\n' "$dmg_assess" | grep -q 'source=Notarized Developer ID'; then
  ok "DMG accepted by Gatekeeper as Notarized Developer ID"
else
  die "DMG did NOT pass the notarized Gatekeeper gate"
fi

printf '\n%sRelease complete.%s\n' "$BOLD$GRN" "$RST"
log "Ship this: $DMG_PATH"
log "Users can download, open, and drag to Applications with no Gatekeeper warning."
