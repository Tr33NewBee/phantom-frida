#!/usr/bin/env bash
# Local build wrapper for phantom-frida, based on .github/workflows/build.yml
#
# Usage:
#   FRIDA_VERSION=17.7.2 CUSTOM_NAME=stealth ARCH=android-arm64 bash build-frida.sh
#   bash build-frida.sh
#
# Optional environment variables:
#   FRIDA_VERSION  Frida version to build (default: 17.7.2)
#   CUSTOM_NAME    Custom name replacing "frida" (default: ajeossida)
#   ARCH           Target arch(s) (default: android-arm64)
#   PORT           Custom listening port (default: 27042 unchanged)
#   EXTENDED       1 to enable extended anti-detection, 0 to disable (default: 1)
#   TEMP_FIXES     1 to enable stability fixes, 0 to disable (default: 0)
#   WORK_DIR       Working directory (default: build)
#   OUTPUT_DIR     Output directory (default: output)
#   NDK_PATH       Existing NDK path to use instead of auto-download
#   SKIP_CLONE     1 to reuse existing source in work dir, 0 to always clone (default: 0)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRIDA_VERSION="${FRIDA_VERSION:-17.7.2}"
CUSTOM_NAME="${CUSTOM_NAME:-ajeossida}"
ARCH="${ARCH:-android-arm64}"
PORT="${PORT:-}"
EXTENDED="${EXTENDED:-1}"
TEMP_FIXES="${TEMP_FIXES:-0}"
WORK_DIR="${WORK_DIR:-$SCRIPT_DIR/build}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output}"
NDK_PATH="${NDK_PATH:-}"
SKIP_CLONE="${SKIP_CLONE:-0}"

cat <<EOF
=== Local Frida build ===
Version:      $FRIDA_VERSION
Name:         $CUSTOM_NAME
Arch:         $ARCH
Port:         ${PORT:-27042 (default)}
Extended:     $EXTENDED
Temp fixes:   $TEMP_FIXES
Work dir:     $WORK_DIR
Output dir:   $OUTPUT_DIR
NDK path:     ${NDK_PATH:-auto-download}
Skip clone:   $SKIP_CLONE
EOF

# Ensure basic dependencies are installed.
if ! command -v apt-get >/dev/null 2>&1; then
  echo "ERROR: apt-get not found. Install dependencies manually: build-essential curl git python3 unzip"
  exit 1
fi

if ! sudo apt-get update; then
  echo "WARNING: apt-get update failed. This may be caused by an unsigned external APT repository."
  echo "Proceeding to install required packages anyway. If install fails, fix your APT sources or import missing keys."
fi
sudo apt-get install -y build-essential curl git python3 unzip

CMD=(python3 "$SCRIPT_DIR/build.py" --version "$FRIDA_VERSION" --name "$CUSTOM_NAME" --arch "$ARCH" --work-dir "$WORK_DIR" --output-dir "$OUTPUT_DIR" --verify)

if [[ -n "$PORT" ]]; then
  CMD+=(--port "$PORT")
fi
if [[ "$EXTENDED" != "0" ]]; then
  CMD+=(--extended)
fi
if [[ "$TEMP_FIXES" != "0" ]]; then
  CMD+=(--temp-fixes)
fi
if [[ "$SKIP_CLONE" != "0" ]]; then
  CMD+=(--skip-clone)
fi
if [[ -n "$NDK_PATH" ]]; then
  CMD+=(--ndk-path "$NDK_PATH")
fi

echo "Running: ${CMD[*]}"
"${CMD[@]}"
