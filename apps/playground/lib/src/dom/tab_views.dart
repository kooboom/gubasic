import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:web/web.dart' as web;

import '../model/i18n.dart';
import '../model/run_state.dart';
import '../model/snapshot.dart';
import '../model/view_model.dart';
import 'html.dart';
import 'run_controller.dart';

/// What a tab can ask the editor to do.
abstract interface class SourceNavigator {
  void jumpTo(Diagnostic d);
  void select(int start, int end);
}

/// What a tab view can use: the current program, the language, the
/// editor, and the Run tab's controls.
class TabContext {
  TabContext({
    required this.snapshot,
    required this.locale,
    required this.editor,
    required this.run,
    required this.startRun,
    required this.showTab,
    required this.setOutputBox,
  });

  final Snapshot snapshot;
  final Locale locale;
  final SourceNavigator editor;
  final RunController run;
  final void Function() startRun;
  final void Function(String tabId) showTab;

  /// The Run tab hands over its output box, so that new lines can be
  /// appended without redrawing the tab.
  final void Function(web.HTMLElement box) setOutputBox;
}

/// Draws the content of one result tab.
typedef TabView = web.HTMLElement Function(TabContext c);

/// DOM views, keyed by [ResultTab.id]. Every tab in `resultTabs` needs one.
const Map<String, TabView> tabViews = {
  'tokens': _tokensView,
  'ast': _astView,
  'diagnostics': _diagnosticsView,
  'run': _runView,
};

web.HTMLElement _tokensView(TabContext c) {
  final snapshot = c.snapshot;
  final locale = c.locale;
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

web.HTMLElement _diagnosticsView(TabContext c) {
  final snapshot = c.snapshot;
  final locale = c.locale;
  final editor = c.editor;
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
web.HTMLElement _astView(TabContext c) {
  final snapshot = c.snapshot;
  final editor = c.editor;
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

/// The Run tab: Run and Stop, the status, and the output window
/// (Debug.Print lines and the run-time error, which jumps to its line).
web.HTMLElement _runView(TabContext c) {
  final locale = c.locale;
  final state = c.run.state;
  final errors = c.snapshot.diagnostics.where((d) => d.isError).length;

  final runButton =
      el('button', className: 'primary', text: locale[UiText.runButton])
        ..setAttribute('type', 'button')
        ..id = 'run-button';
  if (errors > 0 || state.isRunning) runButton.setAttribute('disabled', '');
  onClick(runButton, c.startRun);

  final stopButton = el('button', text: locale[UiText.stopButton])
    ..setAttribute('type', 'button')
    ..id = 'stop-button';
  if (!state.isRunning) stopButton.setAttribute('disabled', '');
  onClick(stopButton, c.run.stop);

  final toolbar = el('div', className: 'run-toolbar')
    ..append(runButton)
    ..append(stopButton)
    ..append(
        el('span', className: 'run-status', text: locale[state.statusText]));

  final view = el('div', className: 'run')..append(toolbar);
  if (errors > 0 && !state.isRunning) {
    final show = el('button', text: locale[UiText.showProblems])
      ..setAttribute('type', 'button');
    onClick(show, () => c.showTab('diagnostics'));
    view.append(
        el('p', className: 'run-blocked', text: runBlockedText(locale, errors))
          ..append(show));
  }

  final box = el('div', className: 'output')
    ..setAttribute('role', 'log')
    ..setAttribute('aria-live', 'polite');
  for (final entry in state.output) {
    box.append(outputLine(entry, c));
  }
  c.setOutputBox(box);
  return view..append(box);
}

/// One line of the output window.
web.HTMLElement outputLine(OutputEntry entry, TabContext c) {
  switch (entry) {
    case PrintedLine(:final text):
      return el('div', className: 'out-line', text: text);
    case ErrorLine(:final error):
      final button = el('button', className: 'out-error')
        ..setAttribute('type', 'button')
        ..append(el('span', className: 'code', text: error.code.code))
        ..append(
            el('span', className: 'pos', text: '${error.line}:${error.column}'))
        ..append(el('span',
            className: 'msg',
            text: error.formatMessage(c.locale.diagnosticMessages)));
      onClick(button, () => c.editor.jumpTo(error));
      return button;
  }
}
