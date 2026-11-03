// Writes the reference of the language's controls, functions, objects and
// types (docs/reference/, in English and Korean) and the references for AI
// assistants (llms.txt and llms-full.txt at the repository's top), from
// what the analyzer knows (docs/DESIGN.md D121 d, D124). With --check it
// only says whether they are up to date, for CI.
//
//     dart run tool/gen_reference.dart [--check]
import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/src/forms/components.g.dart';

const _root = '../..';
const _site = 'https://github.com/kooboom/gubasic/blob/main';

/// What each function does, in English and Korean, by group.
const _functions = <String, Map<String, (String, String)>>{
  'Text': {
    'Len': ('The number of characters in text.', '글의 글자 수.'),
    'Left': ('The first length characters of text.', '글의 앞에서 length 글자.'),
    'Right': ('The last length characters of text.', '글의 뒤에서 length 글자.'),
    'Mid': (
      'Characters of text from start (counted from 1), length of them or to the end.',
      'start(1부터 셈)부터 length 글자, 없으면 끝까지.'
    ),
    'InStr': (
      'Where find first comes in text, counted from 1; 0 when it does not.',
      'find가 처음 나오는 자리(1부터 셈), 없으면 0.'
    ),
    'UCase': ('text in capital letters.', '대문자로 바꾼 글.'),
    'LCase': ('text in small letters.', '소문자로 바꾼 글.'),
    'Trim': ('text without spaces at either end.', '앞뒤 공백을 뺀 글.'),
    'Replace': (
      'text with every find replaced by with.',
      'find를 모두 with로 바꾼 글.'
    ),
    'Split': (
      'text cut at each separator, as an array.',
      'separator마다 자른 글의 배열.'
    ),
    'Join': (
      'The items of an array joined with separator.',
      '배열의 항목을 separator로 이은 글.'
    ),
  },
  'Conversion': {
    'CInt': (
      'value as an Integer, rounding halves away from zero; text is read as a number.',
      '정수로 바꾼 값(0.5는 0에서 먼 쪽으로). 글은 숫자로 읽음.'
    ),
    'CDbl': (
      'value as a Double; text is read as a number.',
      '실수로 바꾼 값. 글은 숫자로 읽음.'
    ),
    'CStr': ('value as text.', '글로 바꾼 값.'),
    'CBool': ('value as a Boolean.', 'Boolean으로 바꾼 값.'),
    'Val': (
      'The number at the start of text, 0 when there is none.',
      '글 앞부분의 숫자, 없으면 0.'
    ),
    'Str': ('A number as text.', '숫자를 글로.'),
  },
  'Math': {
    'Abs': ('The size of a number, without its sign.', '부호를 뺀 크기.'),
    'Int': ('The largest Integer not above value.', 'value보다 크지 않은 가장 큰 정수.'),
    'Round': (
      'value rounded to digits decimals (0 when left out), halves away from zero.',
      'digits 자리(없으면 0)로 반올림한 값. 0.5는 0에서 먼 쪽으로.'
    ),
    'Sqr': ('The square root.', '제곱근.'),
    'Rnd': (
      'A random Double from 0 up to, not including, 1.',
      '0 이상 1 미만의 난수.'
    ),
    'Randomize': (
      'Starts the random numbers again, from seed when given.',
      '난수를 다시 시작함. seed를 주면 그 값에서.'
    ),
    'Min': ('The smaller of two numbers.', '두 수 가운데 작은 것.'),
    'Max': ('The larger of two numbers.', '두 수 가운데 큰 것.'),
  },
  'Arrays': {
    'UBound': ('The largest index of an array.', '배열의 가장 큰 번호.'),
  },
  'Date and time': {
    'Now': ('The date and time now, on this device.', '이 기기의 지금 날짜와 시각.'),
    'Today': ('Today\'s date, at midnight.', '오늘 날짜(자정).'),
    'Year': ('The year of a date.', '날짜의 연.'),
    'Month': ('The month of a date, 1 to 12.', '날짜의 월(1~12).'),
    'Day': ('The day of a date.', '날짜의 일.'),
    'Hour': ('The hour of a date, 0 to 23.', '날짜의 시(0~23).'),
    'Minute': ('The minute of a date.', '날짜의 분.'),
    'Second': ('The second of a date.', '날짜의 초.'),
    'DateAdd': (
      'date with number intervals added: "yyyy", "q", "m", "d", "ww", "h", "n", "s", or DateInterval.',
      'date에 구간을 number만큼 더한 날짜: "yyyy", "q", "m", "d", "ww", "h", "n", "s" 또는 DateInterval.'
    ),
    'DateDiff': (
      'How many intervals from date1 to date2.',
      'date1부터 date2까지 몇 구간인지.'
    ),
    'Format': (
      'A date or a number written with a .NET format string: custom ("yyyy-MM-dd", "#,##0") or standard ("d", "N2", "C").',
      '.NET 서식 문자열로 쓴 날짜나 숫자: 사용자 지정("yyyy-MM-dd", "#,##0") 또는 표준("d", "N2", "C").'
    ),
  },
  'Dialogs': {
    'MsgBox': ('Shows a message and waits for OK.', '메시지를 보이고 확인을 기다림.'),
    'InputBox': (
      'Asks for a line of text; "" when cancelled.',
      '글 한 줄을 물음. 취소하면 "".'
    ),
  },
  'Program': {
    'DoEvents': (
      'Lets the screen draw and other events run, then goes on.',
      '화면을 그리고 다른 이벤트를 돌게 한 뒤 이어서 감.'
    ),
  },
  'Settings': {
    'SaveSetting': (
      'Keeps a value under key for this app.',
      '이 앱의 key에 값을 보관함.'
    ),
    'GetSetting': (
      'The value kept under key, or default.',
      'key에 보관한 값, 없으면 default.'
    ),
  },
};

