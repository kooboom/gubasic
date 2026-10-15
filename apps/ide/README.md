# GuBASIC IDE

[한국어](README.ko.md)

The IDE: for now it opens the example projects in `examples/` (`hello`; `typing`, a TextBox to try an input method with) and runs them in a run window (docs/DESIGN.md §2.3). The menu at the top right switches between them. It runs on macOS, on Windows and on the web.

```sh
flutter run -d macos     # or -d windows, -d chrome
```

- **F5** runs the project, **Shift+F5** stops it. The words follow the system language (English or Korean).
- The example projects are built into the app (`lib/src/project/examples.g.dart`), so the web build needs no files. After changing `examples/`, run `dart run tool/embed_examples.dart`; CI checks it with `--check`.
- `test/widget_parity_test.dart` runs every event script of `test/parity/` through the real run window (DESIGN §9.1).
