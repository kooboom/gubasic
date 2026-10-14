import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:web/web.dart' as web;

import '../model/i18n.dart';
import '../model/snapshot.dart';
import '../model/view_model.dart';
import 'html.dart';

/// What a tab can ask the editor to do.
abstract interface class SourceNavigator {
  void jumpTo(Diagnostic d);
  void select(int start, int end);
}

/// Draws the content of one result tab.
typedef TabView = web.HTMLElement Function(
    Snapshot snapshot, Locale locale, SourceNavigator editor);

/// DOM views, keyed by [ResultTab.id]. Every tab in `resultTabs` needs one.
const Map<String, TabView> tabViews = {
  'tokens': _tokensView,
  'ast': _astView,
  'diagnostics': _diagnosticsView,
};

web.HTMLElement _tokensView(
    Snapshot snapshot, Locale locale, SourceNavigator _) {
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
    Snapshot snapshot, Locale locale, SourceNavigator editor) {
  final diagnostics = snapshot.diagnostics;
  if (diagnostics.isEmpty) {
    return el('p', className: 'empty', text: locale[UiText.noDiagnostics]);
  }
  final (errors, warnings) = severityCounts(diagnostics);
  final summary = el('p',
      className: 'summary', text: diagnosticSummary(locale, errors, warnings));
  final list = el('ul', className: 'diagnostics');
  for (final d in diagnostics) {
    final severity = d.isWarning ? 'warning' : 'error';
    final button = el('button')
      ..setAttribute('type', 'button')
      ..append(el('span',
          className: 'sev',
          text: locale[
              d.isWarning ? UiText.severityWarning : UiText.severityError]))
      ..append(el('span', className: 'code', text: d.code.code))
      ..append(el('span', className: 'pos', text: '${d.line}:${d.column}'))
      ..append(el('span',
          className: 'msg', text: d.formatMessage(locale.diagnosticMessages)));
    onClick(button, () => editor.jumpTo(d));
    list.append(el('li', className: severity)..append(button));
  }
  return el('div')
    ..append(summary)
    ..append(list);
}

/// The syntax tree as nested, foldable lists. Clicking a node's label
/// selects its source.
web.HTMLElement _astView(
    Snapshot snapshot, Locale locale, SourceNavigator editor) {
  final lines = snapshot.lineMap;

  web.HTMLElement label(Node node) {
    final button = el('button', className: 'node')
      ..setAttribute('type', 'button')
      ..append(el('span', className: 'label', text: node.label))
      ..append(el('span',
          className: 'range', text: rangeText(lines, node.start, node.end)));
    if (node is ErrorExpr || node is ErrorStmt) button.classList.add('error');
    onClick(button, () => editor.select(node.start, node.end));
    return button;
  }

  web.HTMLElement build(Node node) {
    if (node.children.isEmpty) {
      return el('li', className: 'leaf')..append(label(node));
    }
    final details = el('details')..setAttribute('open', '');
    final summary = el('summary')..append(label(node));
    final list = el('ul');
    for (final child in node.children) {
      list.append(build(child));
    }
    details
      ..append(summary)
      ..append(list);
    return el('li')..append(details);
  }

  return el('ul', className: 'ast')..append(build(snapshot.unit));
}