/// The types whose members programs use, as `membersOf` names them.
final _types = <GbType>[
  GbType.string,
  const ListType(GbType.string),
  const ArrayType(GbType.string),
  GbType.exception,
  GbType.keyEventArgs,
  GbType.mouseEventArgs,
  GbType.messageEventArgs,
  GbType.closeEventArgs,
  GbType.errorEventArgs,
  GbType.roomEventArgs,
  GbType.table,
  GbType.pdfDocument,
  GbType.json,
  GbType.httpResponse,
];

String _param(ParamSpec p) {
  final type = switch (p.kind) {
    ArgKind.typed => p.type!.displayName,
    ArgKind.anyValue => 'any value',
    ArgKind.numeric => 'Integer or Double',
    ArgKind.numericOrString => 'number or String',
    ArgKind.convertible => 'number, Boolean or String',
    ArgKind.array => 'array',
    ArgKind.menu => 'Menu',
    ArgKind.tableOrGrid => 'Table or Grid',
    ArgKind.jsonValue => 'number, Boolean, String, Json or Nothing',
    ArgKind.sqlValue => 'number, Boolean, String, Date or Nothing',
  };
  if (p.variadic) return 'ParamArray ${p.name} As $type';
  return '${p.optional ? '[' : ''}${p.name} As $type${p.optional ? ']' : ''}';
}

String _call(String name, List<ParamSpec> params, GbType returns) {
  final args = params.map(_param).join(', ');
  return returns == GbType.void_
      ? '$name($args)'
      : '$name($args) As ${returns.displayName}';
}

String _member(MemberSpec m) => m.isMethod
    ? '${_call(m.name, m.method!.parameters, m.type)}'
        '${m.settable ? ' (can be assigned to)' : ''}'
    : '${m.name} As ${m.type.displayName}${m.readOnly ? '' : ' (can be set)'}';

/// The comment at the top of a component.yaml: what the control is.
String _description(String component) {
  final yaml = builtinComponentFiles.entries
      .firstWhere((e) => e.key.toLowerCase() == component.toLowerCase())
      .value;
  final lines = <String>[];
  for (final l in yaml.split('\n')) {
    if (!l.startsWith('#')) break;
    lines.add(l.replaceFirst(RegExp('^# ?'), ''));
  }
  return lines.join(' ').trim();
}

