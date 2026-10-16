@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/folders.dart';
import 'package:gubasic_ide/src/project/folders_io.dart';

void main() {
  late Directory temp;
  late ProjectFolders fs;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('gubasic_folders_');
    fs = platformFolders()!;
  });
  tearDown(() => temp.deleteSync(recursive: true));

  String at(String name) => fs.join(temp.path, name);

  test('writes, replaces and reads UTF-8 text with LF', () async {
    await fs.write(at('Form1.gbas'), "' 안녕\n");
    await fs.write(at('Form1.gbas'), "' 안녕하세요\nEnd\n");
    expect(await fs.read(at('Form1.gbas')), "' 안녕하세요\nEnd\n");
    expect(
      File(at('Form1.gbas')).readAsBytesSync().where((b) => b == 13),
      isEmpty,
    );
    expect(await fs.list(temp.path), ['Form1.gbas'], reason: 'no temp file');
  });

  test('a missing file reads as null; folders are not listed', () async {
    Directory(at('sub')).createSync();
    expect(await fs.read(at('none.gbas')), isNull);
    expect(await fs.list(temp.path), isEmpty);
    expect(await fs.exists(at('sub')), isTrue);
    expect(await fs.exists(at('none')), isFalse);
  });

  test('a file that is not UTF-8 text', () async {
    File(at('bad.gbas')).writeAsBytesSync([0xff, 0xfe, 0x00]);
    expect(
      fs.read(at('bad.gbas')),
      throwsA(isA<FolderIoException>().having((e) => e.reason, 'reason', null)),
    );
  });

  test('a write into a missing folder fails and leaves nothing', () async {
    expect(
      fs.write(at('gone/Form1.gbas'), 'x'),
      throwsA(isA<FolderIoException>()),
    );
    expect(Directory(at('gone')).existsSync(), isFalse);
  });

  test('createFolder, then a project round-trips', () async {
    await fs.createFolder(at('Quiz'));
    await fs.write(fs.join(at('Quiz'), 'Quiz.gbproj'), 'formatVersion: 1\n');
    expect(await fs.list(at('Quiz')), ['Quiz.gbproj']);
  });
}
