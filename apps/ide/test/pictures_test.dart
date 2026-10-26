import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/designer/form_edit.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/folders.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_ide/src/project/project_pictures.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_ide/src/project/project_zip.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import 'support/memory_folders.dart';
import 'support/pictures.dart';

void main() {
  final hello = exampleProjects['hello']!;
  final png = onePixelPng;
  final other = pngHeader(2, 2);

  /// Hello with the pictures [names], each [png].
  Map<String, String> helloListing(List<String> names) => {
    ...hello,
    'Hello.gbproj': helloWithPictures(names),
  };

  group('checkPicture', () {
    PictureRefused? check(
      String name,
      Uint8List bytes, {
      Map<String, Uint8List> pictures = const {},
      Map<String, String>? files,
    }) => checkPicture(name, bytes, files ?? hello, pictures);

    test('a PNG, a JPEG and a GIF are taken', () {
      expect(check('a.png', png), isNull);
      expect(
        check('사과.jpg', Uint8List.fromList([0xFF, 0xD8, 0xFF, 0])),
        isNull,
      );
      expect(
        check('b.GIF', Uint8List.fromList('GIF89a\x01\x00\x01\x00'.codeUnits)),
        isNull,
      );
    });

    test('a name a picture cannot have (F014)', () {
      expect(
        check('notes.txt', png),
        isA<BadPictureName>().having(
          (r) => r.problem,
          'problem',
          PictureNameProblem.extension,
        ),
      );
      expect(
        check('a:b.png', png),
        isA<BadPictureName>().having(
          (r) => r.problem,
          'problem',
          PictureNameProblem.character,
        ),
      );
    });

    test('what the bytes are counts, not the name', () {
      final heic = Uint8List.fromList([0, 0, 0, 24, ...'ftypheic'.codeUnits]);
      expect(
        check('photo.jpg', heic),
        isA<NotAPicture>().having(
          (r) => r.format,
          'format',
          PictureFormat.heic,
        ),
      );
      expect(
        check('a.png', Uint8List.fromList('hello'.codeUnits)),
        isA<NotAPicture>().having(
          (r) => r.format,
          'format',
          PictureFormat.unknown,
        ),
      );
    });

    test('too large, too wide, and a project too full', () {
      expect(
        check('big.png', pngHeader(10, 10, length: maxPictureBytes + 1)),
        isA<PictureTooLarge>(),
      );
      expect(
        check('ok.png', pngHeader(10, 10, length: maxPictureBytes)),
        isNull,
      );
      expect(
        check('wide.png', pngHeader(maxPictureSide + 1, 10)),
        isA<PictureTooWide>()
            .having((r) => r.width, 'width', maxPictureSide + 1)
            .having((r) => r.height, 'height', 10),
      );
      final full = {
        for (var i = 0; i < 5; i++)
          'p$i.png': pngHeader(1, 1, length: maxPictureBytes),
      };
      expect(check('one.png', png, pictures: full), isA<ProjectPicturesFull>());
      expect(
        check('P0.PNG', png, pictures: full),
        isNull,
        reason: 'a picture that is replaced does not count',
      );
    });

    test('a .gbproj with errors takes no pictures', () {
      expect(
        check('a.png', png, files: {...hello, 'Hello.gbproj': 'name: [\n'}),
        isA<ProjectFileHasErrors>(),
      );
    });
  });

  group('OpenProject', () {
    test(
      'adding a picture lists it in the .gbproj and changes the project',
      () {
        final p = OpenProject(const ExampleLocation('hello'), hello);
        p.setPicture('사과.png', png);
        expect(p.isDirty, isTrue);
        expect(p.pictures.keys, ['사과.png']);
        final read = readProjectFile(p.files['Hello.gbproj']!);
        expect(read.hasErrors, isFalse);
        expect(read.project.pictures, ['사과.png']);
        expect(read.project.startup, 'Form1');
        expect(p.files['Hello.gbproj'], startsWith('formatVersion: 2'));
      },
    );

    test('a picture of the same name in another case is replaced', () {
      final p = OpenProject(
        const ExampleLocation('hello'),
        helloListing(['Apple.png']),
        pictures: {'Apple.png': png},
      );
      p.setPicture('apple.PNG', other);
      expect(p.pictures, {'Apple.png': other});
      expect(readProjectFile(p.files['Hello.gbproj']!).project.pictures, [
        'Apple.png',
      ]);
      expect(p.isDirty, isTrue);
    });

    test('removing the last picture writes the .gbproj as version 1', () {
      final p = OpenProject(
        const ExampleLocation('hello'),
        helloListing(['a.png']),
        pictures: {'a.png': png},
      );
      p.removePicture('a.png');
      expect(p.pictures, isEmpty);
      expect(p.files['Hello.gbproj'], startsWith('formatVersion: 1'));
    });

    test('saved pictures are not dirty; the same bytes again are not', () {
      final p = OpenProject(
        const ExampleLocation('hello'),
        helloListing(['a.png']),
        pictures: {'a.png': png},
      );
      p.setPicture('a.png', Uint8List.fromList(png));
      expect(p.isDirty, isFalse);
      p.setPicture('a.png', other);
      p.markSaved();
      expect(p.isDirty, isFalse);
      expect(p.savedPictures, {'a.png': other});
    });
  });

  test("the examples' pictures are their files, and would be taken", () {
    final pictures = decodeExamplePictures(examplePictures);
    expect(pictures.keys, ['quiz']);
    for (final MapEntry(key: project, value: named) in pictures.entries) {
      final files = exampleProjects[project]!;
      for (final MapEntry(key: name, value: bytes) in named.entries) {
        expect(
          bytes,
          File('../../examples/$project/pictures/$name').readAsBytesSync(),
        );
        expect(checkPicture(name, bytes, files, const {}), isNull);
      }
    }
  });

  test('pictureUsers names the controls that show a picture', () {
    final form = readFormFile(hello['Form1.form.yaml']!, name: 'Form1').form;
    final placed = withControl(form, builtinComponents['image']!, 'imgApple', (
      left: 0,
      top: 0,
      width: 40,
      height: 40,
    ));
    final withImage = writeFormFile(
      withProperty(placed, 'imgApple', 'Picture', 'APPLE.png'),
    );
    final files = {
      ...helloListing(['apple.png']),
      'Form1.form.yaml': withImage,
    };
    expect(pictureUsers(files, 'apple.png'), ['Form1.imgApple']);
    expect(pictureUsers(files, 'pear.png'), isEmpty);
  });

  test('pictureSource finds a picture in any case', () {
    final source = pictureSource({'Apple.png': png});
    expect(source('apple.PNG'), png);
    expect(source('pear.png'), isNull);
  });

  group('on disk', () {
    late MemoryFolders fs;
    setUp(() {
      fs = MemoryFolders()..add('/p', helloListing(['사과.png', 'b.png']));
      fs.folders.add('/p/pictures');
      fs.bytes['/p/pictures/사과.png'] = png;
    });

    test(
      'the pictures the .gbproj lists are read; missing ones named',
      () async {
        final read = await readProject(fs, '/p/Hello.gbproj');
        expect(read.pictures, {'사과.png': png});
        expect(read.missing, ['pictures/b.png']);
      },
    );

    test(
      'saving writes new pictures first and deletes removed ones last',
      () async {
        final saved = helloListing(['사과.png']);
        final files = helloListing(['b.png']);
        await writeChanged(
          fs,
          '/p',
          files,
          saved,
          pictures: {'b.png': other},
          savedPictures: {'사과.png': png},
        );
        expect(fs.written, ['/p/pictures/b.png', '/p/Hello.gbproj']);
        expect(fs.deleted, ['/p/pictures/사과.png']);
        expect(fs.bytes.keys, ['/p/pictures/b.png']);
      },
    );

    test('the pictures folder is made when it is not there', () async {
      final fs = MemoryFolders()..add('/q', hello);
      await writeChanged(
        fs,
        '/q',
        helloListing(['a.png']),
        hello,
        pictures: {'a.png': png},
      );
      expect(fs.folders, contains('/q/pictures'));
      expect(fs.bytes['/q/pictures/a.png'], png);
    });

    test('a picture changed on disk since it was read is found', () async {
      fs.bytes['/p/pictures/사과.png'] = other;
      expect(
        await changedOnDisk(
          fs,
          '/p',
          hello,
          hello,
          pictures: const {},
          savedPictures: {'사과.png': png},
        ),
        ['pictures/사과.png'],
      );
      expect(
        await changedOnDisk(
          fs,
          '/p',
          hello,
          hello,
          pictures: {'사과.png': png},
          savedPictures: {'사과.png': png},
        ),
        isEmpty,
        reason: 'unchanged pictures are not looked at',
      );
    });

    test('Save As copies the pictures and keeps them listed', () async {
      fs.folders.add('/home');
      final (folder, files) = await saveCopy(
        fs,
        '/home',
        'Fruit',
        helloListing(['사과.png']),
        pictures: {'사과.png': png},
      );
      expect(folder, '/home/Fruit');
      expect(fs.bytes['/home/Fruit/pictures/사과.png'], png);
      final read = readProjectFile(files['Fruit.gbproj']!).project;
      expect(read.name, 'Fruit');
      expect(read.pictures, ['사과.png']);
    });
  });

  group('.zip', () {
    test('pictures go into NAME/pictures/ and come back', () {
      final bytes = zipProject(
        'Hello',
        helloListing(['사과.png']),
        pictures: {'사과.png': png},
      );
      expect(
        ZipDecoder().decodeBytes(bytes).files.map((f) => f.name),
        contains('Hello/pictures/사과.png'),
      );
      final back = unzipProject(bytes);
      expect(back.pictures, {'사과.png': png});
      expect(back.missing, isEmpty);
      expect(back.ignored, isEmpty);
    });

    Archive archiveOf(Map<String, List<int>> entries) {
      final archive = Archive();
      for (final MapEntry(:key, :value) in entries.entries) {
        archive.add(ArchiveFile.bytes(key, value));
      }
      return archive;
    }

    List<int> zip(Map<String, List<int>> entries) =>
        ZipEncoder().encodeBytes(archiveOf(entries));

    Map<String, List<int>> text(String folder, Map<String, String> files) => {
      for (final MapEntry(:key, :value) in files.entries)
        '$folder$key': value.codeUnits.length == value.length
            ? value.codeUnits
            : throw ArgumentError('ASCII only'),
    };

    test('a picture named in another case keeps the .gbproj spelling; '
        'pictures not listed are left out and named', () {
      final back = unzipProject(
        zip({
          ...text('Hello/', helloListing(['Apple.png', 'pear.png'])),
          'Hello/pictures/apple.PNG': png,
          'Hello/pictures/extra.png': png,
          'Hello/other/pear.png': png,
        }),
      );
      expect(back.pictures, {'Apple.png': png});
      expect(back.missing, ['pictures/pear.png']);
      expect(
        back.ignored,
        unorderedEquals(['Hello/pictures/extra.png', 'Hello/other/pear.png']),
      );
    });

    test('a picture larger than a project takes is refused', () {
      expect(
        () => unzipProject(
          zip({
            ...text('', helloListing(['big.png'])),
            'pictures/big.png': pngHeader(1, 1, length: maxPictureBytes + 1),
          }),
        ),
        throwsA(isA<ZipTooLarge>()),
      );
    });
  });

  test('changing the picture list keeps the app ID (D83)', () {
    final files = withPictureList(
      {
        'A.gbproj':
            'formatVersion: 1\nid: k3x9q2m7a1b4c8d0\nname: A\n'
            'forms:\n  - Form1\n',
      },
      ['star.png'],
    );
    expect(readProjectFile(files['A.gbproj']!).project.id, 'k3x9q2m7a1b4c8d0');
  });
}