class _Words {
  const _Words.en()
      : ko = false,
        title = 'GuBASIC reference',
        intro =
            'Every control, function, object and type, generated from what the '
                'analyzer knows. How they behave is explained in '
                '[LANGUAGE.md](../LANGUAGE.md).',
        controls = 'Controls',
        functions = 'Functions',
        objects = 'Objects and types',
        properties = 'Properties',
        methods = 'Methods',
        events = 'Events',
        otherNames = 'Names other versions of BASIC use',
        defaultEvent = 'Default event (made by a double-click)',
        notOnForm = 'Not seen on the form: kept in the designer\'s tray.',
        type = 'Type',
        initial = 'At first',
        notes = 'Notes',
        readOnly = 'read only',
        runTimeOnly = 'set only while the program runs',
        constants = 'Constants',
        builtinObjects = 'Built-in objects',
        typeMembers = 'Members of types',
        explained = 'Explained in [LANGUAGE.md §11](../../LANGUAGE.md).',
        back = '[All of the reference](../README.md)',
        language = '[한국어](README.ko.md)',
        ext = '.md';
  const _Words.ko()
      : ko = true,
        title = 'GuBASIC 참조',
        intro = '분석기가 아는 것에서 만든, 모든 컨트롤·함수·객체·형식의 목록입니다. '
            '어떻게 동작하는지는 [LANGUAGE.ko.md](../LANGUAGE.ko.md)에 설명되어 있습니다.',
        controls = '컨트롤',
        functions = '함수',
        objects = '객체와 형식',
        properties = '속성',
        methods = '메서드',
        events = '이벤트',
        otherNames = '다른 BASIC에서 쓰는 이름',
        defaultEvent = '기본 이벤트(더블클릭으로 만듦)',
        notOnForm = '폼에 보이지 않음: 디자이너의 트레이에 둠.',
        type = '형식',
        initial = '처음 값',
        notes = '참고',
        readOnly = '읽기만 함',
        runTimeOnly = '실행 중에만 정함',
        constants = '상수',
        builtinObjects = '내장 객체',
        typeMembers = '형식의 멤버',
        explained = '설명은 [LANGUAGE.ko.md 11절](../../LANGUAGE.ko.md)에 있습니다.',
        back = '[참조 전체](../README.ko.md)',
        language = '[English](README.md)',
        ext = '.ko.md';

  final bool ko;
  final String title, intro, controls, functions, objects, properties;
  final String methods, events, otherNames, defaultEvent, notOnForm, type;
  final String initial, notes, readOnly, runTimeOnly, constants;
  final String builtinObjects, typeMembers, explained, back, language, ext;
}

String _value(Object v) => switch (v) {
      final String s => s.isEmpty ? '""' : '"$s"',
      final bool b => b ? 'True' : 'False',
      final List<Object?> l => l.isEmpty ? '(none)' : '$l',
      _ => '$v',
    };

