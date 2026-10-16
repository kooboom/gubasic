import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

void main() {
  for (final (folder, file) in [('hello', 'Hello'), ('typing', 'Typing')]) {
    test('examples/$folder/$file.gbproj is written back byte for byte', () {
      final text =
          File('../../examples/$folder/$file.gbproj').readAsStringSync();
      final read = readProjectFile(text);
      expect(read.diagnostics, isEmpty);
      expect(writeProjectFile(read.project), text);
    });
  }

  test('without a startup form, and with names YAML would misread', () {
    final text = writeProjectFile(
        ProjectFile(name: '2026 퀴즈: 1', forms: ['Form1', 'Form2']));
    expect(text, '''
formatVersion: 1
name: "2026 퀴즈: 1"
forms:
  - Form1
  - Form2
''');
    final read = readProjectFile(text);
    expect(read.diagnostics, isEmpty);
    expect(read.project.name, '2026 퀴즈: 1');
    expect(read.project.startup, isNull);
    expect(read.project.startupForm, 'Form1');
  });

  test('a Korean name is written as it is', () {
    final text = writeProjectFile(
        ProjectFile(name: '내 퀴즈', forms: ['Form1'], startup: 'Form1'));
    expect(text, contains('name: 내 퀴즈\n'));
    expect(readProjectFile(text).project.name, '내 퀴즈');
  });
}
