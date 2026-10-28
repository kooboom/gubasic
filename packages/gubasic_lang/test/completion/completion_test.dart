import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: lstCity, type: ListBox }
  - { name: lblMessage, type: Label }
  - { name: btnSave, type: Button }
''', name: 'Form1').form;

/// The code, with `|` where the caret is.
({String source, int offset}) _at(String code) {
  final offset = code.indexOf('|');
  return (source: code.replaceFirst('|', ''), offset: offset);
}

Completions? _complete(String code, {String? compiled, bool form = true}) {
  final c = _at(code);
  final program = compile(
    compiled ?? c.source,
    form: form ? _form : null,
  );
  return completionsAt(
    c.source,
    c.offset,
    program: program,
    form: form ? _form : null,
  );
}

List<String> _names(String code, {String? compiled, bool form = true}) => [
      for (final c in _complete(code, compiled: compiled, form: form)!.items)
        c.name,
    ];

void main() {
  group('after a dot', () {
    test('a control\'s properties and methods, from its component.yaml', () {
      final items = _complete('Sub W()\n    lstCity.|\nEnd Sub\n')!.items;
      expect(items.map((c) => c.toString()), [
        'method AddItem (item As String)',
        'property Anchor String',
        'method Clear ()',
        'property Height Integer',
        'property Left Integer',
        'method List (index As Integer) As String',
        'property ListCount Integer',
        'property ListIndex Integer',
        'property Name String',
        'method RemoveItem (index As Integer)',
        'property Tag String',
        'property Text String',
        'property Top Integer',
        'property Width Integer',
      ]);
      // Internal properties (the items) are not members; events are not
      // either (they are handled with Sub lstCity_Changed).
      expect(items.where((c) => c.readOnly).map((c) => c.name), [
        'ListCount',
        'Text',
      ]);
    });

    test('filtered by what is typed, ignoring case: starts, then contains', () {
      final c = _complete('Sub W()\n    lstCity.li|\nEnd Sub\n')!;
      expect(c.prefix, 'li');
      expect(c.afterDot, isTrue);
      expect(c.items.map((c) => c.name), ['List', 'ListCount', 'ListIndex']);
      expect(_names('Sub W()\n    lstCity.count|\nEnd Sub\n'), ['ListCount']);
    });

    test('the whole word is replaced, also after the caret', () {
      final code = _at('Sub W()\n    lstCity.Li|stIdx = 1\nEnd Sub\n');
      final c = completionsAt(code.source, code.offset, form: _form)!;
      expect(code.source.substring(c.start, c.end), 'ListIdx');
      expect(c.prefix, 'Li');
    });

    test('variables of built-in types: String, List, arrays', () {
      const decls = 'Dim names As New List(Of String)\n'
          'Dim scores(3) As Integer\n'
          'Dim title As String\n';
      expect(_names('${decls}Sub W()\n    names.C|\nEnd Sub\n'),
          ['Clear', 'Contains', 'Count']);
      expect(_names('${decls}Sub W()\n    scores.|\nEnd Sub\n'), ['Length']);
      expect(_names('${decls}Sub W()\n    title.To|\nEnd Sub\n'),
          ['ToLower', 'ToUpper']);
      // An item of a list or array, and a property's members.
      expect(
          _names('${decls}Sub W()\n    names(0).Len|\nEnd Sub\n'), ['Length']);
      expect(
          _names('Sub W()\n    lstCity.Text.Sub|\nEnd Sub\n'), ['Substring']);
      expect(_names('Sub W()\n    lstCity.List(0).Trim|\nEnd Sub\n'), ['Trim']);
    });

    test('locals and parameters of the procedure the caret is in', () {
      const code = 'Sub A(who As String)\n'
          '    Dim n As New List(Of Integer)\n'
          '    who.|\n'
          'End Sub\n'
          'Sub B()\n'
          '    n.|\n'
          'End Sub\n';
      final first = code.replaceFirst('n.|', 'n.');
      expect(_names(first), contains('ToUpper'));
      final second = code.replaceFirst('who.|', 'who.');
      expect(_complete(second), isNull, reason: 'n is A\'s, not B\'s');
    });

    test('built-in objects, Me, and function results', () {
      expect(_names('Sub W()\n    Debug.|\nEnd Sub\n'), ['Print']);
      expect(_names('Sub W()\n    Integer.|\nEnd Sub\n'),
          ['MaxValue', 'MinValue']);
      expect(_names('Sub W()\n    Me.|\nEnd Sub\n'), [
        'Caption',
        'Close',
        'Controls',
        'DialogResult',
        'Height',
        'Hide',
        'KeyPreview',
        'Name',
        'Show',
        'ShowDialog',
        'Tag',
        'Width'
      ]);
      expect(_names('Sub W()\n    Trim(lblMessage.Caption).Len|\nEnd Sub\n'),
          ['Length']);
    });

    test('names typed since the last compilation are looked up by spelling',
        () {
      // Compiled before the line was typed: offsets have moved on.
      const before = 'Dim title As String\nSub W()\nEnd Sub\n';
      expect(
          _names(
              'Dim title As String\nSub W()\n    x = 1\n    title.Tr|\n'
              'End Sub\n',
              compiled: before),
          ['Trim']);
    });

    test('nothing for what is unknown or has no members', () {
      expect(_complete('Sub W()\n    nope.|\nEnd Sub\n'), isNull);
      expect(_complete('Sub W()\n    Dim o As Object\n    o.|\nEnd Sub\n'),
          isNull);
      expect(_complete('Sub W()\n    (1 + 2).|\nEnd Sub\n'), isNull);
      expect(_complete('Sub W()\n    lstCity.Nope.|\nEnd Sub\n'), isNull);
      expect(
          _names('Sub W()\n    Dim i As Integer\n    i.|\nEnd Sub\n'), isEmpty);
    });
  });

  group('elsewhere', () {
    test('keywords, names in scope, built-ins and controls', () {
      final items = _complete(
              'Dim total As Integer\nSub W()\n    Dim count As Integer\n    |\n'
              'End Sub\n')!
          .items;
      String? find(String name) =>
          items.where((c) => c.name == name).firstOrNull?.toString();
      expect(find('If'), 'keyword If');
      expect(find('total'), 'variable total Integer');
      expect(find('count'), 'variable count Integer');
      expect(find('MsgBox'),
          'function MsgBox (prompt As String, [title As String])');
      expect(find('InStr'),
          'function InStr (text As String, find As String) As Integer');
      expect(find('Debug'), 'object Debug');
      expect(find('lstCity'), 'control lstCity ListBox');
      expect(find('W'), 'procedure W ()');
      // Not supported, so not offered.
      expect(find('GoTo'), isNull);
      expect(find('Variant'), isNull);
    });

    test('a prefix: the names starting with it first', () {
      expect(_names('Sub W()\n    ms|\nEnd Sub\n'), ['MsgBox']);
      expect(_names('Sub W()\n    lbl|\nEnd Sub\n'), ['lblMessage']);
      // Starting with it (Len), then containing it (UBound).
      expect(_names('Sub W()\n    bou|\nEnd Sub\n'), ['UBound']);
      expect(_names('Sub W()\n    Le|\nEnd Sub\n').take(2), ['Left', 'Len']);
    });

    test('event handlers are left out; other procedures are offered', () {
      const code = 'Sub btnSave_Click()\nEnd Sub\nSub Refresh()\nEnd Sub\n'
          'Sub W()\n    |\nEnd Sub\n';
      final names = _names(code);
      expect(names, contains('Refresh'));
      expect(names, isNot(contains('btnSave_Click')));
    });

    test('type names after As and New', () {
      final types = _names('Sub W()\n    Dim n As |\nEnd Sub\n');
      expect(types, [
        'Boolean',
        'Button',
        'CheckBox',
        'ComboBox',
        'Control',
        'Date',
        'Double',
        'Exception',
        'Form',
        'Image',
        'Integer',
        'KeyEventArgs',
        'Label',
        'List',
        'ListBox',
        'Object',
        'OptionButton',
        'String',
        'TextBox',
        'Timer',
      ]);
      expect(_names('Sub W()\n    Dim n As New Li|\nEnd Sub\n'),
          ['List', 'ListBox']);
      expect(_names('Sub W()\n    Dim n As New List(Of St|\nEnd Sub\n'),
          ['String']);
    });

    test('without a compilation: keywords, built-ins and the controls', () {
      final c = _at('Sub W()\n    lbl|\nEnd Sub\n');
      expect(
          completionsAt(c.source, c.offset, form: _form)!
              .items
              .map((c) => c.name),
          ['lblMessage']);
      final d = _at('Sub W()\n    lstCity.Ad|\nEnd Sub\n');
      expect(
          completionsAt(d.source, d.offset, form: _form)!
              .items
              .map((c) => c.name),
          ['AddItem']);
    });
  });

  group('nothing is completed', () {
    for (final (what, code) in [
      ('in a string', 'Sub W()\n    MsgBox("lst|")\nEnd Sub\n'),
      ('in a string not closed yet', 'Sub W()\n    MsgBox("ls|\nEnd Sub\n'),
      ('in a comment', "Sub W()\n    ' lst|\nEnd Sub\n"),
      ('in a Rem comment', 'Sub W()\n    Rem lst|\nEnd Sub\n'),
      ('in a number', 'Sub W()\n    x = 12|\nEnd Sub\n'),
      ('in a number with a dot', 'Sub W()\n    x = 1.|\nEnd Sub\n'),
      ('after Dim (a new name)', 'Sub W()\n    Dim ab|\nEnd Sub\n'),
      ('after Sub (a new name)', 'Sub Wo|\nEnd Sub\n'),
      ('after Const (a new name)', 'Const MA|\n'),
      ('right after Hangul', 'Sub W()\n    x = 점|\nEnd Sub\n'),
    ]) {
      test(what, () => expect(_complete(code), isNull));
    }
  });

  group('did you mean', () {
    test('the replacements of the diagnostic on the word come first', () {
      final c = _complete('Sub W()\n    lstCity.ListIndx| = 1\nEnd Sub\n')!;
      expect(c.items.first.toString(), 'suggestion ListIndex');
      final d = _complete('Sub W()\n    lblMessage.Text| = "x"\nEnd Sub\n')!;
      expect(d.items.first.toString(), 'suggestion Caption');
      final e = _complete('Dim total As Integer\nSub W()\n    totl| = 1\n'
          'End Sub\n')!;
      expect(e.items.first.toString(), 'suggestion total');
    });

    test('several replacements (otherNames), the caret anywhere in the word',
        () {
      final c = _complete('Sub W()\n    lstCity.It|ems.Add("a")\nEnd Sub\n')!;
      expect(c.items.take(3).map((c) => c.toString()), [
        'suggestion AddItem',
        'suggestion List',
        'suggestion ListCount',
      ]);
    });

    test('only when the compilation is of the code as it is now', () {
      final c = _at('Sub W()\n    lstCity.ListIndx| = 1\nEnd Sub\n');
      final older = compile('${c.source}\n', form: _form);
      final items = completionsAt(c.source, c.offset, program: older)!.items;
      expect(items.where((c) => c.kind == CompletionKind.suggestion), isEmpty);
    });
  });

  test('stays fast on a 300-line file', () {
    final quiz = StringBuffer('Dim total As Integer\n');
    for (var i = 0; quiz.toString().split('\n').length < 300; i++) {
      quiz.write('Sub Work$i(n As Integer)\n'
          '    Dim names As New List(Of String)\n'
          '    names.Add(lstCity.Text)\n'
          '    total = total + n\n'
          '    lblMessage.Caption = CStr(total)\n'
          'End Sub\n');
    }
    final source = '${quiz}Sub W()\n    lstCity.\nEnd Sub\n';
    final offset = source.lastIndexOf('lstCity.') + 'lstCity.'.length;
    final program = compile(source, form: _form);
    for (var i = 0; i < 50; i++) {
      completionsAt(source, offset, program: program);
    }
    final watch = Stopwatch()..start();
    const runs = 200;
    for (var i = 0; i < runs; i++) {
      completionsAt(source, offset, program: program);
      completionsAt(source, source.length - 9, program: program);
    }
    final each = watch.elapsedMicroseconds / runs / 2;
    expect(each, lessThan(1000), reason: '$each µs each');
  });
}
