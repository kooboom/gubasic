import 'package:flutter/foundation.dart';

import 'package:gubasic_lang/gubasic_lang.dart' show soundNamed;
import 'package:gubasic_player/gubasic_player.dart';

import 'project_pictures.dart';
import 'project_sounds.dart';

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

/// A project kept in the web browser under [name] (D33).
class BrowserLocation extends ProjectLocation {
  const BrowserLocation(this.name);

  final String name;
}

/// A project on disk: the folder its `.gbproj` file is in.
class FolderLocation extends ProjectLocation {
  const FolderLocation(this.path);

  final String path;
}

/// The project open in the IDE: its files as they are now, and as they
/// were last read or saved, so that the IDE knows what is unsaved. Its
/// pictures (D51) are kept apart from the text files, by the names its
/// `.gbproj` file gives them.
class OpenProject extends ChangeNotifier {
  OpenProject(
    this._location,
    Map<String, String> files, {
    Map<String, Uint8List> pictures = const {},
    Map<String, Uint8List> sounds = const {},
  }) : _files = Map.of(files),
       _sounds = Map.of(sounds),
       _savedSounds = Map.of(sounds),
       _saved = Map.of(files),
       _pictures = Map.of(pictures),
       _savedPictures = Map.of(pictures);

  ProjectLocation _location;
  final Map<String, String> _files;
  Map<String, String> _saved;
  final Map<String, Uint8List> _pictures;
  Map<String, Uint8List> _savedPictures;

  /// Sound name → bytes (D138), now and as last read or saved.
  final Map<String, Uint8List> _sounds;
  Map<String, Uint8List> _savedSounds;
  Project? _project;

  /// Counts the changes to [pictures], so that views showing them know
  /// when to draw them again.
  int get picturesVersion => _picturesVersion;
  var _picturesVersion = 0;

  ProjectLocation get location => _location;
  bool get isExample => _location is ExampleLocation;

  /// File name → text, as it is now.
  Map<String, String> get files => Map.unmodifiable(_files);

  /// File name → text, as it was last read or saved.
  Map<String, String> get saved => Map.unmodifiable(_saved);

  /// Picture name → bytes, as it is now.
  Map<String, Uint8List> get pictures => Map.unmodifiable(_pictures);

  /// Picture name → bytes, as they were last read or saved.
  Map<String, Uint8List> get savedPictures => Map.unmodifiable(_savedPictures);

  /// Sound name → bytes (D138), as it is now.
  Map<String, Uint8List> get sounds => Map.unmodifiable(_sounds);

  /// Sound name → bytes, as they were last read or saved.
  Map<String, Uint8List> get savedSounds => Map.unmodifiable(_savedSounds);

  /// The project read from [files].
  Project get project => _project ??= Project.read(_files);

  /// Whether a file or a picture differs from what was last read or saved.
  bool get isDirty =>
      !mapEquals(_files, _saved) ||
      !samePictures(_pictures, _savedPictures) ||
      !sameSounds(_sounds, _savedSounds);

  /// Adds picture [name] with [bytes], or replaces the picture of that
  /// name in any case, which keeps its spelling; the `.gbproj` file lists
  /// it. [checkPicture] must have found no problem.
  void setPicture(String name, Uint8List bytes) {
    final names = _pictures.keys.toList();
    final existing = pictureNamed(names, name);
    if (existing == null) {
      names.add(name);
      _files.addAll(withPictureList(_files, names));
    }
    _pictures[existing ?? name] = bytes;
    _picturesChanged();
  }

  /// Takes picture [name] out of the project and its `.gbproj` file.
  void removePicture(String name) {
    if (_pictures.remove(name) == null) return;
    _files.addAll(withPictureList(_files, _pictures.keys.toList()));
    _picturesChanged();
  }

  /// Adds sound [name] with [bytes], or replaces the sound of that name
  /// in any case, which keeps its spelling; the `.gbproj` file lists it
  /// (D138). [checkSound] must have found no problem.
  void setSound(String name, Uint8List bytes) {
    final names = _sounds.keys.toList();
    final existing = soundNamed(names, name);
    if (existing == null) {
      names.add(name);
      _files.addAll(withSoundList(_files, names));
    }
    _sounds[existing ?? name] = bytes;
    _picturesChanged();
  }

  /// Takes sound [name] out of the project and its `.gbproj` file.
  void removeSound(String name) {
    if (_sounds.remove(name) == null) return;
    _files.addAll(withSoundList(_files, _sounds.keys.toList()));
    _picturesChanged();
  }

  void _picturesChanged() {
    _picturesVersion++;
    _project = null;
    notifyListeners();
  }

  /// Changes the text of [file].
  void setFile(String file, String text) {
    if (_files[file] == text) return;
    _files[file] = text;
    _project = null;
    notifyListeners();
  }

  /// Changes the files to [files]: those it leaves out are taken out of
  /// the project, as a form deleted or renamed (D88); saving deletes them
  /// from the disk.
  void replaceFiles(Map<String, String> files) {
    if (mapEquals(_files, files)) return;
    _files
      ..clear()
      ..addAll(files);
    _project = null;
    notifyListeners();
  }

  /// Records that [file] was saved with [text], alone: the other files'
  /// changes stay unsaved.
  void markFileSaved(String file, String text) {
    _saved = {..._saved, file: text};
    notifyListeners();
  }

  /// Records that [files] and [pictures], as they were when a save that
  /// took a while started, were saved: changes made since stay unsaved.
  void markSavedAs(
    Map<String, String> files,
    Map<String, Uint8List> pictures, [
    Map<String, Uint8List>? sounds,
  ]) {
    _saved = Map.of(files);
    _savedPictures = Map.of(pictures);
    _savedSounds = Map.of(sounds ?? _sounds);
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
    _savedPictures = Map.of(_pictures);
    _savedSounds = Map.of(_sounds);
    notifyListeners();
  }
}
