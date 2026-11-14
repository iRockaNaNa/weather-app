#!/usr/bin/env bash
# Restores the binary assets (launcher icons, splash images, Gradle wrapper jar)
# vendored in binary-assets.tar.gz.b64. Run from the repo root (CI does this
# before building). Safe to re-run; it just overwrites the same files.
set -euo pipefail
cd "$(dirname "$0")/.."
base64 -d tooling/binary-assets.tar.gz.b64 | tar -xz
echo "Binary assets restored."
