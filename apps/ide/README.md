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
  - The first time a project in the Documents, Desktop or Downloads folder is opened, macOS asks whether GuBASIC IDE may use that folder: allow it, or the forms cannot be read (D32).
  - The examples are never overwritten: they can be changed, and Save on one saves a copy. "— Edited" after the project's name means unsaved changes.
- **On the web** (D33), the File menu keeps projects in this browser (Open… lists them; changes are kept automatically) and adds **Download .zip** (⇧⌘E / Ctrl+Shift+E, also a button in the top bar) and **Upload .zip…**. The browser's storage can be cleared, so download a .zip at the end of each lesson; the button stands out while there are changes that were not downloaded. The .zip unpacks to a folder the desktop IDE opens.
- **Form designer** (D34): choose `Form1.form.yaml` in the file list. Choose Button, Label or TextBox in the toolbox and drag on the form, in any direction (a click places the default size); double-click a toolbox item to put one in the middle of the form. Click a control to select it, drag it to move it, and drag its handles to resize it; the handles on the form's right and bottom edges resize the form. ⌘ and an arrow key (Ctrl on Windows) move the selected control, Shift and an arrow key resize it, by 8 pixels with the grid on and 1 without. Delete or Backspace removes it; ⌘Z / ⇧⌘Z (Ctrl+Z / Ctrl+Y) undo and redo; Esc goes back to the pointer. **Grid** turns the 8-pixel grid on and off, and **View form file** shows the file's text. The **Properties** window at the right chooses the form or a control from the list at its top and changes its properties: text as you type, numbers on Enter or when you leave the field; a value that is not valid says why. A control's name can change only while its form's code does not use it; the field says where it is used. In a field, the keys edit the text (⌘Z / Ctrl+Z undoes the text); click the form to use the designer's keys again. The form cannot be changed while a program runs.
- **F5** runs the project, **Shift+F5** stops it. The words follow the system language (English or Korean).
- The example projects are built into the app (`lib/src/project/examples.g.dart`), so the web build needs no files. After changing `examples/`, run `dart run tool/embed_examples.dart`; CI checks it with `--check`.
- `test/widget_parity_test.dart` runs every event script of `test/parity/` through the real run window (DESIGN §9.1).
- **Font:** the IDE uses Noto Sans KR on every platform (D30), from [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk/tree/165c01b46ea533872e002e0785ff17e44f6d97d8/Sans/SubsetOTF/KR) (version 2.004, `NotoSansKR-Regular.otf` and `NotoSansKR-Bold.otf`), under the SIL Open Font License 1.1: [`fonts/OFL.txt`](fonts/OFL.txt).
- The web build serves the engine and the fonts itself (`--no-web-resources-cdn`) and shows "Loading…" ("불러오는 중…" in Korean) until the app's first frame (`web/index.html`).
