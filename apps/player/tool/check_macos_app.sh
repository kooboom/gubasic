#!/bin/bash
# Unzips the macOS apps that apps/ide/test/macos/export_hello_test.dart
# exports (D87) and checks them as a Mac would: the signature is whole
# (codesign --verify --deep --strict); with the quarantine a download
# gets, Gatekeeper refuses the ad-hoc signed app (spctl --assess says
# rejected), as README.txt tells the user; Ending, whose program ends,
# closes by itself; 안녕 starts and stays open. CI runs it on a macOS runner.
#
#   tool/check_macos_app.sh FOLDER_WITH_THE_ZIPS
set -euo pipefail
apps="$1"
work="$(mktemp -d)"
trap 'pkill -f "$work" || true; rm -rf "$work"' EXIT

for name in 안녕 Ending; do
  ditto -x -k "$apps/$name-macos.zip" "$work/"
  app="$work/$name-macos/$name.app"
  test -f "$work/$name-macos/README.txt"
  test -f "$app/Contents/Resources/project.gbz"
  codesign --verify --deep --strict "$app"
  echo "$name.app: the signature is whole"
done

quarantined="$work/quarantined.app"
ditto "$work/안녕-macos/안녕.app" "$quarantined"
xattr -r -w com.apple.quarantine "0083;$(printf %x "$(date +%s)");Safari;" "$quarantined"
if spctl --assess --type execute "$quarantined" 2>/dev/null; then
  echo "Gatekeeper let a quarantined ad-hoc app through" >&2
  exit 1
fi
echo "quarantined: Gatekeeper refuses it, as README.txt says"

# Ending ends its program in Form_Load: the app must close by itself.
open -W "$work/Ending-macos/Ending.app" &
waiting=$!
for _ in $(seq 1 60); do
  kill -0 "$waiting" 2>/dev/null || break
  sleep 0.5
done
if kill -0 "$waiting" 2>/dev/null; then
  echo "Ending.app did not close when its program ended" >&2
  exit 1
fi
echo "Ending.app closed by itself"

open "$work/안녕-macos/안녕.app"
sleep 8
# By the work folder: pgrep does not match the Korean name as written.
if ! pgrep -f "$work/" >/dev/null; then
  echo "안녕.app is not running" >&2
  exit 1
fi
echo "안녕.app runs"
