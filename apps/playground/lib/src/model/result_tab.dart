import 'i18n.dart';
import 'snapshot.dart';

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
}

class TokensTab extends ResultTab {
  const TokensTab();

  @override
  String get id => 'tokens';

  @override
  UiText get title => UiText.tabTokens;
}

class DiagnosticsTab extends ResultTab {
  const DiagnosticsTab();

  @override
  String get id => 'diagnostics';

  @override
  UiText get title => UiText.tabDiagnostics;

  @override
  int? badge(Snapshot snapshot) => snapshot.diagnostics.length;
}

/// The tabs of the result panel, in display order.
const List<ResultTab> resultTabs = [TokensTab(), DiagnosticsTab()];
