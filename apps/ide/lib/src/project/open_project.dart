import 'package:flutter/foundation.dart';

import 'project.dart';

/// Where an open project's files come from.
sealed class ProjectLocation {
  const ProjectLocation();
}

/// A project built into the IDE (`examples/`): it can be looked at and
/// run, and saved only as a copy (D32).
class ExampleLocation extends ProjectLocation {
  const ExampleLocation(this.name);

  final String name;
}

/// A project folder on disk.
class FolderLocation extends ProjectLocation {
  const FolderLocation(this.path);

  final String path;
}

/// The project open in the IDE: its files as they are now, and as they
/// were last read or saved, so that the IDE knows what is unsaved.
class OpenProject extends ChangeNotifier {
  OpenProject(this._location, Map<String, String> files)
    : _files = Map.of(files),
      _saved = Map.of(files);

  ProjectLocation _location;
  final Map<String, String> _files;
  Map<String, String> _saved;
  Project? _project;

  ProjectLocation get location => _location;
  bool get isExample => _location is ExampleLocation;

  /// File name → text, as it is now.
  Map<String, String> get files => Map.unmodifiable(_files);

  /// File name → text, as it was last read or saved.
  Map<String, String> get saved => Map.unmodifiable(_saved);

  /// The project read from [files].
  Project get project => _project ??= Project.read(_files);

  /// Whether a file differs from what was last read or saved.
  bool get isDirty => !mapEquals(_files, _saved);

  /// Changes the text of [file].
  void setFile(String file, String text) {
    if (_files[file] == text) return;
    _files[file] = text;
    _project = null;
    notifyListeners();
  }

  /// Records that the files were saved, into [location] when they were
  /// saved as a copy, under the names of [files].
  void markSaved({ProjectLocation? location, Map<String, String>? files}) {
    if (location != null) _location = location;
    if (files != null) {
      _files
        ..clear()
        ..addAll(files);
      _project = null;
    }
    _saved = Map.of(_files);
    notifyListeners();
  }
}
