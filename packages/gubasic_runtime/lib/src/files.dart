import 'files_io.dart' if (dart.library.js_interop) 'files_web.dart';

/// One choice of an open or save dialog: its label and its extensions,
/// without the dot; none for any file (docs/DESIGN.md D113).
typedef GbFileFilter = ({String label, List<String> extensions});

/// Why a file could not be read or written.
enum GbFileErrorKind { notFound, notChosen, other }

class GbFileError implements Exception {
  const GbFileError(this.kind, [this.detail = '']);

  final GbFileErrorKind kind;
  final String detail;
}

/// The files of a running program (D113). On the desktop the system's open
/// and save dialogs and real paths. On the web, which has no paths, a file
/// is known by the name of one the user chose with the open dialog, or one
/// the program saved, in this run: reading another is
/// [GbFileErrorKind.notChosen], and saving downloads the file under its
/// name.
abstract class GbFiles {
  factory GbFiles() => createGbFiles();

  /// Whether a save dialog of the system's is there; on the web the app
  /// asks for the name itself.
  bool get hasSaveDialog;

  /// The file the user chooses to open, or null.
  Future<String?> chooseOpen(
    String title,
    List<GbFileFilter> filters,
    String fileName,
  );

  /// Where the user chooses to save, or null. Only with [hasSaveDialog].
  Future<String?> chooseSave(
    String title,
    List<GbFileFilter> filters,
    String fileName,
  );

  /// Marks [name] as saved to on the web, as a save dialog would.
  void allowSave(String name);

  /// The bytes of [path]; throws a [GbFileError].
  Future<List<int>> read(String path);

  /// Writes [bytes] to [path], after what it has when [append]; throws a
  /// [GbFileError].
  Future<void> write(String path, List<int> bytes, {bool append = false});

  /// Whether [path] is there; on the web, whether it is one the user chose
  /// or the program saved.
  Future<bool> exists(String path);
}