String _controlPage(ComponentSpec c, _Words w) {
  final b = StringBuffer('# ${c.name}\n\n${w.back}\n\n');
  if (!w.ko) b.write('${_description(c.name)}\n\n');
  b.write('${w.explained}\n\n');
  if (!c.visual && !c.menu) b.write('${w.notOnForm}\n\n');
  b.write('${w.defaultEvent}: `${c.defaultEvent}`\n\n');
  final props = c.properties.values.where((p) => !p.internal).toList();
  if (props.isNotEmpty) {
    b.write(
      '## ${w.properties}\n\n| | ${w.type} | ${w.initial} | ${w.notes} |\n'
      '|---|---|---|---|\n',
    );
    for (final p in props) {
      final notes = [
        if (p.readOnly) w.readOnly,
        if (!p.readOnly && !p.designTime) w.runTimeOnly,
      ].join(', ');
      b.write(
        '| `${p.name}` | ${p.type.displayName} | '
        '${p.readOnly ? '' : '`${_value(p.defaultValue)}`'} | $notes |\n',
      );
    }
    b.write('\n');
  }
  if (c.methods.isNotEmpty) {
    b.write('## ${w.methods}\n\n');
    for (final m in c.methods.values) {
      b.write(
        '- `${_call(m.name, m.parameters, m.returnType)}`'
        '${m.settable ? (w.ko ? ' (대입 가능)' : ' (can be assigned to)') : ''}\n',
      );
    }
    b.write('\n');
  }
  if (c.events.isNotEmpty) {
    b.write('## ${w.events}\n\n');
    for (final e in c.events.values) {
      b.write(
        '- `${e.name}(${e.parameters.map(_param).join(', ')})`\n',
      );
    }
    b.write('\n');
  }
  final others = [
    for (final a in c.aliases) '`$a` → `${c.name}`',
    for (final MapEntry(:key, :value) in c.otherNames.entries)
      '`$key` → ${value.map((v) => '`$v`').join(', ')}',
    for (final MapEntry(:key, :value) in c.otherEvents.entries)
      '`$key` → `$value`',
  ];
  if (others.isNotEmpty) {
    b.write('## ${w.otherNames}\n\n');
    for (final o in others) {
      b.write('- $o\n');
    }
    b.write('\n');
  }
  return '${'$b'.trimRight()}\n';
}

String _functionsPage(_Words w) {
  final b =
      StringBuffer('# ${w.functions}\n\n${w.back.replaceAll('../', '')}\n\n');
  for (final MapEntry(key: group, value: fs) in _functions.entries) {
    b.write('## $group\n\n');
    for (final MapEntry(key: name, value: (en, ko)) in fs.entries) {
      final f = builtinFunctions[name.toLowerCase()]!;
      b.write(
        '- `${_call(f.name, f.parameters, f.returnType)}`: '
        '${w.ko ? ko : en}\n',
      );
    }
    b.write('\n');
  }
  return '${'$b'.trimRight()}\n';
}

/// Structures (D131): what is copied and what is shared, and where
/// GuBASIC differs from Visual Basic .NET, which LANGUAGE §4.1 explains.
const _structuresEn = '''## Structures

A program's own types: `Structure Student … End Structure`, fields only,
in a module for the whole project or in a form for that form.
Explained in [LANGUAGE.md §4.1](../LANGUAGE.md).

- A Structure is copied when it is stored (assigned, passed, returned, put
  into an array or a List), **its array fields too**. A plain array
  assigned to another variable (`y = x`) is **the same array**.
- A field is changed where the value is: `list(0).Score = 95` changes the
  item of a `List(Of Student)`. Visual Basic .NET refuses this (BC30068).
- For Each gives copies (A066). Not done with a Structure: comparing it
  (A063), text (A064), `Object` (A067).
- A value in one expression: `New Student With {.Name = "Kim", .Score = 90}`.
  Lists of items for arrays: `.Choices = {"a", "b", "c", "d"}`,
  `Dim names() As String = {"Kim", "Lee"}`, `Total({4, 5, 6})`. Inside the
  braces a line may break without `_` (LANGUAGE §1, §4).

''';

const _structuresKo = '''## Structure

프로그램이 만드는 형식입니다. `Structure Student … End Structure`로 쓰고
필드만 있으며, 모듈에 두면 프로젝트 전체에서, 폼에 두면 그 폼에서 씁니다.
설명은 [LANGUAGE.ko.md 4.1절](../LANGUAGE.ko.md)에 있습니다.

- Structure는 담을 때(대입, 인수, `Return`, 배열이나 List에 넣기) 복사되고,
  **배열 필드도 함께 복사됩니다**. 그냥 배열을 다른 변수에 대입하면(`y = x`)
  **같은 배열**입니다.
- 필드는 값이 있는 자리에서 바뀝니다. `list(0).Score = 95`는
  `List(Of Student)`의 항목을 바꿉니다. Visual Basic .NET은 이것을 막습니다(BC30068).
- For Each는 복사본을 줍니다(A066). Structure로 하지 않는 것: 비교(A063),
  글(A064), `Object`(A067).
- 값을 식 하나로: `New Student With {.Name = "Kim", .Score = 90}`.
  배열의 항목 목록: `.Choices = {"a", "b", "c", "d"}`,
  `Dim names() As String = {"Kim", "Lee"}`, `Total({4, 5, 6})`. 중괄호
  안에서는 `_` 없이 줄을 바꿀 수 있습니다(LANGUAGE 1절, 4절).

''';

