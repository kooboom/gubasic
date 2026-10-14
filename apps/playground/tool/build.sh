#!/usr/bin/env bash
# Builds the playground into build/web. Used by CI and the Pages workflow.
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf build/web
mkdir -p build/web
dart compile js -O2 --no-source-maps -o build/web/main.dart.js web/main.dart
rm -f build/web/*.deps
cp web/index.html web/styles.css build/web/
ls -l build/web
