import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/project_zip.dart';

/// A .zip of [entries]: path → text.
List<int> zipOf(Map<String, String> entries) {
  final archive = Archive();
  for (final MapEntry(:key, :value) in entries.entries) {
    archive.add(ArchiveFile.bytes(key, utf8.encode(value)));
  }
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  final hello = exampleProjects['hello']!;

  test('a project goes into NAME/ and comes back', () {
    final bytes = zipProject('Hello', hello);
    final names = ZipDecoder().decodeBytes(bytes).files.map((f) => f.name);
    expect(
      names,
      unorderedEquals([
        'Hello/Hello.gbproj',
        'Hello/Form1.form.yaml',
        'Hello/Form1.gbas',
      ]),
    );
    final back = unzipProject(bytes);
    expect(back.name, 'Hello');
    expect(back.files, hello);
    expect(back.ignored, isEmpty);
  });

  test('files at the top of the .zip', () {
    expect(unzipProject(zipOf(hello)).files, hello);
  });

  test('Korean text and a Korean folder name', () {
    final files = {...hello, 'Form1.gbas': "' 안녕하세요\n"};
    final back = unzipProject(
      zipOf({
        for (final MapEntry(:key, :value) in files.entries) '내 퀴즈/$key': value,
      }),
    );
    expect(back.files['Form1.gbas'], "' 안녕하세요\n");
  });

  test('other files are left out and named; system files silently', () {
    final back = unzipProject(
      zipOf({
        for (final MapEntry(:key, :value) in hello.entries) 'Hello/$key': value,
        'Hello/notes.txt': 'mine',
        'Hello/.DS_Store': 'x',
        '__MACOSX/Hello/._Form1.gbas': 'x',
      }),
    );
    expect(back.files, hello);
    expect(back.ignored, ['Hello/notes.txt']);
  });

  group('refused', () {
    void refuses(Map<String, String> entries, Matcher problem) =>
        expect(() => unzipProject(zipOf(entries)), throwsA(problem));

    for (final path in [
      '../Form1.gbas',
      'Hello/../../Form1.gbas',
      r'Hello\..\Form1.gbas',
      '/etc/Form1.gbas',
      r'C:\Form1.gbas',
      'C:Form1.gbas',
    ]) {
      test('an unsafe path: $path', () {
        refuses(
          {...hello, path: 'x'},
          isA<UnsafeZipPath>().having(
            (p) => p.path.replaceAll(r'\', '/'),
            'path (the decoder writes \\ as /)',
            path.replaceAll(r'\', '/'),
          ),
        );
      });
    }

    test('an unsafe path is refused even when the file would be left out', () {
      refuses({...hello, '../notes.txt': 'x'}, isA<UnsafeZipPath>());
    });

    test('files deeper than one folder', () {
      refuses({
        for (final MapEntry(:key, :value) in hello.entries) 'a/b/$key': value,
      }, isA<ZipLayout>());
    });

    test('files in two folders', () {
      refuses({
        'a/Hello.gbproj': hello['Hello.gbproj']!,
        'b/Form1.gbas': hello['Form1.gbas']!,
      }, isA<ZipLayout>());
    });

    test('no .gbproj file', () {
      refuses({
        'Form1.gbas': '',
      }, isA<ZipProjectFiles>().having((p) => p.found, 'found', isEmpty));
    });

    test('two .gbproj files', () {
      refuses({
        ...hello,
        'Other.gbproj': '',
      }, isA<ZipProjectFiles>().having((p) => p.found, 'found', hasLength(2)));
    });

    test('not UTF-8 text', () {
      final archive = Archive()
        ..add(ArchiveFile.bytes('Hello.gbproj', utf8.encode('x')))
        ..add(ArchiveFile.bytes('Form1.gbas', [0xff, 0xfe, 0x00]));
      expect(
        () => unzipProject(ZipEncoder().encodeBytes(archive)),
        throwsA(isA<ZipNotText>().having((p) => p.file, 'file', 'Form1.gbas')),
      );
    });

    test('not a .zip', () {
      expect(
        () => unzipProject(utf8.encode('formatVersion: 1\n')),
        throwsA(isA<NotAZip>()),
      );
    });

    test('a .zip larger than 1 MB', () {
      expect(
        () => unzipProject(List.filled(maxZipBytes + 1, 0)),
        throwsA(isA<ZipTooLarge>()),
      );
    });

    test('more than 100 GuBASIC files', () {
      refuses({
        ...hello,
        for (var i = 0; i < maxZipFiles; i++) 'Form$i.gbas': '',
      }, isA<ZipTooLarge>());
    });

    test('more than 2 MB unpacked, though small packed', () {
      final big = 'x' * (maxUnpackedBytes + 1);
      final bytes = zipOf({...hello, 'Form1.gbas': big});
      expect(bytes.length, lessThan(maxZipBytes));
      expect(() => unzipProject(bytes), throwsA(isA<ZipTooLarge>()));
    });
  });
}