String _objectsPage(_Words w) {
  final b =
      StringBuffer('# ${w.objects}\n\n${w.back.replaceAll('../', '')}\n\n');
  b.write('## ${w.builtinObjects}\n\n');
  for (final name in allBuiltinObjects) {
    final members = builtinObjectMembers(name);
    if (members.isEmpty) continue;
    b.write('### $name\n\n');
    // An object of the component channel (Http, D125) says what it is.
    if (!w.ko && objectComponents.containsKey(name.toLowerCase())) {
      b.write('${_description(name)}\n\n');
    }
    for (final m in members.values) {
      b.write('- `$name.${_member(m)}`\n');
    }
    b.write('\n');
  }
  b.write('## ${w.typeMembers}\n\n');
  for (final t in _types) {
    final members = membersOf(t);
    if (members == null || members.isEmpty) continue;
    b.write('### ${t.displayName}\n\n');
    for (final m in members.values) {
      b.write('- `${_member(m)}`\n');
    }
    b.write('\n');
  }
  b.write(w.ko ? _structuresKo : _structuresEn);
  b.write('## ${w.constants}\n\n');
  for (final MapEntry(:key, :value) in builtinConstants.entries) {
    final shown = value
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n')
        .replaceAll('\t', r'\t');
    b.write('- `$key`: `$shown`\n');
  }
  return '${'$b'.trimRight()}\n';
}

/// The controls, each with a page of its own; the objects of the
/// component channel (Http) are on the objects page.
List<ComponentSpec> get _components {
  final list = controlComponents.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return list;
}

String _index(_Words w) {
  final b = StringBuffer('# ${w.title}\n\n${w.language}\n\n${w.intro}\n\n');
  b.write('## ${w.controls}\n\n');
  for (final c in _components) {
    b.write('- [${c.name}](controls/${c.name}${w.ext})\n');
  }
  b.write(
    '\n## ${w.functions}\n\n[${w.functions}](functions${w.ext})\n\n'
    '## ${w.objects}\n\n[${w.objects}](objects${w.ext})\n',
  );
  return '$b';
}

String _llms() {
  final b = StringBuffer('''
# GuBASIC

> GuBASIC is a Visual Basic-style RAD tool: draw a form, double-click a control, write event handlers in a BASIC dialect and press F5. The same program runs in the IDE's interpreter and in exported web, Windows and macOS apps.

Write GuBASIC code as the documents below describe; it is close to Visual Basic .NET but not the same. Key rules: identifiers are case-insensitive; arrays are zero-based and `Dim a(5)` has six elements; `Mid` and `InStr` count from 1; `And` and `Or` short-circuit; there is no `On Error`, `GoTo`, `Variant`, control array or user-defined class (use `Try … Catch`, `Handles` with `sender`, and `Me.Controls`); every event handler is `Sub control_Event()` and does not run again while it runs.

## Docs

- [Language](https://github.com/kooboom/gubasic/blob/main/docs/LANGUAGE.md): the whole language, its controls and its diagnostics
- [Reference](https://github.com/kooboom/gubasic/blob/main/docs/reference/README.md): every control, function, object and type
- [Your first app](https://github.com/kooboom/gubasic/blob/main/docs/FIRST_APP.md): a five-minute guide

## Reference

''');
  for (final c in _components) {
    b.write(
      '- [${c.name}]($_site/docs/reference/controls/${c.name}.md): '
      '${_firstSentence(_description(c.name))}\n',
    );
  }
  b.write(
    '- [Functions]($_site/docs/reference/functions.md): text, conversion, '
    'math, dates, dialogs, settings\n'
    '- [Objects and types]($_site/docs/reference/objects.md): File, Csv, '
    'Http, Database, Json, Keys, Table, PdfDocument and the others\n\n'
    '## Optional\n\n'
    '- [Design](https://github.com/kooboom/gubasic/blob/main/docs/DESIGN.md): '
    'how GuBASIC is built, and its decisions\n'
    '- [Examples](https://github.com/kooboom/gubasic/tree/main/examples): '
    'hello, calculator, quiz, scores and others\n',
  );
  return '$b';
}

