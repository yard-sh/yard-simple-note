#!/usr/bin/env bash
# Build Simple Note as a macOS .app bundle.
# Usage:  ./build.sh             — universal release build into build/SimpleNote.app
#         ./build.sh --arm64     — single-arch (faster local builds)
#         ./build.sh --skip-fonts — don't try to fetch fonts (use whatever's on disk)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SimpleNote"
DISPLAY_NAME="Simple Note"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/$DISPLAY_NAME.app"
FONTS_DIR="$ROOT/Sources/SimpleNote/Resources/Fonts"
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

# SwiftPM resource bundle (named "<package>_<target>.bundle"). Move to Contents/Resources.
RESOURCE_BUNDLE="$BIN_DIR/SimpleNote_SimpleNote.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
fi

# Copy fonts directly into Contents/Resources/Fonts as well so AppKit's
# ATSApplicationFontsPath can pick them up at launch (belt-and-suspenders).
if [[ -d "$FONTS_DIR" ]] && compgen -G "$FONTS_DIR/*.ttf" > /dev/null; then
  cp -f "$FONTS_DIR"/*.ttf "$APP_DIR/Contents/Resources/Fonts/" 2>/dev/null || true
fi

# Info.plist
cp "$PACKAGING_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

# PkgInfo
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

# ---------- 4. Ad-hoc codesign ----------
echo "[sign] ad-hoc codesigning"
codesign --force --deep --sign - --options runtime --timestamp=none "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR" || {
  echo "[sign] verification failed" >&2
  exit 1
}

# ---------- 5. Done ----------
echo
echo "Built: $APP_DIR"
echo "Open with:  open \"$APP_DIR\""
