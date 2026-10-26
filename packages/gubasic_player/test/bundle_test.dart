import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// The project bundle (D83): a `.gbz` file, a zip with `bundle.yaml` and
/// the project's files, as many forms as it has.
void main() {
  final twoForms = {
    'Quiz.gbproj':
        'formatVersion: 2\nid: k3x9q2m7a1b4c8d0\nname: Quiz\nstartup: Form1\n'
        'forms:\n  - Form1\n  - Form2\npictures:\n  - star.png\n',
    'Form1.form.yaml': 'formatVersion: 1\nproperties:\n  Caption: One\n',
    'Form1.gbas': "' one\n",
    'Form2.form.yaml': 'formatVersion: 1\nproperties:\n  Caption: Two\n',
    'Form2.gbas': "' two\n",
  };
  final star = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);

  test('a bundle reads back as it was written, every form and picture', () {
    final bytes = ProjectBundle(
      id: 'k3x9q2m7a1b4c8d0',
      name: 'Quiz',
      files: twoForms,
      pictures: {'star.png': star},
    ).encode();
    final read = ProjectBundle.decode(bytes);
    expect(read.id, 'k3x9q2m7a1b4c8d0');
    expect(read.name, 'Quiz');
    expect(read.madeBy, gubasicVersion);
    expect(read.files, twoForms);
    expect(read.pictures['star.png'], star);
    final project = readProjectFile(read.files['Quiz.gbproj']!).project;
    expect(project.forms, ['Form1', 'Form2']);
    expect(Project.read(read.files).canRun, isTrue);
  });

  test('its manifest names the layout, the GuBASIC, the ID and the name', () {
    final archive = ZipDecoder().decodeBytes(
      ProjectBundle(
        id: 'k3x9q2m7a1b4c8d0',
        name: '퀴즈',
        files: twoForms,
      ).encode(),
    );
    expect(
      utf8.decode(archive.findFile('bundle.yaml')!.content),
      'formatVersion: 1\ngubasic: "$gubasicVersion"\n'
      'id: k3x9q2m7a1b4c8d0\nname: "퀴즈"\n',
    );
    expect(archive.findFile('project/Form2.gbas'), isNotNull);
  });

  Uint8List zip(Map<String, String> entries) {
    final a = Archive();
    for (final MapEntry(:key, :value) in entries.entries) {
      a.add(ArchiveFile.bytes(key, utf8.encode(value)));
    }
    return Uint8List.fromList(ZipEncoder().encodeBytes(a));
  }

  test('a newer layout is refused, saying which GuBASIC made it', () {
    expect(
      () => ProjectBundle.decode(
        zip({
          'bundle.yaml':
              'formatVersion: 2\ngubasic: "0.5.0"\nid: k3x9q2m7a1b4c8d0\n',
          'project/A.gbproj': 'formatVersion: 1\nforms:\n  - F\n',
        }),
      ),
      throwsA(isA<BundleTooNew>().having((p) => p.madeBy, 'madeBy', '0.5.0')),
    );
  });

  test('what is not a bundle is said to be not one', () {
    for (final bytes in [
      utf8.encode('hello'),
      zip({'project/A.gbproj': 'x'}),
      zip({'bundle.yaml': 'formatVersion: 1\nid: k3x9q2m7a1b4c8d0\n'}),
      zip({
        'bundle.yaml': 'formatVersion: 1\nid: BAD\n',
        'project/A.gbproj': 'x',
      }),
    ]) {
      expect(() => ProjectBundle.decode(bytes), throwsA(isA<NotABundle>()));
    }
  });

  test('an exported app keeps its settings under its app ID', () async {
    final store = GbMemorySettings();
    final host = RunHost(
      readFormFile('formatVersion: 1\n', name: 'Form1').form,
      project: 'Quiz',
      settingsKey: 'k3x9q2m7a1b4c8d0',
      settings: store,
    );
    await host.saveSettings('best=3');
    expect(store.values, {'k3x9q2m7a1b4c8d0': 'best=3'});
    expect(
      RunHost(
        readFormFile('formatVersion: 1\n', name: 'Form1').form,
        project: 'Quiz',
      ).settingsKey,
      'Quiz',
      reason: 'in the IDE, the project name (D48)',
    );
  });
}
