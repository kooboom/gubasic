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

  test('starts with the README example and no diagnostics', () {
    expect(_source.value, readmeSample);
    expect(_texts('#tabs button'), ['Tokens', 'Diagnostics0']);
    expect(web.document.querySelectorAll('.tokens tbody tr').length,
        greaterThan(50));
    expect(web.document.querySelectorAll('.has-diagnostic').length, 0);
  });

  test('typing re-lexes immediately and marks the gutter', () {
    _type('x = 1\ny = "open');
    expect(_texts('#tabs button').last, 'Diagnostics1');
    expect(_texts('.gutter .has-diagnostic'), ['2']);
  });

  test('the error example shows every diagnostic; clicking one jumps', () {
    _click('#sample-errors');
    _click('#tabs button:nth-child(2)');
    expect(_texts('.diagnostics .code'),
        ['L002', 'L001', 'L003', 'L004', 'L005', 'L006']);

    _click('.diagnostics li:nth-child(4) button'); // L004 at "@"
    final start = _source.selectionStart;
    final end = _source.selectionEnd;
    expect(_source.value.substring(start, end), '@');
  });

  test('clicking a marked line in the gutter jumps to its problem', () {
    _type('ok\nDim 점수');
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
    _click('#tabs button:nth-child(2)');
    expect(_texts('.diagnostics .msg').first, contains('한글은 문자열'));
    expect(_texts('[data-i18n="footerPreview"]'), ['GuBASIC 놀이터 — 개발 미리보기']);
  });
}
