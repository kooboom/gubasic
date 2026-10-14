import 'i18n.dart';
import 'snapshot.dart';
import 'view_model.dart';

/// The colour of a tab badge. Colour is never the only signal: the
/// Diagnostics tab also spells out the counts per severity.
enum BadgeTone { neutral, warning, error }

/// A tab of the result panel.
///
/// This part holds what can be tested without a browser; the DOM side
/// lives in `lib/src/dom/tab_views.dart`. To add a tab (AST, Output, …):
/// add a [ResultTab] to [resultTabs] and a view for its [id].
abstract class ResultTab {
  const ResultTab();

  String get id;
  UiText get title;

  /// A number shown next to the title, or null for none.
  int? badge(Snapshot snapshot) => null;

  BadgeTone badgeTone(Snapshot snapshot) => BadgeTone.neutral;
}

class TokensTab extends ResultTab {
  const TokensTab();

  @override
  String get id => 'tokens';

  @override
  UiText get title => UiText.tabTokens;
}

class AstTab extends ResultTab {
  const AstTab();

  @override
  String get id => 'ast';

  @override
  UiText get title => UiText.tabAst;
}

class DiagnosticsTab extends ResultTab {
  const DiagnosticsTab();

  @override
  String get id => 'diagnostics';

  @override
  UiText get title => UiText.tabDiagnostics;

  @override
  int? badge(Snapshot snapshot) => snapshot.diagnostics.length;

  /// Red if there is any error, amber if there are only warnings.
  @override
  BadgeTone badgeTone(Snapshot snapshot) {
    final (errors, warnings) = severityCounts(snapshot.diagnostics);
    if (errors > 0) return BadgeTone.error;
    if (warnings > 0) return BadgeTone.warning;
    return BadgeTone.neutral;
  }
}

/// The tabs of the result panel, in display order.
const List<ResultTab> resultTabs = [TokensTab(), AstTab(), DiagnosticsTab()];
