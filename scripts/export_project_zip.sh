#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_DIR="$ROOT_DIR/exports"
ZIP_PATH="$EXPORT_DIR/uiuc_sublease_phase1.zip"

mkdir -p "$EXPORT_DIR"

# Build zip from repo root excluding git internals and previous exports.
(
  cd "$ROOT_DIR"
  zip -r "$ZIP_PATH" . \
    -x ".git/*" \
    -x "exports/*"
)

echo "Created: $ZIP_PATH"
