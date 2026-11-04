import 'dart:io';

/// Writes [json] as [name] in the user's Downloads folder; gives the
/// file's path.
Future<String?> saveResults(String name, String json) async {
  final home = Platform.isWindows
      ? Platform.environment['USERPROFILE']
      : Platform.environment['HOME'];
  final folder = home == null
      ? Directory.current.path
      : '$home${Platform.pathSeparator}Downloads';
  final file = File('$folder${Platform.pathSeparator}$name');
  await file.writeAsString(json);
  return file.path;
}
