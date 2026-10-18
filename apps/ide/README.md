# GuBASIC IDE

[한국어](README.ko.md)

The IDE: it opens the example projects in `examples/` (`hello`; `typing`, a TextBox to try an input method with; `quiz`, a small quiz with a ListBox and a CheckBox that keeps its best score with `SaveSetting`) and projects on disk, and runs them in a run window (docs/DESIGN.md §2.3). The menu at the top right switches between them. It runs on macOS, on Windows and on the web.

```sh
flutter run -d macos     # or -d windows, -d chrome
flutter build web --no-web-resources-cdn   # as CI builds it (D30)
dart run tool/web_load_sizes.dart          # the sizes for "Loading… 37%" (D43)
```

- **File**, at the top left (macOS and Windows; D32):
  - **Open…** (⌘O / Ctrl+O) opens a project by its `.gbproj` file.
  - **Save** (⌘S / Ctrl+S) saves the project: every file of it that changed, `.gbproj`, `.form.yaml` and `.gbas` alike.
  - **Save As…** (⇧⌘S / Ctrl+Shift+S) copies the whole project into a new folder: choose a place and a name, and the IDE makes `NAME/NAME.gbproj` and the forms' files. It does not ask file by file as Visual Basic 6 did.
  - A form's `.form.yaml` and `.gbas` are one pair with one name: they are always saved, and renamed, together. Saving one form on its own is decided with multiple forms (stage 2).
  - The first time a project in the Documents, Desktop or Downloads folder is opened, macOS asks whether GuBASIC IDE may use that folder: allow it, or the forms cannot be read (D32).
  - The examples are never overwritten: they can be changed, and Save on one saves a copy. "— Edited" after the project's name means unsaved changes.
- **Clear Saved Settings…** (File menu) forgets what the open project's program saved with `SaveSetting`. Settings are kept by the project's name, outside its files: in the IDE's user defaults on macOS, in `%APPDATA%\Jungmo Gu\GuBASIC IDE` on Windows, in the browser on the web (D48).
- **On the web** at [kooboom.github.io/gubasic/ide](https://kooboom.github.io/gubasic/ide/), next to the playground (E1e; File → Open the Playground goes there) (D33), the File menu keeps projects in this browser (Open… lists them; changes are kept automatically) and adds **Download .zip** (⇧⌘E / Ctrl+Shift+E, also a button in the top bar) and **Upload .zip…**. The browser's storage can be cleared, so download a .zip at the end of each lesson; the button stands out while there are changes that were not downloaded. The .zip unpacks to a folder the desktop IDE opens.
- **Form designer** (D34): choose `Form1.form.yaml` in the file list. Choose Button, Label, TextBox, CheckBox or ListBox in the toolbox and drag on the form, in any direction (a click places the default size); double-click a toolbox item to put one in the middle of the form. Click a control to select it, drag it to move it, and drag its handles to resize it; the handles on the form's right and bottom edges resize the form. ⌘ and an arrow key (Ctrl on Windows) move the selected control, Shift and an arrow key resize it, by 8 pixels with the grid on and 1 without. Delete or Backspace removes it; ⌘Z / ⇧⌘Z (Ctrl+Z / Ctrl+Y) undo and redo; Esc goes back to the pointer. **Grid** turns the 8-pixel grid on and off, and **View form file** shows the file's text. The **Properties** window at the right chooses the form or a control from the list at its top and changes its properties: text as you type, numbers on Enter or when you leave the field; a value that is not valid says why. Renaming a control renames it in its form's code too, and the field says which lines (D39). In a field, the keys edit the text (⌘Z / Ctrl+Z undoes the text); click the form to use the designer's keys again. The form cannot be changed while a program runs.
- **F5** runs the project, **Shift+F5** stops it. The words follow the system language (English or Korean).
- The example projects are built into the app (`lib/src/project/examples.g.dart`), so the web build needs no files. After changing `examples/`, run `dart run tool/embed_examples.dart`; CI checks it with `--check`.
- `test/widget_parity_test.dart` runs every event script of `test/parity/` through the real run window (DESIGN §9.1).
- **Handlers** (D38): double-click a control in the designer (or the empty form) to open its default event's handler in the code editor, added if it is not there; the Object and Event lists above the code go to or add any handler.
- **Designer** (D41, D42): a Label is drawn under the other controls. Tab / Shift+Tab choose controls, Option-click (Alt-click) the one underneath; ⌘J / ⌘K (Ctrl+J / Ctrl+K) bring to the front or send to the back. A right click opens the designer's menu.
- **Errors** (D40): click an error with a line in the output to go to that line of the code; the line where a run stopped with an error is marked until the code changes.
- **Code editor** (D36): choose `Form1.gbas`. Keywords, strings, comments and controls are coloured; Tab / Shift+Tab indent, Enter keeps the indentation, ⌘Z / Ctrl+Z undoes. A project opens on its form; the code font, D2Coding, is fetched the first time the code editor opens.
- **Code font:** D2Coding 1.3.2 Regular, from [naver/d2codingfont](https://github.com/naver/d2codingfont/releases/tag/VER1.3.2) (`D2Coding-Ver1.3.2-20180524.ttf`, sha256 `8b1b23e5…711aba84`), under the SIL Open Font License 1.1: [`fonts/d2coding/OFL.txt`](fonts/d2coding/OFL.txt). It is an asset loaded on first use, not a declared font (D36).
- **Font:** the IDE uses Noto Sans KR on every platform (D30), from [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk/tree/165c01b46ea533872e002e0785ff17e44f6d97d8/Sans/SubsetOTF/KR) (version 2.004, `NotoSansKR-Regular.otf` and `NotoSansKR-Bold.otf`), under the SIL Open Font License 1.1: [`fonts/OFL.txt`](fonts/OFL.txt).
- The web build serves the engine and the fonts itself (`--no-web-resources-cdn`) and shows "Loading…" ("불러오는 중…" in Korean) until the app's first frame (`web/index.html`).
