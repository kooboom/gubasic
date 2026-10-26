import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/folders.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import 'support/memory_folders.dart';

void main() {
  final hello = exampleProjects['hello']!;

  group('readProject', () {
    test('reads the .gbproj file and the files of its forms', () async {
      final fs = MemoryFolders()
        ..add('/p', {...hello, 'notes.txt': 'not part of it'});
      final read = await readProject(fs, '/p/Hello.gbproj');
      expect(read.files, hello);
      expect(read.missing, isEmpty);
    });

    test('names the files the .gbproj lists that are not there', () async {
      final fs = MemoryFolders()..add('/p', {...hello}..remove('Form1.gbas'));
      final read = await readProject(fs, '/p/Hello.gbproj');
      expect(read.missing, ['Form1.gbas']);
      expect(
        read.files.keys,
        unorderedEquals(['Hello.gbproj', 'Form1.form.yaml']),
      );
    });

    test('the chosen one of two projects in a folder', () async {
      final fs = MemoryFolders()
        ..add('/p', {
          ...hello,
          'Other.gbproj': 'formatVersion: 1\nname: Other\nforms:\n  - Form1\n',
        });
      final read = await readProject(fs, '/p/Other.gbproj');
      expect(
        read.files.keys,
        unorderedEquals(['Other.gbproj', 'Form1.form.yaml', 'Form1.gbas']),
      );
    });

    test('a .gbproj file that is gone', () async {
      final fs = MemoryFolders()..add('/p', {});
      expect(
        readProject(fs, '/p/Hello.gbproj'),
        throwsA(
          isA<MissingProjectFile>().having(
            (p) => p.file,
            'file',
            'Hello.gbproj',
          ),
        ),
      );
    });
  });

  group('saving', () {
    test('only changed files are written', () async {
      final fs = MemoryFolders()..add('/p', hello);
      await writeChanged(fs, '/p', {
        ...hello,
        'Form1.gbas': "' changed\n",
      }, hello);
      expect(fs.written, ['/p/Form1.gbas']);
      expect(fs.files['/p/Form1.gbas'], "' changed\n");
    });

    test('a file changed on disk since it was read is found', () async {
      final fs = MemoryFolders()..add('/p', hello);
      fs.files['/p/Form1.gbas'] = "' by another program\n";
      final files = {...hello, 'Form1.gbas': "' mine\n"};
      expect(await changedOnDisk(fs, '/p', files, hello), ['Form1.gbas']);
      expect(
        await changedOnDisk(fs, '/p', hello, hello),
        isEmpty,
        reason: 'unchanged files are not looked at',
      );
    });

    test('a file deleted on disk counts as changed', () async {
      final fs = MemoryFolders()..add('/p', hello);
      fs.files.remove('/p/Form1.gbas');
      final files = {...hello, 'Form1.gbas': "' mine\n"};
      expect(await changedOnDisk(fs, '/p', files, hello), ['Form1.gbas']);
    });

    test('a write that fails names the file', () async {
      final fs = MemoryFolders()..add('/p', hello);
      fs.failing.add('/p/Form1.gbas');
      expect(
        writeChanged(fs, '/p', {...hello, 'Form1.gbas': 'x'}, hello),
        throwsA(
          isA<FileFailed>()
              .having((p) => p.file, 'file', 'Form1.gbas')
              .having((p) => p.reason, 'reason', 'disk full')
              .having((p) => p.writing, 'writing', true),
        ),
      );
    });
  });

  group('saveCopy', () {
    test('makes NAME/NAME.gbproj with the new name', () async {
      final fs = MemoryFolders()..folders.add('/home');
      final (folder, files) = await saveCopy(fs, '/home', 'My Quiz', hello);
      expect(folder, '/home/My Quiz');
      expect(
        files.keys,
        unorderedEquals(['My Quiz.gbproj', 'Form1.form.yaml', 'Form1.gbas']),
      );
      expect(fs.files['/home/My Quiz/My Quiz.gbproj'], '''
formatVersion: 1
name: My Quiz
startup: Form1
forms:
  - Form1
''');
      expect(fs.files['/home/My Quiz/Form1.gbas'], hello['Form1.gbas']);
      expect(fs.folders, contains('/home/My Quiz'));
    });

    test('keeps a .gbproj file with errors as it is', () async {
      final fs = MemoryFolders()..folders.add('/home');
      final broken = {...hello, 'Hello.gbproj': 'formatVersion: 1\nname: [\n'};
      final (_, files) = await saveCopy(fs, '/home', 'Copy', broken);
      expect(files['Copy.gbproj'], 'formatVersion: 1\nname: [\n');
    });

    test('never writes into a folder that is there', () async {
      final fs = MemoryFolders()..add('/home/Hello', {'keep.txt': 'mine'});
      expect(
        saveCopy(fs, '/home', 'Hello', hello),
        throwsA(isA<FolderExists>()),
      );
      expect(fs.written, isEmpty);
    });
  });

  test('a copy is another app: an app ID is replaced by a new one, and a '
      'project without one gets none (D83)', () {
    final withId = {
      ...hello,
      'Hello.gbproj':
          'formatVersion: 1\nid: k3x9q2m7a1b4c8d0\nname: Hello\n'
          'forms:\n  - Form1\n',
    };
    final copy = readProjectFile(renameProject(withId, 'Copy')['Copy.gbproj']!)
        .project;
    expect(copy.name, 'Copy');
    expect(copy.id, isNotNull);
    expect(copy.id, isNot('k3x9q2m7a1b4c8d0'));
    expect(isProjectId(copy.id!), isTrue);
    expect(
      readProjectFile(renameProject(hello, 'Copy')['Copy.gbproj']!).project.id,
      isNull,
    );
  });

  test('project names', () {
    for (final name in ['Hello', '내 퀴즈', 'quiz-2', 'quiz_2']) {
      expect(isUsableProjectName(name), isTrue, reason: name);
    }
    for (final name in [
      '',
      ' lead',
      'trail ',
      '.hidden',
      'end.',
      'v1.2',
      'MyHello.band',
      'a/b',
      r'a\b',
      'a:b',
      'a*b',
      'a?b',
      'a"b',
      'a<b',
      'a>b',
      'a|b',
      'tab\there',
    ]) {
      expect(isUsableProjectName(name), isFalse, reason: name);
    }
  });
}