String _firstSentence(String text) {
  final cut = text.replaceAll(RegExp(r'\s*\(docs/DESIGN\.md [^)]*\)'), '');
  final end = cut.indexOf('. ');
  return (end < 0 ? cut : cut.substring(0, end + 1)).trim();
}

String _llmsFull(String language) {
  const w = _Words.en();
  final b = StringBuffer(
    '# GuBASIC: the whole language and its reference\n\n'
    'Generated for AI assistants (llms.txt). The language guide comes '
    'first, then the reference of every control, function, object and '
    'type.\n\n---\n\n',
  );
  b.write(language.trimRight());
  b.write('\n\n---\n\n# Reference\n\n');
  for (final c in _components) {
    b.write(_controlPage(c, w).replaceFirst('${w.back}\n\n', ''));
    b.write('\n');
  }
  b.write(_functionsPage(w)
      .replaceFirst('${w.back.replaceAll('../', '')}\n\n', ''));
  b.write('\n');
  b.write(
      _objectsPage(w).replaceFirst('${w.back.replaceAll('../', '')}\n\n', ''));
  return '$b';
}

void main(List<String> args) {
  final check = args.contains('--check');
  for (final g in _functions.values.expand((f) => f.keys)) {
    if (!builtinFunctions.containsKey(g.toLowerCase())) {
      stderr.writeln('$g is described but is no function');
      exit(1);
    }
  }
  final described = {
    for (final f in _functions.values.expand((f) => f.keys)) f.toLowerCase(),
  };
  final missing = builtinFunctions.keys.where((k) => !described.contains(k));
  if (missing.isNotEmpty) {
    stderr.writeln('Describe these functions in tool/gen_reference.dart: '
        '${missing.join(', ')}');
    exit(1);
  }
  final language = File('$_root/docs/LANGUAGE.md').readAsStringSync();
  final files = <String, String>{
    for (final w in const [_Words.en(), _Words.ko()]) ...{
      'docs/reference/README${w.ext}': _index(w),
      'docs/reference/functions${w.ext}': _functionsPage(w),
      'docs/reference/objects${w.ext}': _objectsPage(w),
      for (final c in _components)
        'docs/reference/controls/${c.name}${w.ext}': _controlPage(c, w),
    },
    'llms.txt': _llms(),
    'llms-full.txt': _llmsFull(language),
  };
  var stale = <String>[];
  for (final MapEntry(key: path, value: text) in files.entries) {
    final file = File('$_root/$path');
    final now = file.existsSync() ? file.readAsStringSync() : null;
    if (now == text) continue;
    if (check) {
      stale.add(path);
    } else {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
    }
  }
  final known = files.keys.toSet();
  final extra = Directory('$_root/docs/reference')
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.substring('$_root/'.length).replaceAll(r'\', '/'))
      .where((p) => !known.contains(p))
      .toList();
  if (check) {
    if (stale.isNotEmpty || extra.isNotEmpty) {
      stderr.writeln(
        'The reference is out of date: ${[...stale, ...extra].join(', ')}. '
        'Run dart run tool/gen_reference.dart in packages/gubasic_lang.',
      );
      exit(1);
    }
    stdout.writeln('The reference is up to date.');
  } else {
    for (final p in extra) {
      File('$_root/$p').deleteSync();
    }
    stdout.writeln('Wrote ${files.length} files.');
  }
}
