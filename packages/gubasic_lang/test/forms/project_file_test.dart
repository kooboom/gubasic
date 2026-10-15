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
}
