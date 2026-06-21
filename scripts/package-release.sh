#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/package-release.sh --version VERSION [--output-dir DIR]

Build FROK.app in Release configuration, package it as a zip, and print its sha256.
EOF
}

VERSION=""
OUTPUT_DIR="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "Missing required argument: --version" >&2
  usage >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${ROOT_DIR}/DerivedData"
ZIP_NAME="FROK-${VERSION}.zip"
ZIP_PATH="${OUTPUT_DIR%/}/${ZIP_NAME}"

mkdir -p "$OUTPUT_DIR"

echo "Building FROK ${VERSION}..."
xcodebuild \
  -project "${ROOT_DIR}/FROK.xcodeproj" \
  -scheme FROK \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="$(find "${DERIVED_DATA}/Build/Products/Release" -name 'FROK.app' -type d | head -n 1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Failed to locate FROK.app in ${DERIVED_DATA}/Build/Products/Release" >&2
  exit 1
fi

echo "Packaging ${APP_PATH} -> ${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
echo
echo "Release artifact: ${ZIP_PATH}"
echo "sha256: ${SHA256}"
