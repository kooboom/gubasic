# Stage 2 plan — building real apps

[한국어](STAGE2_PLAN.ko.md)

**Status: approved by the author on 2026-10-26, with the decisions in §6. Steps 2-0 to 2-2 come first; after 2-2 the author decides the next steps from its measurements (§7) and the bundle design (step 2-3).**

This plan answers how a GuBASIC project becomes an app that runs on its own, without the IDE: for the web, macOS and Windows. It compares three ways to do it, says where the build happens when the user's computer has no Flutter, and splits the work into small steps that each end with something to look at.

**It changes documents that were in force**, and says so here rather than diverging quietly (CLAUDE.md). Step 2-0 changes them first:

- DESIGN §2.2 and D3 present the transpiler as *the* way to release; §2.3 says "generated apps never carry the interpreter"; §12 says Flutter is downloaded on the first Build.
- ROADMAP stage 2 lists the transpiler first and ends "when one project ships to four platforms" (Android included).
- CLAUDE.md describes the transpiler as how native release builds are made, and hard rule 3 asks for parity "both modes".

The hard rules themselves stay: one AST for every way of running (rule 2), parity tests for every feature (rule 3), the interpreter async (rule 4), and apps that draw only through `gubasic_runtime` (rule 6). Keeping them is what leaves the way open for the transpiler later.

---

## 1. Goal

A student who has made an app in the IDE can turn it into:

- **a web app**: a folder of files that runs in a browser from any web host;
- **a macOS app** and **a Windows app**: something that opens with a double-click, on a computer with no GuBASIC and no Flutter.

The app looks and behaves exactly as it did when F5 ran it in the IDE, because it draws its forms with the same `gubasic_runtime` widgets (rule 6) and follows the same execution model (one handler at a time, modal dialogs, `DoEvents`; DESIGN §3).

Who it is for: elementary school students and their teachers. That decides most choices below: no developer tools to install, no accounts to create, no command line.

## 2. Three ways to do it

### (A) Transpiler: BASIC → Dart → `flutter build`

The IDE turns the project's code into Dart, writes a Flutter project around it, and Flutter compiles it.

