# Sound probe

[한국어](README.ko.md)

Measures how fast two audio packages start a sound, to choose the one behind `Sound` (docs/plans/PLAN_V07.md §7, DESIGN D138): `audioplayers` and `flutter_soloud`. The sounds are made in the app (a 50 ms shot, an 80 ms noise, a 30 ms beep, a tone and a chord, as WAV), so nothing comes from outside.

Three cases, each the milliseconds from the call to the first progress the package reports (a position above zero, or the playing state when that comes first); -1 when nothing is reported within a second:

1. one short effect, five times with a pause between;
2. the same effect twenty times, 10 ms apart, each on its own;
3. the five different sounds at once.

That is the package's own latency, not what a microphone would hear: the engine's buffer adds the same to both.

## Running

Use the pinned Flutter first (`dart tool/check_flutter.dart` in `packages/gubasic_runtime`), then:

```sh
cd packages/gubasic_runtime/tool/sound_probe
flutter pub get
flutter run -d windows --release    # or -d macos: starts by itself, saves sound-probe-<system>.json in Downloads
flutter build web --release
node ../../../../tool/web_check/sound_probe.mjs build/web --channel chrome   # prints the result line
```

In the browser the page waits for Start, since a page plays sound only after a click; the script clicks it. On the desktop the app starts by itself after a second and writes the results to the Downloads folder.

## Results

The results so far are in the plan's §7 table. Every platform is measured the same way; the one on macOS is taken on the Mac.
