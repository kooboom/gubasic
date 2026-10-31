import '../pdf/pdf_document.dart';

/// What a running program needs from the screen. The playground shows
/// these in its Run tab; tests use a fake that records them.
abstract interface class Host {
  /// `Debug.Print`: one line of output.
  void debugPrint(String line);

  /// `MsgBox`: waits until the user closes the message.
  Future<void> msgBox(String prompt, String title);

  /// `InputBox`: the text typed, or "" if the user cancels.
  Future<String> inputBox(String prompt, String title, String defaultValue);

  /// Lets the screen update and the Stop button work. Called by `DoEvents`
  /// and regularly while the program runs; it never changes what the
  /// program computes.
  Future<void> yieldNow();

  /// The saved settings of the program (`GetSetting`), as the text the
  /// interpreter last gave [saveSettings], or null if there are none. The
  /// IDE keeps them for each project, by its name (docs/DESIGN.md D48).
  Future<String?> loadSettings();

  /// `SaveSetting`: keeps [text], all of the program's settings. Throws if
  /// they cannot be kept; the program then stops with R012.
  Future<void> saveSettings(String text);
}

/// A form the program shows (docs/DESIGN.md D88).
class ShownForm {
  const ShownForm(this.name, {this.dialog = false});

  final String name;

  /// Shown by ShowDialog: over the form behind it, which is dimmed.
  final bool dialog;

  @override
  bool operator ==(Object other) =>
      other is ShownForm && other.name == name && other.dialog == dialog;

  @override
  int get hashCode => Object.hash(name, dialog);

  @override
  String toString() => dialog ? '$name (dialog)' : name;
}

/// What a program with forms needs besides [Host]: its forms and their
/// controls (docs/LANGUAGE.md §8, §11). The IDE's run window implements it
/// with gubasic_runtime; tests use a recording fake (testing.dart).
///
/// Forms are named as their files; controls as in the form file, null
/// being the form itself. Properties are named as in their
/// component.yaml, and their values are `int`, `double`, `bool` or
/// `String`. Every form of the project has its properties from the start,
/// shown or not.
abstract interface class FormHost implements Host {
  /// The current value of a property: as the program last set it, or as
  /// the user changed it (the text typed in a TextBox).
  Object getProperty(String form, String? control, String property);

  /// The program sets a property. The interpreter runs the property's
  /// change event itself (TextBox.Changed); the host runs it only for
  /// changes the user makes.
  void setProperty(String form, String? control, String property, Object value);

  /// The forms shown changed (D88): [forms] from the back to the front.
  /// Only the front one takes what the user does; a dialog is shown over
  /// the forms behind it. Called first when the startup form's Form_Load
  /// has finished.
  void showForms(List<ShownForm> forms);

  /// [form] starts again, shown after it was closed (D88): its properties
  /// are as in its form file again, and only its controls are on it.
  void resetForm(String form);

  /// The program puts a control made with New on [form] (D98): [control],
  /// a [component] (`Button`), with [properties] (every stored one). It is
  /// drawn on top of the others of its layer.
  void addControl(String form, String control, String component,
      Map<String, Object> properties);

  /// The program takes [control] off [form] (D98).
  void removeControl(String form, String control);

  /// `PopupMenu` (D106): shows the items of [menu], a menu of [form], and
  /// completes with the name of the item the user chooses, or null for
  /// none. Like MsgBox, it is modal.
  Future<String?> popupMenu(String form, String menu);

  /// The program has ended: close the forms, and close any open dialog as
  /// if it was cancelled.
  void endProgram();
}

/// One choice of an open or save dialog's Filter: `Text files|*.txt`
/// (docs/DESIGN.md D113). [extensions] without the dot, lower case; empty
/// for `*.*`, any file.
class FileFilter {
  const FileFilter(this.label, this.extensions);

  final String label;
  final List<String> extensions;

  @override
  bool operator ==(Object other) =>
      other is FileFilter &&
      other.label == label &&
      other.extensions.join(',') == extensions.join(',');

  @override
  int get hashCode => Object.hash(label, extensions.join(','));

  @override
  String toString() => '$label|${extensions.join(';')}';
}

/// A Filter's text as its choices: `Text files|*.txt;*.log|All|*.*`.
/// A label without patterns is left out.
List<FileFilter> parseFileFilter(String filter) {
  final parts = filter.split('|');
  return [
    for (var i = 0; i + 1 < parts.length; i += 2)
      FileFilter(parts[i].trim(), [
        for (final p in parts[i + 1].split(';'))
          if (p.trim().toLowerCase() case final ext
              when ext.startsWith('*.') && ext != '*.*')
            ext.substring(2),
      ]),
  ];
}

/// Why a file could not be read or written (D113).
enum FileProblemKind {
  /// There is no such file.
  notFound,

  /// On the web: a name no dialog gave in this run.
  notChosen,

  /// No font to write a PDF file with (D117): an app exported before it
  /// used PdfDocument.
  noPdfFont,

  /// Anything else the system said: [FileProblem.detail].
  other,
}

class FileProblem implements Exception {
  const FileProblem(this.kind, [this.detail = '']);

  final FileProblemKind kind;
  final String detail;
}

/// What a program's files need from where it runs (docs/DESIGN.md D113):
/// the open and save dialogs, and the files' bytes. The IDE and the apps
/// have one; where there is none (the playground), the File functions and
/// the dialogs stop the program with R030.
abstract interface class FileHost {
  /// OpenFileDialog: the file the user chooses, or null when cancelled.
  Future<String?> chooseOpenFile(
      String title, List<FileFilter> filters, String fileName);

  /// SaveFileDialog: where the user chooses to save, or null.
  Future<String?> chooseSaveFile(
      String title, List<FileFilter> filters, String fileName);

  /// The bytes of the file [path]; throws a [FileProblem].
  Future<List<int>> readFile(String path);

  /// Writes [bytes] to [path], after what it has when [append]; throws a
  /// [FileProblem].
  Future<void> writeFile(String path, List<int> bytes, {bool append = false});

  /// Whether the file [path] is there.
  Future<bool> fileExists(String path);

  /// Writes [document] to [path] as a PDF file (D117), with `pdfBytes` and
  /// the font the IDE and the apps carry for it; throws a [FileProblem].
  Future<void> writePdf(String path, GbPdfDocument document);
}
