# GuBASIC IDE

[한국어](README.ko.md)

The IDE: it opens the example projects in `examples/` (`hello`; `typing`, a TextBox to try an input method with) and projects on disk, and runs them in a run window (docs/DESIGN.md §2.3). The menu at the top right switches between them. It runs on macOS, on Windows and on the web.

```sh
flutter run -d macos     # or -d windows, -d chrome
flutter build web --no-web-resources-cdn   # as CI builds it (D30)
```

- **File**, at the top left (macOS and Windows; D32):
  - **Open…** (⌘O / Ctrl+O) opens a project by its `.gbproj` file.
  - **Save** (⌘S / Ctrl+S) saves the project: every file of it that changed, `.gbproj`, `.form.yaml` and `.gbas` alike.
  - **Save As…** (⇧⌘S / Ctrl+Shift+S) copies the whole project into a new folder: choose a place and a name, and the IDE makes `NAME/NAME.gbproj` and the forms' files. It does not ask file by file as Visual Basic 6 did.
  - A form's `.form.yaml` and `.gbas` are one pair with one name: they are always saved, and renamed, together. Saving one form on its own is decided with multiple forms (stage 2).
  - The examples are read-only: Save on one saves a copy. "— Edited" after the project's name means unsaved changes.
- **On the web** (D33), the File menu keeps projects in this browser (Open… lists them; changes are kept automatically) and adds **Download .zip** (⇧⌘E / Ctrl+Shift+E, also a button in the top bar) and **Upload .zip…**. The browser's storage can be cleared, so download a .zip at the end of each lesson; the button stands out while there are changes that were not downloaded. The .zip unpacks to a folder the desktop IDE opens.
- **F5** runs the project, **Shift+F5** stops it. The words follow the system language (English or Korean).
- The example projects are built into the app (`lib/src/project/examples.g.dart`), so the web build needs no files. After changing `examples/`, run `dart run tool/embed_examples.dart`; CI checks it with `--check`.
- `test/widget_parity_test.dart` runs every event script of `test/parity/` through the real run window (DESIGN §9.1).
- **Font:** the IDE uses Noto Sans KR on every platform (D30), from [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk/tree/165c01b46ea533872e002e0785ff17e44f6d97d8/Sans/SubsetOTF/KR) (version 2.004, `NotoSansKR-Regular.otf` and `NotoSansKR-Bold.otf`), under the SIL Open Font License 1.1: [`fonts/OFL.txt`](fonts/OFL.txt).
- The web build serves the engine and the fonts itself (`--no-web-resources-cdn`) and shows "Loading…" ("불러오는 중…" in Korean) until the app's first frame (`web/index.html`).