- **Pros:** the fastest apps (AOT native code; the interpreter's slow long loops, KNOWN_ISSUES, go away); the app carries no interpreter; the long-term design (D3) already describes it; extra pub.dev components (DESIGN §5.1) and the embedded-Dart escape hatch (stage 3) need it.
- **Cons:** someone must run Flutter, which needs Xcode for macOS apps and Visual Studio with "Desktop development with C++" for Windows apps ([Flutter: macOS setup](https://docs.flutter.dev/platform-integration/macos/setup), [Flutter: Windows setup](https://docs.flutter.dev/platform-integration/windows/setup)): many gigabytes, and not something a school PC or a child installs. The generated code must reproduce the interpreter's behaviour statement by statement: every procedure async, one handler at a time, re-entrancy blocked, `DoEvents`, the run-time errors with their codes and lines.
- **Parity:** run every program in `test/parity/` both ways and compare the transcripts. Programs without forms can run with plain `dart run`; programs with forms need `flutter test` on the generated project in CI.
- **Error messages and lines:** a Dart exception does not know the `.gbas` line. The generated code must pass line numbers into runtime helpers that raise GuBASIC's own errors (R0xx with English and Korean messages); everything Dart can throw must be caught and translated.
- **App size:** the smallest of the three.
- **Effort:** the largest: a code generator for the whole AST, a second implementation of the execution model, a build pipeline, and parity infrastructure that runs Flutter in CI.

### (B) Player: the interpreter and the project inside a prebuilt app

A **player** is a Flutter app built once, by GuBASIC's own CI, that contains the interpreter (`gubasic_lang`) and the run window, and runs the project it is given. "Building" a student's app means copying the player and putting the project's files into it: no compiler at all.

- **Pros:** works with no Flutter anywhere, from the web IDE too; the same interpreter code and the same run window code as F5, so parity holds by construction; the same player becomes the phone Player of stage 3 (DESIGN §12).
- **Cons:** the interpreter's speed (a million-round loop takes about 3 s on the web, KNOWN_ISSUES); the app carries the interpreter and the source code (readable by anyone, which DESIGN §11 already assumes of everything in an app); changing a macOS app's files breaks its signature, which Apple silicon requires for any executable to run, an ad-hoc signature being enough ([Apple: macOS Big Sur 11.0.1 universal apps release notes](https://developer.apple.com/documentation/macos-release-notes/macos-big-sur-11_0_1-universal-apps-release-notes), quoted in [The Eclectic Light Company](https://eclecticlight.co/2020/08/22/apple-silicon-macs-will-require-signed-code/)), so the macOS app must be signed again after the project goes in.
- **Parity:** the IDE's run window and the player share one package (step 2-1), so there is one implementation to test; the existing parity programs and event scripts (DESIGN §9.1) run through the player in widget tests, as they already run through the IDE.
- **Error messages and lines:** exactly the interpreter's: the same R0xx codes, messages in English and Korean, and `.gbas` lines.
- **App size:** about a Flutter app's own size plus the interpreter, the runtime and the project. Measured in step 2-1; for comparison the whole IDE is 51 MB on macOS and its web build's code (`main.dart.js`) 3.3 MB.
- **Effort:** moderate: a small app, a project bundle format, an export command, a way to ship the prebuilt players with each release, and macOS re-signing.

### (C) Both, in order: the player now, the transpiler later

Stage 2 ships apps with the player (B). The transpiler (A) stays the design's long-term fast path and is planned again when there is a reason: a program too slow in the player, an extra component, or the escape hatch, which all need it.

**Decided: (C).** Visual Basic 6 shipped apps the same way: every program used its run-time DLL, MSVBVM60.DLL, for forms, controls and run-time functions, and could be compiled to p-code, which the runtime translated statement by statement as it ran, or, in the Professional and Enterprise editions, to native code, which still needed the DLL ([Microsoft: Compiling your project to native code](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa240843(v=vs.60))). GuBASIC's player is that runtime with the interpreter in the place of p-code; the transpiler is the native-code option, later. Only (B) works for the people GuBASIC is for: no Flutter, no Xcode, no Visual Studio, no command line, and it reuses what stage 1 built and tested. (A) is not thrown away: the AST stays shared (rule 2), and the parity programs written for the player are the ones the transpiler will have to pass.

## 3. Where the build happens

The user's computer has no Flutter. The ways that remain:

| Way | Web | macOS | Windows | For children and teachers |
|---|---|---|---|---|
| **Player templates** (B): GuBASIC's CI builds the players for each release; the IDE adds the project | the IDE zips the web player and the project, in the browser too | the macOS IDE adds the project and signs the app again (ad-hoc, with the system's `codesign`) | any IDE adds the project folder next to the program | no tools, no accounts; works offline once the template is there |
| Flutter downloaded by the IDE (A) | possible | needs Xcode as well | needs Visual Studio as well | too big and too technical |
| GitHub Actions cloud build (A) | yes | yes | yes | needs a GitHub account, and GitHub's terms say "You must be age 13 or older" ([GitHub Terms of Service](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service)); for a teacher, not a student |
| Compiling Dart inside the browser (A) | not attempted | — | — | the compiler would have to run in the page; out of scope |

**Decided:** player templates. The IDE does not carry them (they would make the web IDE much heavier): it downloads the one it needs, for its own version, from GuBASIC's GitHub Release or its Pages site, the first time, and keeps it. A macOS app is exported only from the macOS IDE, which can sign it again; the Windows and web IDEs offer the web and Windows apps.

What the student sees: **File → Export as app…**, a choice of Web, Windows or macOS, a folder or a `.zip`, and a few lines on how to open it (for macOS, the steps of the v0.1.0 release notes).

## 4. Several forms: in stage 2, after the export

Several forms (`Form2.Show`, DESIGN §3.3) are a language and runtime feature: they change the interpreter, the run window, the designer, the project file and the parity tests, whether apps are exported or not. The export does not need them: it carries whatever the project has.

**Decided:** keep them in stage 2, as their own block right after the export (steps 2-7 and 2-8). Doing the export first gives students something to take home sooner, and each block stays reviewable on its own.

## 5. Steps

Each step ends with something the author can look at. Every step keeps the stage 1 rules: tests, parity, en/ko messages, docs in both languages, a PR merged only when checked.

| Step | What | What you can see when it is done |
|---|---|---|
| **2-0** | The decisions below written down: DESIGN (new D-numbers; §2.2, §2.3, §12 changed), ROADMAP stage 2 reordered, CLAUDE.md's description of release builds | A docs-only PR |
| **2-1** | Move the run window and `RunHost` out of `apps/ide` into a package both use (`packages/gubasic_player`, name to decide); the IDE behaves exactly as before | All IDE tests and the widget parity tests pass unchanged; F5 looks the same |
| **2-2** | `apps/player`: a Flutter app that runs one project, full window, with no IDE around it; for now the project is built in. CI builds it for web, macOS and Windows, and reports its size. The speed of the benchmarks of §7 is measured in the IDE and in the player, and the numbers that bring the transpiler back are written into §7 | `flutter run` shows hello as an app of its own; the sizes of the three builds; the measurements and the criteria |
| **2-3** | The project bundle: the project's files and pictures in one file, with a format version from the first one (`formatVersion`, as rule 8 asks), designed from the start to hold several forms even before 2-7 lets a project have them; read by the player at start; a newer format than the player knows is refused with a message. The design is reported after 2-2, before it is built | The player opens the quiz example from a bundle; a test opens every example |
| **2-4** | Export for the web: File → Export as app… → Web, from the desktop and the web IDE; the template downloaded and kept | A `.zip` that, unzipped and served by any web host (GitHub Pages, a school server), runs the app; checked in Chromium and WebKit |
| **2-5** | Export for Windows | The exported folder runs on the school PC (the author checks; CI checks that the files are complete) |
| **2-6** | Export for macOS, from the macOS IDE, signed again ad-hoc | The exported app opens on the Mac after Open Anyway; `codesign --verify` passes |
| **2-7** | Several forms in the language and the run window: `Form2.Show`, `Hide`, `Unload`, a startup form or `Sub Main` (DESIGN §3.2, §3.3), with parity programs | A two-form example runs with F5 and as an exported app |
| **2-8** | Several forms in the designer and the project files | Adding, renaming and deleting a form in the IDE |
| **2-9** | A `Timer` control: `Interval`, `Enabled` and a `Tick` event, with an event-script step for parity tests | The small game of §7 written with a Timer instead of a `DoEvents` loop |
| **2-10** | Key events: `KeyDown` and `KeyUp` on the form, with an event-script step | A shape moved with the arrow keys, with F5 and in an exported app |

The other stage 2 items of the ROADMAP (`LayoutMode`, `Handles`, `OptionButton`, menus, `Database`, `Http`, `ByRef`) come after these, each planned on its own.

**Timer and key events: in stage 2, after several forms (2-9, 2-10).** They are what turns a form into a small game or an animation, the thing children most want to make next, and both run in the interpreter and the player alike, so they need no transpiler. A Timer is a control like the others (`component.yaml`, rule 7); a tick is an event like a click, so it follows the execution model: it does not re-enter, and a tick that comes while a handler runs waits like any other event (DESIGN §3.1). Key events are for the web and the desktop, where there is a keyboard; on phones (stage 3) they simply do not come.

## 6. Decisions

Decided by the author on 2026-10-26.

| # | Question | Decision |
|---|---|---|
| 1 | Which way: (A), (B) or (C)? | **(C)**: the player for stage 2, the transpiler planned again later; the hard rules stay, so the way to it stays open |
| 2 | When does the transpiler come back? | When a benchmark of §7 is slower in the player than the criteria written there after step 2-2, or for extra components and the escape hatch; at the latest at the start of stage 3 |
| 3 | Android in stage 2? | **No**: an Android app changed after it is built must be signed again, with Android's own tool (`apksigner`, part of the Android SDK Build Tools: [Android Developers](https://developer.android.com/tools/apksigner)) and a key; it moves to stage 3, with the phone Player. **Stage 2 is done when one project ships to the web, macOS and Windows** |
| 4 | Where do the player templates come from? | Not inside the IDE: downloaded once per version from the GitHub Release or Pages, and kept |
| 5 | macOS export from Windows or the web? | **No**: only the macOS IDE exports macOS apps, since only it can sign them again |
| 6 | What does an exported app do on a run-time error? | What F5 does: the program ends. The app shows the error (code, message, line) in a dialog and closes when it is dismissed |
| 7 | The app's name, window and icon | The project's name; the startup form's size; GuBASIC's icon. Choosing an icon comes later |
| 8 | How is a web app shared? | A `.zip` to put on any web host, with short steps for GitHub Pages and a school server. A page on GuBASIC's own site that plays a project file comes with stage 3's Publish menu |
| 9 | Several forms: in stage 2? | **Yes**, as their own block after the export (§4); the bundle can hold them from the start (2-3) |
| 10 | The package and app names | `packages/gubasic_player` and `apps/player`, the same player that becomes the phone Player in stage 3 |

## 7. Speed: what is measured in 2-2, and when the transpiler comes back

The player runs the same interpreter as F5, so it should be as fast as the IDE; step 2-2 measures it rather than assume it, and turns the result into numbers.

**Benchmarks**, each run in the IDE (F5) and in the player, on the web (Chrome and Safari) and in the macOS app:

1. **Arithmetic loop:** a million rounds of `total = total + i * 2 - 1` (the program of KNOWN_ISSUES).
2. **Text:** building and searching a long text with `&`, `Mid`, `InStr` and `Len` in a loop.
3. **The examples:** `typing` and `quiz` driven by their event scripts: the time from each step to the screen showing its result.
4. **A small game:** 20 Images on a form, each moved a little every round; every round checks each pair for a collision and changes a score Label. With no Timer yet (2-9), a loop with `DoEvents` does what a 30 ms Timer would, as fast as it can. Measured: **updates per second (the aim is 30 or more)**, milliseconds per update, and how much of it is the interpreter (from the loop's start to its `DoEvents`) and how much drawing (Flutter's frame timings: build and raster).

**Measured in step 2-2** (2026-10-26, `main` at `ba11bc0` with step 2-2; the player and the IDE built for measuring, `lib/bench_main.dart`; Chrome and WebKit through Playwright on the author's Mac, WebKit standing in for Safari; the macOS apps as release builds). The player's numbers first, the IDE's in brackets:

| Benchmark | Chrome | WebKit | macOS app |
|---|---|---|---|
| 1. Arithmetic loop, a million rounds | 7.5 s (7.7 s) | 7.1 s (7.2 s) | 1.38 s (1.38 s) |
| — of which the interpreter | 3.0 s | 2.5 s | 1.35 s |
| 2. Text | 32 ms (196 ms) | 36 ms (66 ms) | 12 ms (16 ms) |
| 3. Typing and quiz: a step, after the first | 7.5–7.7 ms (9.6–10 ms) | 12–14 ms (14–15 ms) | 16–17 ms (8 ms) |
| — the first step | 6–19 ms (183–210 ms) | 12–13 ms (30–46 ms) | 11–29 ms (11–13 ms) |
| 4. Small game: updates per second | 141 (116) | 186 (164) | 2324 (1953) |
| — the interpreter, per round | 0.93 ms (0.98 ms) | 0.59 ms (0.63 ms) | 0.39 ms (0.40 ms) |
| — frames drawn per second | 93 (89) | 60 (55) | 63 (116) |
| — a frame's build + raster | 6.8 ms (8.0 ms) | 2.6 ms (4.6 ms) | 2.1 ms (2.0 ms) |

What they say:

- **The small game is far above 30 updates a second everywhere** (141 to 2324 in the player). The interpreter needs under 1 ms of a 30 ms tick, drawing a few ms; the rest of a round on the web is the wait in `DoEvents`, about 5 ms, which is the browser's shortest timer.
- **The player is as fast as the IDE**, as it runs the same interpreter; where it is faster (text, the first steps), the IDE was redrawing its own Output pane and run window.
- **The steps of typing and quiz take a frame or less** (7 to 17 ms): what a user does shows at the next frame. On macOS the player's steps wait for the display's next frame (16.7 ms at 60 Hz), the IDE's come sooner because the IDE was drawing frames anyway.
- **The million-round loop is the one slow case, and mostly not the interpreter's fault on the web:** of its 7.5 s, 3.0 s is the interpreter and 4.5 s is spent in the 1000 pauses the interpreter makes so that the screen can update and Stop can work (one every 1000 rounds, `_stepsPerYield`), each lasting the browser's shortest timer, about 4.5 ms. Pausing by time instead (when 10 ms or so have passed) would bring it close to 3 s with no change in what programs compute.

**Sizes of the player** (release builds, the hello project built in): **web** 42 MB as a folder, of which 36 MB are CanvasKit's builds for different browsers; a browser loads about 11 MB (`main.dart.js` 2.8 MB, one CanvasKit 7 MB, Pretendard 1.6 MB); 15 MB as a `.zip`. **macOS** 43 MB (universal), 19 MB as a `.zip`. **Windows** 29.5 MB as a folder, with the Visual C++ runtime next to the program (CI prints it with every build; the IDE's folder is 36 MB). The IDE for comparison: 51 MB on macOS, `main.dart.js` 3.4 MB.

**Criteria.** The transpiler is planned again (decision 2) when, in the player, on any of the web or macOS:

1. **the small game's interpreter needs more than 10 ms a round** (a third of a 30 ms tick; now 0.39 to 0.93 ms);
2. **a step of the typing or quiz example, after the first, takes more than 50 ms** (now at most 26 ms);
3. **the million-round loop's interpreter part takes more than 6 s** (twice today's 3.0 s on Chrome), or a student's real program is found too slow;

but only after the interpreter has been made faster as below, and still fails them. The benchmarks are measured again with each change to the interpreter's speed.

**If the interpreter is the slow part,** these come before a transpiler, each only where the result is provably the same (rule 4 forbids fast paths that change behaviour, and the parity tests are the judge):

- **Pausing by time:** the pause that lets the screen update comes when about 10 ms have passed, not every 1000 rounds; on the web it is the largest part of the loop's time (above).
- **Resolved names:** the analyzer already knows every variable; giving each a slot number instead of looking it up by name on every use.
- **Synchronous runs of statements:** a run of statements with no call to a user procedure and no `DoEvents`, `MsgBox` or `InputBox` cannot wait; evaluating it without an `await` per statement keeps the order exactly (D25 already does this for expressions).
- **Property changes in batches:** many `Left`/`Top` changes in one round become one redraw at the next frame instead of one notification each.
- **Cheaper control lookups:** a control's state found once per handler, not on every property access.

If drawing is the slow part, the runtime's widgets are looked at instead (repainting only what moved), which a transpiler would not change.

## 8. Risks

- **macOS:** a signature broken by an added file stops the app; re-signing must cover the whole bundle, and Gatekeeper still asks for Open Anyway, since there is no Developer ID. The project goes inside the app, not next to it, so that the app is one thing to copy.
- **Windows:** an unsigned program from the internet can be warned about by SmartScreen and some antivirus programs; the release notes already say so.
- **Versions:** an app exported by one IDE version and a player of another must not meet unnoticed: the bundle's format version and the player's version are checked, and the IDE downloads the template of its own version.
- **Speed:** heavy loops are slower than in a native app; programs of the size beginners write do not notice it (KNOWN_ISSUES). If one does, that is decision 2's trigger.
- **The web app needs a web host:** opening `index.html` straight from the disk may not work in browsers; step 2-4 checks, and the export says how to host it.
- **The source is inside the app:** anyone can read it. The secret-key warning (DESIGN §11) matters more once apps travel.
- **One run window, two apps:** the move in step 2-1 must not change the IDE; its tests are the guard.

## 9. Not now

- The transpiler (decision 2), Flutter downloads and GitHub Actions builds of students' apps.
- iOS and Android, app stores, Developer ID signing and notarization (paid accounts).
- Extra pub.dev components and the embedded-Dart escape hatch (stage 3; they need the transpiler).
- The Publish menu (stage 3).
- Choosing an app icon, and sharing a web app by link.
