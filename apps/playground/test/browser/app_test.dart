@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:gubasic_playground/src/dom/app.dart';
import 'package:gubasic_playground/src/dom/tab_views.dart';
import 'package:gubasic_playground/src/model/result_tab.dart';
import 'package:gubasic_playground/src/model/samples.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

/// The body of web/index.html, minus the script and stylesheet.
const _skeleton = '''
<button id="sample-starter" data-i18n="sampleStarter"></button>
<button id="sample-readme" data-i18n="sampleReadme"></button>
<button id="sample-errors" data-i18n="sampleErrors"></button>
<button id="switch-language" data-i18n="switchLanguage"></button>
<section id="editor-pane">
  <div id="gutter" class="gutter"></div>
  <textarea id="source" data-i18n-label="editorLabel"></textarea>
</section>
<div id="tabs"></div>
<div id="tab-content"></div>
<span data-i18n="footerPreview"></span>
''';

web.HTMLTextAreaElement get _source =>
    web.document.getElementById('source')! as web.HTMLTextAreaElement;

List<String> _texts(String selector) {
  final nodes = web.document.querySelectorAll(selector);
  return [
    for (var i = 0; i < nodes.length; i++) nodes.item(i)!.textContent ?? '',
  ];
}

void _click(String selector) =>
    (web.document.querySelector(selector)! as web.HTMLElement).click();

void _type(String text) {
  _source.value = text;
  _source.dispatchEvent(web.Event('input'));
}

/// Waits until [condition] holds (the interpreter runs asynchronously).
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 500 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'timed out waiting');
}

String _status() => _texts('.run-status').join();

Future<void> _runAndWait(String done) async {
  _click('#run-button');
  await _until(() => _status() == done);
}

web.HTMLInputElement? get _dialogInput =>
    web.document.querySelector('.dialog-input') as web.HTMLInputElement?;

