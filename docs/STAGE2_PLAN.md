# Stage 2 plan — building real apps

[한국어](STAGE2_PLAN.ko.md)

**Status: a proposal for the author's review. Nothing here is decided until the author says so; nothing is built yet.**

This plan answers how a GuBASIC project becomes an app that runs on its own, without the IDE: for the web, macOS and Windows. It compares three ways to do it, says where the build happens when the user's computer has no Flutter, and splits the work into small steps that each end with something to look at.

**It conflicts with documents that are in force**, and says so here rather than diverging quietly (CLAUDE.md). If the recommended way (C) is chosen, step 2-0 changes them first:

- DESIGN §2.2 and D3 present the transpiler as *the* way to release; §2.3 says "generated apps never carry the interpreter"; §12 says Flutter is downloaded on the first Build.
- ROADMAP stage 2 lists the transpiler first and ends "when one project ships to four platforms" (Android included).
- CLAUDE.md describes the transpiler as how native release builds are made, and hard rule 3 asks for parity "both modes".

The hard rules themselves stay: one AST for every way of running (rule 2), parity tests for every feature (rule 3), the interpreter async (rule 4), and apps that draw only through `gubasic_runtime` (rule 6).

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

**Recommended: (C).** Only (B) works for the people GuBASIC is for: no Flutter, no Xcode, no Visual Studio, no command line, and it reuses what stage 1 built and tested. (A) is not thrown away: the AST stays shared (rule 2), and the parity programs written for the player are the ones the transpiler will have to pass.

## 3. Where the build happens

The user's computer has no Flutter. The ways that remain:

| Way | Web | macOS | Windows | For children and teachers |
|---|---|---|---|---|
| **Player templates** (B): GuBASIC's CI builds the players for each release; the IDE adds the project | the IDE zips the web player and the project, in the browser too | the macOS IDE adds the project and signs the app again (ad-hoc, with the system's `codesign`) | any IDE adds the project folder next to the program | no tools, no accounts; works offline once the template is there |
| Flutter downloaded by the IDE (A) | possible | needs Xcode as well | needs Visual Studio as well | too big and too technical |
| GitHub Actions cloud build (A) | yes | yes | yes | needs a GitHub account, and GitHub's terms say "You must be age 13 or older" ([GitHub Terms of Service](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service)); for a teacher, not a student |
| Compiling Dart inside the browser (A) | not attempted | — | — | the compiler would have to run in the page; out of scope |

**Recommended:** player templates. The IDE does not carry them (they would make the web IDE much heavier): it downloads the one it needs, for its own version, from GuBASIC's GitHub Release or its Pages site, the first time, and keeps it. A macOS app is exported only from the macOS IDE, which can sign it again; the Windows and web IDEs offer the web and Windows apps.

What the student sees: **File → Export as app…**, a choice of Web, Windows or macOS, a folder or a `.zip`, and a few lines on how to open it (for macOS, the steps of the v0.1.0 release notes).

## 4. Several forms: in stage 2, after the export

Several forms (`Form2.Show`, DESIGN §3.3) are a language and runtime feature: they change the interpreter, the run window, the designer, the project file and the parity tests, whether apps are exported or not. The export does not need them: it carries whatever the project has.

**Recommended:** keep them in stage 2, as their own block right after the export (steps 2-7 and 2-8). Doing the export first gives students something to take home sooner, and each block stays reviewable on its own.

## 5. Steps

Each step ends with something the author can look at. Every step keeps the stage 1 rules: tests, parity, en/ko messages, docs in both languages, a PR merged only when checked.

