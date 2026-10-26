# GuBASIC player

Runs one GuBASIC project as an app of its own, for the web, macOS and
Windows, with the same interpreter and run window as the IDE's F5
(docs/DESIGN.md D79, D80; docs/STAGE2_PLAN.md).

For now the project is built in: the files under `project/` (the hello
example). The bundle of step 2-3 takes their place, and the IDE's export
(steps 2-4 to 2-6) puts a student's project into a prebuilt player.

    flutter run -d chrome        # or -d macos, -d windows

## Measuring (STAGE2_PLAN §7)

`lib/bench_main.dart` runs one of the benchmarks of `test/bench/` and the
typing and quiz examples, drives it with its event script and prints one
line, `GUBASIC_BENCH {json}`. The IDE has the same entry point.

    flutter build web --release -t lib/bench_main.dart \
      --dart-define=GUBASIC_BENCH=true --no-web-resources-cdn
    # then open the page with ?bench=loop, text, typing, quiz or game

    flutter build macos --release -t lib/bench_main.dart \
      --dart-define=GUBASIC_BENCH=true
    GUBASIC_BENCH_NAME=game "build/macos/Build/Products/Release/GuBASIC Player.app/Contents/MacOS/GuBASIC Player"

Apps are never built from it: without `GUBASIC_BENCH`, the probe's calls
are compiled away.
