import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/i18n.dart';
import '../model/result_tab.dart';
import '../model/run_state.dart';
import '../model/samples.dart';
import '../model/snapshot.dart';
import 'editor.dart';
import 'html.dart';
import 'run_controller.dart';
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
  web.HTMLElement? _outputBox;

  late final RunController _run = RunController(
    onStatus: () {
      if (_activeTab == 'run') _render();
    },
    onOutput: _appendOutput,
  );

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
    _editor.source = loadSetting(_sourceKey) ?? starterSample;

    _editor.onInput(_update);
    onClick(byId('sample-starter'), () => _loadSample(starterSample));
    onClick(byId('sample-readme'), () => _loadSample(readmeSample));
    onClick(byId('sample-errors'), () => _loadSample(errorSample));
    onClick(_languageButton, () {
      _locale = _locale.other;
      saveSetting(_localeKey, _locale.code);
      _applyLocale();
    });

    // Ctrl+Enter (⌘+Enter on a Mac) runs the program.
    web.document.addEventListener(
        'keydown',
        ((web.KeyboardEvent e) {
          if (e.key == 'Enter' && (e.ctrlKey || e.metaKey)) {
            e.preventDefault();
            _startRun();
          }
        }).toJS);

    _applyLocale();
    _update();
  }

  void _startRun() {
    if (_run.isRunning) return;
    _activeTab = 'run';
    _render();
    _run.run(_snapshot, _locale);
  }

  void _showTab(String id) {
    _activeTab = id;
    _render();
  }

  void _appendOutput(OutputEntry entry) {
    final box = _outputBox;
    if (_activeTab != 'run' || box == null || !box.isConnected) return;
    box.append(outputLine(entry, _context()));
    box.scrollTop = box.scrollHeight.toDouble();
  }

  TabContext _context() => TabContext(
        snapshot: _snapshot,
        locale: _locale,
        editor: _editor,
        run: _run,
        startRun: _startRun,
        showTab: _showTab,
        setOutputBox: (box) => _outputBox = box,
      );

  void _loadSample(String sample) {
    _editor.source = sample;
    _update();
  }

  /// Re-lexes the source and redraws everything that depends on it.
  void _update() {
    // I5: editing stops a running program; run again to use the new code.
    if (_run.isRunning) _run.stop();
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
    _tabContent.replaceChildren(view(_context()));
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
