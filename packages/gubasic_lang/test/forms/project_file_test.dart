import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

List<String> diagnose(String text) => readProjectFile(text)
    .diagnostics
    .map((d) => '${d.code.code}@${d.line}')
    .toList();

void main() {
  test('a project with its forms and startup form', () {
    final r = readProjectFile('formatVersion: 1\nname: Quiz\n'
        'startup: Form2\nforms:\n  - Form1\n  - Form2\n');
    expect(r.diagnostics, isEmpty);
    expect(r.project.name, 'Quiz');
    expect(r.project.forms, ['Form1', 'Form2']);
    expect(r.project.startupForm, 'Form2');
  });

  test('the first form starts when startup is not given', () {
    final r = readProjectFile('formatVersion: 1\nforms: [Main1, Other]\n');
    expect(r.diagnostics, isEmpty);
    expect(r.project.startupForm, 'Main1');
  });

  test('startup is matched in any case and keeps the listed spelling', () {
    final r =
        readProjectFile('formatVersion: 1\nstartup: FORM1\nforms: [Form1]\n');
    expect(r.diagnostics, isEmpty);
    expect(r.project.startupForm, 'Form1');
  });

  test('F011: startup names a form that is not listed', () {
    expect(diagnose('formatVersion: 1\nstartup: Form9\nforms: [Form1]\n'),
        ['F011@2']);
  });

  test('F005: forms is missing, empty or not a list', () {
    expect(diagnose('formatVersion: 1\nname: X\n'), ['F005@1']);
    expect(diagnose('formatVersion: 1\nforms: []\n'), ['F005@2']);
    expect(diagnose('formatVersion: 1\nforms: Form1\n'), ['F005@2']);
  });

  test('F006 and F007: unusable and repeated form names', () {
    expect(
        diagnose('formatVersion: 1\nforms:\n  - Form1\n  - form1\n'
            '  - 2nd\n  - Form\n'),
        ['F007@4', 'F006@5', 'F006@6']);
  });

  test('F002, F003 and F004 as in form files', () {
    expect(diagnose('forms: [Form1]\n'), ['F002@1']);
    expect(diagnose('formatVersion: 7\nforms: [Form1]\n'), ['F003@1']);
    expect(diagnose('formatVersion: 1\nforms: [Form1]\nicon: x.png\n'),
        ['F004@3']);
  });

  group('the app ID (D83)', () {
    test('is read and written back', () {
      const text = 'formatVersion: 1\nid: k3x9q2m7a1b4c8d0\nname: Quiz\n'
          'forms:\n  - Form1\n';
      final r = readProjectFile(text);
      expect(r.diagnostics, isEmpty);
      expect(r.project.id, 'k3x9q2m7a1b4c8d0');
      expect(writeProjectFile(r.project), text);
    });

    test('a project without one has none, and is written without one', () {
      final r = readProjectFile('formatVersion: 1\nname: A\nforms:\n  - F\n');
      expect(r.project.id, isNull);
      expect(writeProjectFile(r.project), isNot(contains('id:')));
    });

    test('F018: one that is not an app ID is a warning, and ignored', () {
      for (final bad in ['Short1', 'abc', 'has-hyphen1', 'UPPERCASE123']) {
        final r = readProjectFile(
            'formatVersion: 1\nid: $bad\nname: A\nforms:\n  - F\n');
        expect(r.diagnostics.map((d) => '${d.code.code}@${d.line}'), ['F018@2'],
            reason: bad);
        expect(r.hasErrors, isFalse);
        expect(r.project.id, isNull);
      }
    });

    test('new ones are app IDs, and differ', () {
      final ids = {for (var i = 0; i < 100; i++) newProjectId()};
      expect(ids, hasLength(100));
      expect(ids.every(isProjectId), isTrue);
    });
  });
}
