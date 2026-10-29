#!/usr/bin/env bash
# Build Simple Note as a macOS .app bundle.
# Usage:  ./build.sh             — universal release build into build/Simple Note.app
#         ./build.sh --arm64     — single-arch (faster local builds)
#         ./build.sh --skip-fonts — don't try to fetch fonts (use whatever's on disk)
#
# License validation needs a Yard API key with the licenses:validate scope, read from
# $YARD_API_KEY or secrets.env (see secrets.env.example). Without one the app still
# builds and runs; it just can't verify license keys.
#
# Test build against a Yard sandbox (accepts that sandbox's simulated purchases only):
#         YARD_SANDBOX=Development ./build.sh --arm64
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SimpleNote"
DISPLAY_NAME="Simple Note"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/$DISPLAY_NAME.app"
FONTS_DIR="$ROOT/PackagingResources/Fonts"
PACKAGING_DIR="$ROOT/PackagingResources"

ARCHS=(arm64 x86_64)
SKIP_FONTS="0"
for arg in "$@"; do
  case "$arg" in
    --arm64) ARCHS=(arm64) ;;
    --x86_64) ARCHS=(x86_64) ;;
    --skip-fonts) SKIP_FONTS="1" ;;
    *) echo "[build.sh] unknown arg: $arg" >&2; exit 2 ;;
  esac
done

ARCH_FLAGS=()
for a in "${ARCHS[@]}"; do
  ARCH_FLAGS+=("--arch" "$a")
done

# ---------- 1. Fetch fonts ----------
fetch_font() {
  local url="$1"
  local out="$2"
  if [[ -s "$out" ]]; then return 0; fi
  echo "[fonts] fetching $(basename "$out")"
  if ! curl -fL --retry 3 --retry-delay 1 -o "$out.tmp" "$url"; then
    rm -f "$out.tmp"
    echo "[fonts] WARN: could not fetch $url — falling back to system font" >&2
    return 0
  fi
  mv "$out.tmp" "$out"
}

mkdir -p "$FONTS_DIR"

if [[ "$SKIP_FONTS" != "1" ]]; then
  # Onest ships as a single variable font in google/fonts. SwiftUI picks weights
  # via .fontWeight() when the family is registered.
  fetch_font "https://github.com/google/fonts/raw/main/ofl/onest/Onest%5Bwght%5D.ttf" "$FONTS_DIR/Onest.ttf"

  IS_BASE="https://github.com/google/fonts/raw/main/ofl/instrumentserif"
  fetch_font "$IS_BASE/InstrumentSerif-Regular.ttf" "$FONTS_DIR/InstrumentSerif-Regular.ttf"
  fetch_font "$IS_BASE/InstrumentSerif-Italic.ttf" "$FONTS_DIR/InstrumentSerif-Italic.ttf"

  JBM_BASE="https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/ttf"
  for w in Regular Medium; do
    fetch_font "$JBM_BASE/JetBrainsMono-$w.ttf" "$FONTS_DIR/JetBrainsMono-$w.ttf"
  done
fi

# ---------- 2. Compile (release, universal) ----------
echo "[build] swift build -c release ${ARCH_FLAGS[*]}"
cd "$ROOT"
swift build -c release "${ARCH_FLAGS[@]}"

BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
  echo "[build] FATAL: built binary not found at $BIN_PATH" >&2
  exit 1
fi

# ---------- 3. Assemble .app bundle ----------
echo "[bundle] assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources/Fonts"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# SwiftPM's link step records the deployment target as the SDK version. macOS uses the
# SDK version for linked-on-or-after behaviour, so stamp the SDK that was actually used.
MIN_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PACKAGING_DIR/Info.plist")"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
vtool -set-build-version macos "$MIN_OS" "$SDK_VERSION" -replace \
  -output "$APP_DIR/Contents/MacOS/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Fonts live in Contents/Resources/Fonts; AppKit registers them at launch via
# ATSApplicationFontsPath in Info.plist.
if [[ -d "$FONTS_DIR" ]] && compgen -G "$FONTS_DIR/*.ttf" > /dev/null; then
  cp -f "$FONTS_DIR"/*.ttf "$APP_DIR/Contents/Resources/Fonts/"
fi

# Asset catalog (the leaf-green AccentColor named by NSAccentColorName in Info.plist).
xcrun actool "$PACKAGING_DIR/Assets.xcassets" \
  --compile "$APP_DIR/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PACKAGING_DIR/Info.plist")" \
  --output-partial-info-plist "$BUILD_DIR/assets-info.plist" \
  --output-format human-readable-text --notices --warnings > /dev/null

# Info.plist, with the Yard API key injected when one is configured.
cp "$PACKAGING_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
if [[ -z "${YARD_API_KEY:-}" && -f "$ROOT/secrets.env" ]]; then
  YARD_API_KEY="$(sed -n 's/^YARD_API_KEY=//p' "$ROOT/secrets.env" | tr -d '[:space:]')"
fi
if [[ -n "${YARD_API_KEY:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Add :YardAPIKey string $YARD_API_KEY" "$APP_DIR/Contents/Info.plist"
  echo "[bundle] Yard API key injected"
else
  echo "[bundle] WARN: no YARD_API_KEY — license validation is disabled in this build" >&2
fi
if [[ -n "${YARD_SANDBOX:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Add :YardSandbox string $YARD_SANDBOX" "$APP_DIR/Contents/Info.plist"
  echo "[bundle] SANDBOX BUILD for '$YARD_SANDBOX' — test only, do not publish" >&2
fi

# PkgInfo
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

# ---------- 4. Ad-hoc codesign ----------
echo "[sign] ad-hoc codesigning"
codesign --force --deep --sign - --options runtime --timestamp=none "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR" || {
  echo "[sign] verification failed" >&2
  exit 1
}

# ---------- 5. Zip for distribution ----------
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
ZIP_PATH="$BUILD_DIR/SimpleNote-$VERSION-mac${YARD_SANDBOX:+-sandbox-$YARD_SANDBOX}.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

# ---------- 6. Done ----------
echo
echo "Built: $APP_DIR"
echo "Zip:   $ZIP_PATH"
echo "Open with:  open \"$APP_DIR\""
if [[ -z "${YARD_SANDBOX:-}" ]]; then
  echo "Publish:    yard releases publish v$VERSION --file \"$ZIP_PATH\""
fi
