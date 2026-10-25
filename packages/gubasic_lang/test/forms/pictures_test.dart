import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// A PNG header of [w] x [h] pixels (enough for [pictureSize]).
Uint8List _png(int w, int h) {
  final b = ByteData(24);
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < 8; i++) {
    b.setUint8(i, sig[i]);
  }
  b
    ..setUint32(8, 13)
    ..setUint32(16, w)
    ..setUint32(20, h);
  for (final (i, c) in 'IHDR'.codeUnits.indexed) {
    b.setUint8(12 + i, c);
  }
  return b.buffer.asUint8List();
}

/// A JPEG with an APP0 segment, then a start-of-frame of [w] x [h].
Uint8List _jpeg(int w, int h) => Uint8List.fromList([
      0xFF, 0xD8, //
      0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // APP0, 2 bytes of data
      0xFF, 0xC2, 0x00, 0x11, 0x08, h >> 8, h & 0xFF, w >> 8, w & 0xFF,
      0x03, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ]);

void main() {
  group('names', () {
    test('Hangul split into letters (macOS file names) is put together', () {
      // 사과 as macOS writes it: ㅅ ㅏ ㄱ ㅗ ㅏ, conjoining.
      const nfd = '사과.png';
      expect(composeHangul(nfd), '사과.png');
      // With a final consonant: 한 = ㅎ ㅏ ㄴ.
      expect(composeHangul('한'), '한');
      expect(composeHangul('triangle.png'), 'triangle.png');
      expect(composeHangul('사과.png'), '사과.png');
    });

    test(
        'case of English letters does not matter; Hangul is compared '
        'as syllables', () {
      expect(pictureKey('Triangle.PNG'), pictureKey('triangle.png'));
      expect(pictureKey('사과.png'), pictureKey('사과.PNG'));
      // Only A-Z are folded: the same on the VM and the web.
      expect(pictureKey('Ä.png'), 'Ä.png');
    });

    test('names a picture cannot have', () {
      expect(pictureNameProblem('triangle.png'), isNull);
      expect(pictureNameProblem('사과 1.JPEG'), isNull);
      expect(pictureNameProblem('a.gif'), isNull);
      expect(pictureNameProblem(''), PictureNameProblem.length);
      expect(pictureNameProblem('${'a' * 97}.png'), PictureNameProblem.length);
      for (final bad in ['a/b.png', r'a\b.png', 'a:b.png', '.png', ' a.png']) {
        expect(pictureNameProblem(bad), PictureNameProblem.character,
            reason: bad);
      }
      for (final bad in ['a.bmp', 'a.heic', 'a', 'a.png.txt']) {
        expect(pictureNameProblem(bad), PictureNameProblem.extension,
            reason: bad);
      }
    });
  });

  group('formats and sizes', () {
    test('told from the first bytes, not the name', () {
      expect(pictureFormat(_png(1, 1)), PictureFormat.png);
      expect(pictureFormat(_jpeg(1, 1)), PictureFormat.jpeg);
      expect(
          pictureFormat(Uint8List.fromList('GIF89a\x02\x00\x03\x00'.codeUnits)),
          PictureFormat.gif);
      final heic = Uint8List.fromList(
          [0, 0, 0, 24, ...'ftypheic'.codeUnits, 0, 0, 0, 0]);
      expect(pictureFormat(heic), PictureFormat.heic);
      expect(pictureFormat(Uint8List.fromList('hello'.codeUnits)),
          PictureFormat.unknown);
      expect(pictureFormat(Uint8List(0)), PictureFormat.unknown);
    });

    test('width and height from the header', () {
      expect(pictureSize(_png(640, 480)), (640, 480));
      expect(pictureSize(_jpeg(4032, 3024)), (4032, 3024));
      expect(
          pictureSize(Uint8List.fromList('GIF89a\x02\x01\x03\x00'.codeUnits)),
          (258, 3));
      expect(pictureSize(Uint8List.fromList([0xFF, 0xD8, 0xFF])), isNull);
    });
  });

  group('project files (version 2)', () {
    test('pictures are read and written; without them, version 1', () {
      final project = ProjectFile(
          name: 'Quiz', forms: ['Form1'], pictures: ['triangle.png', '사과.png']);
      final text = writeProjectFile(project);
      expect(text, startsWith('formatVersion: 2\n'));
      expect(text, contains('pictures:\n  - triangle.png\n  - 사과.png\n'));
      final read = readProjectFile(text);
      expect(read.diagnostics, isEmpty);
      expect(read.project.pictures, ['triangle.png', '사과.png']);
      expect(writeProjectFile(ProjectFile(name: 'Hello', forms: ['Form1'])),
          startsWith('formatVersion: 1\n'));
    });

    test('a version 1 file reads with no pictures', () {
      final read =
          readProjectFile('formatVersion: 1\nname: Hello\nforms:\n  - Form1\n');
      expect(read.diagnostics, isEmpty);
      expect(read.project.pictures, isEmpty);
    });

    test('bad names (F014) and names differing only in case (F015)', () {
      final read = readProjectFile('formatVersion: 2\nname: Quiz\n'
          'forms:\n  - Form1\n'
          'pictures:\n  - Triangle.png\n  - notes.txt\n  - triangle.PNG\n');
      expect(read.diagnostics.map((d) => '${d.code.code}@${d.line}'),
          ['F014@7', 'F015@8']);
      expect(read.project.pictures, ['Triangle.png']);
      final d = read.diagnostics.last;
      expect(d.args, ['triangle.PNG', 'Triangle.png', '6']);
      expect(
          d.formatMessage(koreanMessages),
          '"triangle.PNG" 그림은 "Triangle.png" 그림(6번 줄)과 대소문자만 다릅니다. '
          'GuBASIC은 Windows, macOS처럼 둘을 같은 이름으로 보므로 한 프로젝트에 함께 둘 수 없습니다. '
          '하나의 이름을 바꿔 주세요.');
    });

    test('Hangul from a Mac is kept as syllables', () {
      final read = readProjectFile('formatVersion: 2\nname: Q\n'
          'forms:\n  - Form1\npictures:\n  - "사과.png"\n');
      expect(read.project.pictures, ['사과.png']);
    });
  });

  group('form files', () {
    const form = 'formatVersion: 1\ncontrols:\n'
        '  - name: imgShape\n    type: Image\n'
        '    properties:\n      Picture: TRIANGLE.png\n      Stretch: true\n';

    test('Picture names a picture of the project, in any case (F016)', () {
      final ok = readFormFile(form, name: 'Form1', pictures: ['triangle.png']);
      expect(ok.diagnostics, isEmpty);
      // Read with the project's spelling.
      expect(ok.form.controls.single.valueOf('Picture'), 'triangle.png');
      expect(ok.form.controls.single.valueOf('Stretch'), true);

      final missing = readFormFile(form, name: 'Form1', pictures: []);
      expect(missing.diagnostics.map((d) => '${d.code.code}@${d.line}'),
          ['F016@6']);
      expect(missing.diagnostics.single.formatMessage(koreanMessages),
          '프로젝트에 "TRIANGLE.png" 그림이 없습니다. 프로젝트의 그림에 넣거나 다른 그림을 골라 주세요.');
    });

    test('read on its own, any name is taken', () {
      final r = readFormFile(form, name: 'Form1');
      expect(r.diagnostics, isEmpty);
      expect(r.form.controls.single.valueOf('Picture'), 'TRIANGLE.png');
    });
  });

  group('code', () {
    final form = readFormFile(
            'formatVersion: 1\ncontrols:\n  - { name: imgShape, type: Image }\n',
            name: 'Form1')
        .form;
    List<String> codes(String body, {List<String>? pictures = const []}) =>
        compile('Sub W()\n$body\nEnd Sub\n', form: form, pictures: pictures)
            .diagnostics
            .map((d) => d.code.code)
            .toList();

    test('text naming no picture of the project is a warning (A037)', () {
      expect(codes('imgShape.Picture = "circle.png"'), ['A037']);
      expect(codes('imgShape.Picture = "Circle.PNG"', pictures: ['circle.png']),
          isEmpty);
      expect(codes('imgShape.Picture = ""'), isEmpty);
      // Not checked without the project's pictures, nor for a variable.
      expect(codes('imgShape.Picture = "circle.png"', pictures: null), isEmpty);
      expect(codes('Dim p As String = "x.png"\nimgShape.Picture = p'), isEmpty);
    });

    test('VB names are pointed to GuBASIC\'s (A036)', () {
      expect(codes('imgShape.Image = ""'), ['A036']);
      expect(codes('imgShape.SizeMode = True'), ['A036']);
    });
  });

  test('a picture property is a String, empty by default', () {
    String yaml(String p) => 'name: X\nversion: 1\ndefaultEvent: A\n'
        'properties: [$p]\nevents: [A()]\n';
    expect(
        readComponentFile(
                yaml('{ name: P, type: String, default: "", picture: true }'))
            .properties['p']!
            .picture,
        isTrue);
    for (final bad in [
      '{ name: P, type: Integer, default: 0, picture: true }',
      '{ name: P, type: String, default: "a.png", picture: true }',
      '{ name: P, type: String, default: "", picture: 1 }',
    ]) {
      expect(() => readComponentFile(yaml(bad)), throwsFormatException,
          reason: bad);
    }
  });

  group('pictureLooksWhole (D65)', () {
    final png =
        File('../../examples/quiz/pictures/triangle.png').readAsBytesSync();
    // A 40 x 20 JPEG and an 8 x 8 GIF of two frames, as cameras and
    // tools write them.
    final jpeg = base64Decode(
        '/9j/4AAQSkZJRgABAQAAAQABAAD/4QAiRXhpZgAATU0AKgAAAAgAAQESAAMAAAABAAYAAAAAAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAAUACgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDgKKKK+eP2EKKKKACiiigAooooAKKKKACiiigD/9k=');
    final gif = base64Decode(
        'R0lGODlhCAAIAIEAAP8AAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgAAACwAAAAACAAIAAAIDwABCBxIsKDBgwgTKkwYEAAh+QQBCgABACwAAAAACAAIAIEA/wAAAAAAAAAAAAAIDwABCBxIsKDBgwgTKkwYEAA7');

    test('whole pictures pass', () {
      expect(pictureLooksWhole(png), isTrue);
      expect(pictureLooksWhole(jpeg), isTrue);
      expect(pictureLooksWhole(gif), isTrue);
    });

    test('pictures cut short fail', () {
      for (final whole in [png, jpeg, gif]) {
        for (final keep in [whole.length - 1, whole.length ~/ 2, 30, 12]) {
          expect(
              pictureLooksWhole(Uint8List.sublistView(whole, 0, keep)), isFalse,
              reason: '${pictureFormat(whole)} cut to $keep bytes');
        }
      }
    });

    test('a damaged PNG fails by its CRC; a header alone fails', () {
      final damaged = Uint8List.fromList(png)..[png.length ~/ 2] ^= 0xFF;
      expect(pictureLooksWhole(damaged), isFalse);
      expect(pictureLooksWhole(_png(100, 100)), isFalse);
      expect(pictureLooksWhole(_jpeg(100, 100)), isFalse);
    });
  });
}
