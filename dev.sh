#!/usr/bin/env bash
# Development compile helper for existing patched Frida source.
#
# Usage:
#   ARCH=android-arm64 bash dev.sh
#   ARCH=android-arm64 NDK_PATH=/workspaces/phantom-frida/build/android-ndk-r29 bash dev.sh
#
# This script assumes you have already executed build-frida.sh once and
# have a patched Frida source tree in build/frida.
# It does not re-run patching; it only configures and builds the existing tree.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="${ARCH:-android-arm64}"
NDK_PATH="${NDK_PATH:-$SCRIPT_DIR/build/android-ndk-r29}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output}"
FRIDA_DIR="$SCRIPT_DIR/build/frida"

if [[ "$ARCH" == *","* ]]; then
  echo "ERROR: dev.sh supports a single ARCH only, e.g. ARCH=android-arm64"
  exit 1
fi

if [[ ! -d "$FRIDA_DIR" ]]; then
  echo "ERROR: patched source tree not found: $FRIDA_DIR"
  echo "Run build-frida.sh once first to populate build/frida and apply patches."
  exit 1
fi

if [[ ! -d "$NDK_PATH" ]]; then
  echo "ERROR: Android NDK not found at: $NDK_PATH"
  echo "Set NDK_PATH to an existing NDK directory, or run build-frida.sh once to download it."
  exit 1
fi

if ! command -v make >/dev/null 2>&1; then
  echo "ERROR: make not found. Install it before running dev.sh."
  exit 1
fi

if [[ ! -x "$NDK_PATH" && ! -d "$NDK_PATH" ]]; then
  echo "ERROR: NDK_PATH appears invalid: $NDK_PATH"
  exit 1
fi

cat <<EOF
=== dev.sh ===
ARCH:       $ARCH
NDK_PATH:   $NDK_PATH
FRIDA_DIR:  $FRIDA_DIR
OUTPUT_DIR: $OUTPUT_DIR
EOF

mkdir -p "$OUTPUT_DIR"
cd "$FRIDA_DIR"

export ANDROID_NDK_ROOT="$NDK_PATH"

BUILD_DIR="$FRIDA_DIR/build"
if [[ -d "$BUILD_DIR" && -f "$BUILD_DIR/Makefile" ]]; then
  echo "Already configured. Reusing existing build directory: $BUILD_DIR"
else
  echo "Configuring Frida for $ARCH..."
  ./configure --host="$ARCH"
fi

echo "Running make -j$(nproc)..."
make -j"$(nproc)"

echo "Copying build artifacts to $OUTPUT_DIR..."
shopt -s nullglob
for src in "$FRIDA_DIR/build/subprojects/frida-core/server/"* "$FRIDA_DIR/build/subprojects/frida-core/lib/agent/"* "$FRIDA_DIR/build/subprojects/frida-core/lib/gadget/"*; do
  if [[ -f "$src" ]]; then
    cp -p "$src" "$OUTPUT_DIR/"
    echo "  copied: $(basename "$src")"
  fi
done
shopt -u nullglob

echo "Build finished. Artifacts are in $OUTPUT_DIR"
