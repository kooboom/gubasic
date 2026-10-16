# GuBASIC IDE

[한국어](README.ko.md)

The IDE: it opens the example projects in `examples/` (`hello`; `typing`, a TextBox to try an input method with) and project folders on disk, and runs them in a run window (docs/DESIGN.md §2.3). The menu at the top right switches between them. It runs on macOS, on Windows and on the web.

```sh
flutter run -d macos     # or -d windows, -d chrome
flutter build web --no-web-resources-cdn   # as CI builds it (D30)
```

- **File** (macOS and Windows): **Open…** (⌘O / Ctrl+O) opens a project folder, a folder with one `.gbproj` file; **Save** (⌘S / Ctrl+S) saves into it; **Save As…** (⇧⌘S / Ctrl+Shift+S) saves a copy in a new folder. The examples are read-only: Save on one saves a copy. A • after the project's name means unsaved changes (D32).
- **F5** runs the project, **Shift+F5** stops it. The words follow the system language (English or Korean).
- The example projects are built into the app (`lib/src/project/examples.g.dart`), so the web build needs no files. After changing `examples/`, run `dart run tool/embed_examples.dart`; CI checks it with `--check`.
- `test/widget_parity_test.dart` runs every event script of `test/parity/` through the real run window (DESIGN §9.1).
- **Font:** the IDE uses Noto Sans KR on every platform (D30), from [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk/tree/165c01b46ea533872e002e0785ff17e44f6d97d8/Sans/SubsetOTF/KR) (version 2.004, `NotoSansKR-Regular.otf` and `NotoSansKR-Bold.otf`), under the SIL Open Font License 1.1: [`fonts/OFL.txt`](fonts/OFL.txt).
- The web build serves the engine and the fonts itself (`--no-web-resources-cdn`) and shows "Loading…" ("불러오는 중…" in Korean) until the app's first frame (`web/index.html`).
