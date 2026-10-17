import 'dart:io';

/// Where the recording was made: the desktop app and its system.
Map<String, Object?> recordedOn() => {
  'userAgent': 'Flutter desktop app',
  'platform': Platform.operatingSystem,
  'osVersion': Platform.operatingSystemVersion,
};

/// Writes [json] to `ime-log-<system>-app.json` in the user's Downloads
/// folder; gives the file's path.
Future<String> saveLog(String json) async {
  final home = Platform.isWindows
      ? Platform.environment['USERPROFILE']
      : Platform.environment['HOME'];
  final folder = Directory(
    home == null
        ? Directory.current.path
        : '$home${Platform.pathSeparator}Downloads',
  );
  final os = Platform.isMacOS ? 'macos' : Platform.operatingSystem;
  final file = File(
    '${folder.path}${Platform.pathSeparator}ime-log-$os-app.json',
  );
  await file.writeAsString(json);
  return file.path;
}
