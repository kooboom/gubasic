import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/project_forms.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

/// Adding, renaming and deleting a project's forms, and choosing the one
/// it starts with (D88): what the files become.
void main() {
  const files = {
    'Demo.gbproj':
        'formatVersion: 1\nname: Demo\nstartup: Form2\nforms:\n'
        '  - Form1\n  - Form2\nid: abcdefgh\n',
    'Form1.form.yaml':
        'formatVersion: 1\nproperties:\n  Caption: One\n  Width: 300\n'
        '  Height: 200\n',
    'Form1.gbas': 'Sub Form_Load()\n    Form2.Show\nEnd Sub\n',
    'Form2.form.yaml':
        'formatVersion: 1\nproperties:\n  Caption: Two\n  Width: 320\n'
        '  Height: 240\n',
    'Form2.gbas':
        'Dim Settings As Integer\n'
        'Sub Form_Load()\n    Debug.Print("Form2")\nEnd Sub\n',
  };

  ProjectFile project(Map<String, String> f) =>
      readProjectFile(f['Demo.gbproj']!).project;

  test('a new form is named Form3, with the startup form\'s size, listed '
      'last, its other entries kept', () {
    expect(newFormName(files), 'Form3');
    final added = withFormAdded(files, 'Form3')!;
    expect(project(added).forms, ['Form1', 'Form2', 'Form3']);
    expect(project(added).startup, 'Form2');
    expect(project(added).id, 'abcdefgh');
    final form = readFormFile(added['Form3.form.yaml']!, name: 'Form3');
    expect(form.diagnostics, isEmpty);
    expect(form.form.valueOf('Caption'), 'Form3');
    expect(form.form.valueOf('Width'), 320);
    expect(form.form.valueOf('Height'), 240);
    expect(added['Form3.gbas'], '');
  });

  test('a form is renamed with its files, the list, the startup and its '
      'uses in the code; its handlers stay Form_Load', () {
    final renamed = withFormRenamed(files, 'form2', 'Question');
    // In the same order: the project list keeps its order.
    expect(renamed.keys.toList(), [
      'Demo.gbproj',
      'Form1.form.yaml',
      'Form1.gbas',
      'Question.form.yaml',
      'Question.gbas',
    ]);
    expect(project(renamed).forms, ['Form1', 'Question']);
    expect(project(renamed).startup, 'Question');
    expect(
      renamed['Form1.gbas'],
      'Sub Form_Load()\n    Question.Show\nEnd Sub\n',
    );
    expect(renamed['Question.gbas'], files['Form2.gbas']);
    expect(renamed['Question.form.yaml'], files['Form2.form.yaml']);
  });

  test('a name a form cannot take says why', () {
    expect(formNameRefusal(files, 'Form 3'), isA<FormNameNotUsable>());
    expect(formNameRefusal(files, 'Sub'), isA<FormNameNotUsable>());
    expect(formNameRefusal(files, 'FORM1'), isA<FormNameTaken>());
    // Form2's code has a variable named Settings.
    expect(
      formNameRefusal(files, 'Settings', from: 'Form1'),
      isA<FormNameUsedInCode>().having((r) => r.uses, 'uses', ['Form2.gbas:1']),
    );
    expect(formNameRefusal(files, 'form2', from: 'Form2'), isNull);
    expect(formNameRefusal(files, 'Question', from: 'Form2'), isNull);
  });

  test('a form is deleted with its files; the first left starts when it was '
      'the startup form; its uses are listed first', () {
    expect(formUsesIn(files, 'Form2'), ['Form1.gbas:2']);
    final deleted = withFormDeleted(files, 'Form2');
    expect(deleted.keys.toList(), [
      'Demo.gbproj',
      'Form1.form.yaml',
      'Form1.gbas',
    ]);
    expect(project(deleted).forms, ['Form1']);
    expect(project(deleted).startup, 'Form1');
    expect(project(withFormDeleted(files, 'Form1')).startup, 'Form2');
  });

  test('the startup form is chosen', () {
    final chosen = withStartupForm(files, 'Form1');
    expect(project(chosen).startup, 'Form1');
    expect(project(chosen).forms, ['Form1', 'Form2']);
    expect(startupFormOf(chosen), 'Form1');
    expect(projectForms(chosen), ['Form1', 'Form2']);
  });
}