| Step | What | What you can see when it is done |
|---|---|---|
| **2-0** | The decisions below written down: DESIGN (new D-numbers; §2.2, §2.3, §12 changed), ROADMAP stage 2 reordered, CLAUDE.md's description of release builds | A docs-only PR |
| **2-1** | Move the run window and `RunHost` out of `apps/ide` into a package both use (`packages/gubasic_player`, name to decide); the IDE behaves exactly as before | All IDE tests and the widget parity tests pass unchanged; F5 looks the same |
| **2-2** | `apps/player`: a Flutter app that runs one project, full window, with no IDE around it; for now the project is built in. CI builds it for web, macOS and Windows, and reports its size | `flutter run` shows hello as an app of its own; the sizes of the three builds |
| **2-3** | The project bundle: the project's files and pictures in one file with a format version (`formatVersion`, as rule 8 asks), read by the player at start; a newer format than the player knows is refused with a message | The player opens the quiz example from a bundle; a test opens every example |
| **2-4** | Export for the web: File → Export as app… → Web, from the desktop and the web IDE; the template downloaded and kept | A `.zip` that, unzipped and served by any web host (GitHub Pages, a school server), runs the app; checked in Chromium and WebKit |
| **2-5** | Export for Windows | The exported folder runs on the school PC (the author checks; CI checks that the files are complete) |
| **2-6** | Export for macOS, from the macOS IDE, signed again ad-hoc | The exported app opens on the Mac after Open Anyway; `codesign --verify` passes |
| **2-7** | Several forms in the language and the run window: `Form2.Show`, `Hide`, `Unload`, a startup form or `Sub Main` (DESIGN §3.2, §3.3), with parity programs | A two-form example runs with F5 and as an exported app |
| **2-8** | Several forms in the designer and the project files | Adding, renaming and deleting a form in the IDE |

The other stage 2 items of the ROADMAP (`LayoutMode`, `Handles`, `OptionButton`, menus, `Database`, `Http`, `ByRef`) come after these, each planned on its own.

## 6. Questions to decide

| # | Question | Recommended |
|---|---|---|
| 1 | Which way: (A), (B) or (C)? | **(C)**: the player for stage 2, the transpiler planned again later |
| 2 | When does the transpiler come back? | When a real program is too slow in the player, or for extra components and the escape hatch; at the latest at the start of stage 3 |
| 3 | Android in stage 2? (ROADMAP says "four platforms") | **No**: an Android app changed after it is built must be signed again, with Android's own tool (`apksigner`, part of the Android SDK Build Tools: [Android Developers](https://developer.android.com/tools/apksigner)) and a key; it comes with the phone Player in stage 3. Stage 2 is done when one project ships to the web, macOS and Windows |
| 4 | Where do the player templates come from? | Not inside the IDE: downloaded once per version from the GitHub Release or Pages, and kept |
| 5 | macOS export from Windows or the web? | **No** for now: only the macOS IDE can sign the app again |
| 6 | What does an exported app do on a run-time error? | What F5 does: the program ends. The app shows the error (code, message, line) in a dialog and closes when it is dismissed |
| 7 | The app's name, window and icon | The project's name; the startup form's size; GuBASIC's icon. Choosing an icon comes later |
| 8 | How is a web app shared? | A `.zip` to put on any web host, with short steps for GitHub Pages and a school server. A page on GuBASIC's own site that plays a project file comes with stage 3's Publish menu |
| 9 | Several forms: in stage 2? | **Yes**, as their own block after the export (§4) |
| 10 | The package and app names | `packages/gubasic_player` and `apps/player`, the same player that becomes the phone Player in stage 3 |

## 7. Risks

- **macOS:** a signature broken by an added file stops the app; re-signing must cover the whole bundle, and Gatekeeper still asks for Open Anyway, since there is no Developer ID. The project goes inside the app, not next to it, so that the app is one thing to copy.
- **Windows:** an unsigned program from the internet can be warned about by SmartScreen and some antivirus programs; the release notes already say so.
- **Versions:** an app exported by one IDE version and a player of another must not meet unnoticed: the bundle's format version and the player's version are checked, and the IDE downloads the template of its own version.
- **Speed:** heavy loops are slower than in a native app; programs of the size beginners write do not notice it (KNOWN_ISSUES). If one does, that is question 2's trigger.
- **The web app needs a web host:** opening `index.html` straight from the disk may not work in browsers; step 2-4 checks, and the export says how to host it.
- **The source is inside the app:** anyone can read it. The secret-key warning (DESIGN §11) matters more once apps travel.
- **One run window, two apps:** the move in step 2-1 must not change the IDE; its tests are the guard.

## 8. Not now

- The transpiler (question 2), Flutter downloads and GitHub Actions builds of students' apps.
- iOS and Android, app stores, Developer ID signing and notarization (paid accounts).
- Extra pub.dev components and the embedded-Dart escape hatch (stage 3; they need the transpiler).
- The Publish menu (stage 3).
- Choosing an app icon, and sharing a web app by link.
