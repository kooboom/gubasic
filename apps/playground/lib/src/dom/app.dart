import 'package:web/web.dart' as web;

import '../model/i18n.dart';
import '../model/result_tab.dart';
import '../model/samples.dart';
import '../model/snapshot.dart';
import 'editor.dart';
import 'html.dart';
import 'tab_views.dart';

const _localeKey = 'gubasic.playground.locale';
const _sourceKey = 'gubasic.playground.source';

class App {
  late final Editor _editor;
  late final web.HTMLElement _tabBar;
  late final web.HTMLElement _tabContent;
  late final web.HTMLElement _languageButton;

  Locale _locale = Locale.en;
  Snapshot _snapshot = Snapshot('');
  String _activeTab = resultTabs.first.id;

  void start() {
    for (final tab in resultTabs) {
      assert(tabViews.containsKey(tab.id), 'No view for tab "${tab.id}"');
    }

    _editor = Editor(
      byId<web.HTMLElement>('editor-pane'),
      byId<web.HTMLTextAreaElement>('source'),
      byId<web.HTMLElement>('gutter'),
    );
    _tabBar = byId<web.HTMLElement>('tabs');
    _tabContent = byId<web.HTMLElement>('tab-content');
    _languageButton = byId<web.HTMLElement>('switch-language');

    _locale = Locale.fromCode(loadSetting(_localeKey));
    _editor.source = loadSetting(_sourceKey) ?? readmeSample;

    _editor.onInput(_update);
    onClick(byId('sample-readme'), () => _loadSample(readmeSample));
    onClick(byId('sample-errors'), () => _loadSample(errorSample));
    onClick(_languageButton, () {
      _locale = _locale.other;
      saveSetting(_localeKey, _locale.code);
      _applyLocale();
    });

    _applyLocale();
    _update();
  }

  void _loadSample(String sample) {
    _editor.source = sample;
    _update();
  }

  /// Re-lexes the source and redraws everything that depends on it.
  void _update() {
    _snapshot = Snapshot(_editor.source);
    saveSetting(_sourceKey, _snapshot.source);
    _render();
  }

  void _applyLocale() {
    web.document.documentElement!.setAttribute('lang', _locale.code);
    final labelled = web.document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < labelled.length; i++) {
      final e = labelled.item(i)! as web.Element;
      e.textContent =
          _locale[UiText.values.byName(e.getAttribute('data-i18n')!)];
    }
    final ariaLabelled = web.document.querySelectorAll('[data-i18n-label]');
    for (var i = 0; i < ariaLabelled.length; i++) {
      final e = ariaLabelled.item(i)! as web.Element;
      e.setAttribute('aria-label',
          _locale[UiText.values.byName(e.getAttribute('data-i18n-label')!)]);
    }
    web.document.title = _locale[UiText.title];
    _render();
  }

  void _render() {
    _editor.showDiagnostics(_snapshot.diagnostics, _locale);
    _renderTabBar();
    final view = tabViews[_activeTab]!;
    _tabContent.replaceChildren(view(_snapshot, _locale, _editor));
  }

  void _renderTabBar() {
    final buttons = <web.HTMLElement>[];
    for (final tab in resultTabs) {
      final button = el('button', text: _locale[tab.title])
        ..setAttribute('type', 'button')
        ..setAttribute('role', 'tab')
        ..setAttribute('aria-selected', '${tab.id == _activeTab}');
      if (tab.badge(_snapshot) case final count?) {
        final tone = switch (tab.badgeTone(_snapshot)) {
          BadgeTone.error => 'badge error',
          BadgeTone.warning => 'badge warning',
          BadgeTone.neutral => 'badge',
        };
        button.append(el('span', className: tone, text: '$count'));
      }
      onClick(button, () {
        _activeTab = tab.id;
        _render();
      });
      buttons.add(button);
    }
    _tabBar.replaceChildren(_fragment(buttons));
  }

  web.DocumentFragment _fragment(List<web.Node> nodes) {
    final f = web.document.createDocumentFragment();
    for (final n in nodes) {
      f.append(n);
    }
    return f;
  }
}
