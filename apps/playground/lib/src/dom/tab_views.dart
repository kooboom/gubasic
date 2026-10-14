import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:web/web.dart' as web;

import '../model/i18n.dart';
import '../model/snapshot.dart';
import '../model/view_model.dart';
import 'html.dart';

typedef JumpTo = void Function(Diagnostic d);

/// Draws the content of one result tab.
typedef TabView = web.HTMLElement Function(
    Snapshot snapshot, Locale locale, JumpTo jumpTo);

/// DOM views, keyed by [ResultTab.id]. Every tab in `resultTabs` needs one.
const Map<String, TabView> tabViews = {
  'tokens': _tokensView,
  'diagnostics': _diagnosticsView,
};

web.HTMLElement _tokensView(Snapshot snapshot, Locale locale, JumpTo _) {
  final table = el('table', className: 'tokens');
  final head = el('tr');
  for (final title in [
    '#',
    locale[UiText.columnPosition],
    locale[UiText.columnKind],
    locale[UiText.columnText],
    locale[UiText.columnValue],
  ]) {
    head.append(el('th', text: title));
  }
  table.append(el('thead')..append(head));

  final body = el('tbody');
  var index = 0;
  for (final row in tokenRows(snapshot.lexResult)) {
    final tr = el('tr',
        className: row.isComment
            ? 'comment'
            : row.isError
                ? 'error'
                : null);
    tr.append(
        el('td', className: 'num', text: row.isComment ? '' : '${index++}'));
    tr.append(el('td', text: row.position));
    final kind = el('td', text: row.kind);
    if (row.tag case final tag?) {
      kind.append(el('span', className: 'tag', text: locale[tag]));
    }
    tr.append(kind);
    tr.append(el('td', text: row.text));
    tr.append(el('td', text: row.value));
    body.append(tr);
  }
  table.append(body);
  return table;
}

web.HTMLElement _diagnosticsView(
    Snapshot snapshot, Locale locale, JumpTo jumpTo) {
  final diagnostics = snapshot.diagnostics;
  if (diagnostics.isEmpty) {
    return el('p', className: 'empty', text: locale[UiText.noDiagnostics]);
  }
  final list = el('ul', className: 'diagnostics');
  for (final d in diagnostics) {
    final button = el('button')
      ..setAttribute('type', 'button')
      ..append(el('span', className: 'code', text: d.code.code))
      ..append(el('span', className: 'pos', text: '${d.line}:${d.column}'))
      ..append(el('span',
          className: 'msg', text: d.formatMessage(locale.diagnosticMessages)));
    onClick(button, () => jumpTo(d));
    list.append(el('li')..append(button));
  }
  return list;
}