void main() {
  setUp(() {
    try {
      web.window.localStorage.clear();
    } catch (_) {}
    web.document.body!.innerHTML = _skeleton.toJS;
    App().start();
  });

  test('every result tab has a view', () {
    for (final tab in resultTabs) {
      expect(tabViews.containsKey(tab.id), isTrue, reason: tab.id);
    }
  });

  test('starts with the starter example and no diagnostics', () {
    expect(_source.value, starterSample);
    expect(_texts('#tabs button'), ['Tokens', 'AST', 'Diagnostics0', 'Run']);
    expect(web.document.querySelectorAll('.tokens tbody tr').length,
        greaterThan(50));
    expect(web.document.querySelectorAll('.has-diagnostic').length, 0);
  });

  test('typing re-lexes immediately and marks the gutter', () {
    _type('Sub A()\nDim y As String = "open\nDebug.Print(y)\nEnd Sub');
    expect(_texts('#tabs button')[2], 'Diagnostics1');
    expect(_texts('.gutter .has-diagnostic'), ['2']);
  });

  test('the error example shows every diagnostic; clicking one jumps', () {
    _click('#sample-errors');
    _click('#tabs button:nth-child(3)');
    expect(_texts('.diagnostics .code'), [
      'L002', 'L001', 'L003', 'L004', 'L005', 'L006', 'A026', //
      'P006', 'P011', 'P007', 'P013', 'A010', 'L002', 'A002',
    ]);
    expect(_texts('.summary'), ['13 errors · 1 warning']);
    expect(_texts('.diagnostics li.warning .sev'), ['Warning']);
    expect(_texts('.diagnostics li.error .sev'), everyElement('Error'));
    expect(_texts('#tabs .badge.error'), ['14']);

    _click('.diagnostics li:nth-child(4) button'); // L004 at "@"
    final start = _source.selectionStart;
    final end = _source.selectionEnd;
    expect(_source.value.substring(start, end), '@');
  });

  test('clicking a marked line in the gutter jumps to its problem', () {
    _type('Sub A()\nDim 점수 As Integer = 1\nDebug.Print(점수)\nEnd Sub');
    _click('.gutter .has-diagnostic');
    expect(
        _source.value.substring(_source.selectionStart, _source.selectionEnd),
        '점수');
  });

  test('switching to Korean translates the UI and the diagnostics', () {
    _click('#sample-errors');
    _click('#switch-language');
    expect(web.document.documentElement!.getAttribute('lang'), 'ko');
    expect(_texts('#switch-language'), ['English']);
    expect(_texts('#tabs button').first, '토큰');
    _click('#tabs button:nth-child(3)');
    expect(_texts('.diagnostics .msg').first, contains('한글은 문자열'));
    expect(_texts('#tabs button:nth-child(2)'), ['구문 트리']);
    expect(_texts('[data-i18n="footerPreview"]'), ['GuBASIC 놀이터 — 개발 미리보기']);
  });

  test('the AST tab shows the tree; clicking a node selects its source', () {
    _click('#tabs button:nth-child(2)');
    final labels = _texts('.ast .label');
    expect(labels.first, 'CompilationUnit');
    expect(labels, containsAll(['Sub Main', 'Function Average']));

    final buttons = web.document.querySelectorAll('.ast button.node');
    for (var i = 0; i < buttons.length; i++) {
      final b = buttons.item(i)! as web.HTMLElement;
      if (b.textContent!.startsWith('Function Average')) {
        b.click();
        break;
      }
    }
    final selected =
        _source.value.substring(_source.selectionStart, _source.selectionEnd);
    expect(selected, startsWith('Function Average('));
    expect(selected, endsWith('End Function'));
  });

  test('parser problems mark the gutter too', () {
    _type('Sub A()\nIf True Then\nEnd Sub');
    expect(_texts('.gutter .has-diagnostic'), ['2']);
    expect(_texts('#tabs button')[2], 'Diagnostics1');
  });

  test('warnings alone: amber badge, diamond gutter mark, text labels', () {
    _type('Sub A()\nDim unused As Integer\nEnd Sub');
    expect(_texts('#tabs .badge.warning'), ['1']);
    expect(_texts('.gutter .warning-only'), ['2']);
    _click('#tabs button:nth-child(3)');
    expect(_texts('.summary'), ['1 warning']);
    _click('#switch-language');
    expect(_texts('.summary'), ['경고 1']);
    expect(_texts('.diagnostics .sev'), ['경고']);
    expect(_texts('.diagnostics .msg').single, contains('쓰지 않았습니다'));
  });

  test('analyzer problems are listed and marked too', () {
    _type('Sub A()\nDim n As Integer = 2.5\nDebug.Print(n & totl)\nEnd Sub');
    _click('#tabs button:nth-child(3)');
    expect(_texts('.diagnostics .code'), ['A010', 'A001']);
    expect(_texts('.gutter .has-diagnostic'), ['2', '3']);
  });

  test('the README example can still be loaded; its control is explained', () {
    _click('#sample-readme');
    expect(_source.value, readmeSample);
    _click('#tabs button:nth-child(3)');
    expect(_texts('.diagnostics .code'), ['A003']);
    expect(_texts('.diagnostics .msg').single, contains('form designer'));
    _click('#sample-starter');
    expect(_source.value, starterSample);
  });

  group('Run tab', () {
    test('the starter example runs and prints its results', () async {
      _click('#tabs button:nth-child(4)');
      expect(_status(), 'Press Run to start the program (Ctrl+Enter).');
      await _runAndWait('Finished.');
      expect(_texts('.out-line'), [
        'Sum of 1 to 10: 55',
        'Average of 3 and 4: 3.5',
        'Hello, Kim',
        'Hello, Lee',
      ]);
    });

    test('errors block Run and say why; warnings do not (D23)', () async {
      _click('#sample-errors');
      _click('#tabs button:nth-child(4)');
      expect(
          web.document.querySelector('#run-button')!.hasAttribute('disabled'),
          isTrue);
      expect(
          _texts('.run-blocked').single, startsWith('Fix the 13 errors first'));
      _click('.run-blocked button');
      expect(_texts('#tabs button[aria-selected="true"]').single,
          startsWith('Diagnostics'));

      _type('Sub Main()\nDim unused As Integer\nDebug.Print("ran")\nEnd Sub');
      _click('#tabs button:nth-child(4)');
      await _runAndWait('Finished.');
      expect(_texts('.out-line'), ['ran']);
    });

    test('MsgBox and InputBox open a dialog inside the page', () async {
      _type('Sub Main()\nDim name As String = InputBox("Name?", "Hi", "Kim")\n'
          'MsgBox("Hello, " & name)\nDebug.Print("done")\nEnd Sub');
      _click('#tabs button:nth-child(4)');
      _click('#run-button');
      await _until(() => _dialogInput != null);
      expect(_texts('.dialog-title'), ['Hi']);
      expect(_dialogInput!.value, 'Kim');
      _dialogInput!.value = 'Lee';
      _click('.dialog .primary');
      await _until(() => _texts('.dialog-message').join() == 'Hello, Lee');
      _click('.dialog .primary');
      await _until(() => _status() == 'Finished.');
      expect(_texts('.out-line'), ['done']);
      expect(web.document.querySelector('.dialog-backdrop'), isNull);
    });

    test('Stop ends an endless loop; Stop also closes a waiting dialog',
        () async {
      _type('Sub Main()\nDo\nLoop\nEnd Sub');
      _click('#tabs button:nth-child(4)');
      _click('#run-button');
      await _until(() => _status() == 'Running…');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      _click('#stop-button');
      await _until(() => _status() == 'Stopped.');

      _type('Sub Main()\nMsgBox("wait")\nEnd Sub');
      _click('#run-button');
      await _until(() => web.document.querySelector('.dialog') != null);
      _click('#stop-button');
      await _until(() => _status() != 'Running…');
      expect(web.document.querySelector('.dialog-backdrop'), isNull);
    });

    test('a run-time error is shown; clicking it selects the line', () async {
      _type('Sub Main()\nDim zero As Integer = 0\nDebug.Print("a")\n'
          'Debug.Print(1 \\ zero)\nEnd Sub');
      _click('#tabs button:nth-child(4)');
      await _runAndWait('Stopped by an error. Click it to see the line.');
      expect(_texts('.out-line'), ['a']);
      expect(_texts('.out-error .code'), ['R002']);
      expect(_texts('.out-error .pos'), ['4:13']);
      _click('.out-error');
      expect(
          _source.value.substring(_source.selectionStart, _source.selectionEnd),
          '1 \\ zero');
    });

    test('I5: editing the code stops a running program', () async {
      _type('Sub Main()\nDo\nLoop\nEnd Sub');
      _click('#tabs button:nth-child(4)');
      _click('#run-button');
      await _until(() => _status() == 'Running…');
      _type('Sub Main()\nDo\nLoop\nEnd Sub\n');
      await _until(() => _status() == 'Stopped.');
    });

    test('without Sub Main or Form_Load it says what to add', () async {
      _type('Sub Other()\nEnd Sub');
      _click('#tabs button:nth-child(4)');
      await _runAndWait('Add Sub Main() to run the program.');
    });

    test('Ctrl+Enter runs', () async {
      web.document.dispatchEvent(web.KeyboardEvent(
          'keydown', web.KeyboardEventInit(key: 'Enter', ctrlKey: true)));
      await _until(() => _status() == 'Finished.');
      expect(_texts('#tabs button[aria-selected="true"]').single, 'Run');
    });

    test('in Korean: labels and run-time messages', () async {
      _click('#switch-language');
      _type(
          'Sub Main()\nDim big As Integer = Integer.MaxValue\nbig = big + 1\nEnd Sub');
      _click('#tabs button:nth-child(4)');
      expect(_texts('#run-button'), ['▶ 실행']);
      await _runAndWait('오류로 멈췄습니다. 오류를 누르면 그 줄로 갑니다.');
      expect(_texts('.out-error .msg').single, startsWith('계산 결과가 Integer 범위'));
    });
  });
}
