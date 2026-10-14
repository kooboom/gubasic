import 'dart:js_interop';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:web/web.dart' as web;

import '../model/i18n.dart';
import '../model/view_model.dart';
import 'html.dart';

/// The source textarea plus a gutter of line numbers that marks lines
/// with diagnostics.
class Editor {
  Editor(this.pane, this.textarea, this.gutter) {
    textarea.addEventListener(
        'scroll',
        ((web.Event _) {
          gutter.scrollTop = textarea.scrollTop;
        }).toJS);
  }

  /// Must match `--line-height` in styles.css.
  static const lineHeight = 20;

  final web.HTMLElement pane;
  final web.HTMLTextAreaElement textarea;
  final web.HTMLElement gutter;

  String get source => textarea.value;

  set source(String value) {
    textarea.value = value;
    textarea.scrollTop = 0;
    textarea.scrollLeft = 0;
  }

  void onInput(void Function() handler) =>
      textarea.addEventListener('input', ((web.Event _) => handler()).toJS);

  /// Redraws the gutter for [source] and its diagnostics.
  void showDiagnostics(List<Diagnostic> diagnostics, Locale locale) {
    final byLine = diagnosticsByLine(diagnostics);
    final lines = lineCount(source);
    final fragment = web.document.createDocumentFragment();
    for (var line = 1; line <= lines; line++) {
      final row = el('div', className: 'line', text: '$line');
      final here = byLine[line];
      if (here != null) {
        row.classList.add('has-diagnostic');
        row.title = [
          locale[UiText.diagnosticsOnLine],
          for (final d in here)
            '${d.code.code}: ${d.formatMessage(locale.diagnosticMessages)}',
        ].join('\n');
        onClick(row, () => jumpTo(here.first));
      }
      fragment.append(row);
    }
    fragment.append(el('div', className: 'spacer'));
    gutter.replaceChildren(fragment);
    gutter.scrollTop = textarea.scrollTop;
  }

  /// Selects the text of [d] and scrolls it into view.
  void jumpTo(Diagnostic d) {
    final (start, end) = selectionFor(d, source.length);
    if (web.window.matchMedia('(max-width: 799px)').matches) {
      pane.scrollIntoView();
    }
    textarea.focus();
    textarea.setSelectionRange(start, end);
    final target = (d.line - 1) * lineHeight - textarea.clientHeight / 3;
    textarea.scrollTop = target < 0 ? 0 : target;
  }
}
