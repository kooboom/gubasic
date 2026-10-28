import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A form's menu bar (docs/DESIGN.md D106): in the window, or for the
/// system's menu bar on macOS.
void main() {
  final events = <String>[];

  GbControlState menu(
    String name,
    String caption, {
    String? container,
    bool checked = false,
    bool enabled = true,
    String shortcut = '',
  }) => GbControlState(name, GbControlKind.menu, {
    'Caption': caption,
    'Checked': checked,
    'Enabled': enabled,
    'Shortcut': shortcut,
    'Visible': true,
    'Tag': '',
  }, container: container);

  GbFormModel model() => GbFormModel(
    form: {'Caption': '', 'Width': 300, 'Height': 200},
    controls: [
      menu('mnuFile', 'File'),
      menu('mnuFileNew', 'New', container: 'mnuFile', shortcut: 'Ctrl+N'),
      menu('mnuFileLine', '-', container: 'mnuFile'),
      menu('mnuFileBig', 'Big', container: 'mnuFile', checked: true),
      menu('mnuFileOff', 'Off', container: 'mnuFile', enabled: false),
      menu('mnuHelp', 'Help', enabled: false),
      menu('mnuHelpAbout', 'About', container: 'mnuHelp', shortcut: 'F1'),
    ],
    onEvent: (control, event) => events.add('$control.$event'),
    // As when it runs: the form takes the focus, and the keys.
    onKey: (
      event,
      keyCode, {
      required shift,
      required control,
      required alt,
      required inTextBox,
    }) {},
  );

  setUp(events.clear);

  test('gbShortcut: the keys of a Shortcut; Ctrl is Command on Apple', () {
    expect(gbShortcut(''), isNull);
    final save = gbShortcut('Ctrl+Shift+S')!;
    expect(save.trigger, LogicalKeyboardKey.keyS);
    expect(
      [save.control, save.shift, save.meta, save.alt],
      [true, true, false, false],
    );
    final apple = gbShortcut('Ctrl+O', apple: true)!;
    expect([apple.control, apple.meta], [false, true]);
    expect(gbShortcut('Alt+7')!.trigger, LogicalKeyboardKey.digit7);
    expect(gbShortcut('F12')!.trigger, LogicalKeyboardKey.f12);
    expect(gbShortcut('Delete')!.trigger, LogicalKeyboardKey.delete);
  });

  test('menus are not drawn on the form', () {
    final m = model();
    expect(m.drawingOrder, isEmpty);
    expect(m.menusIn(null).map((c) => c.name), ['mnuFile', 'mnuHelp']);
    expect(m.menusIn('MNUFILE').map((c) => c.name), [
      'mnuFileNew',
      'mnuFileLine',
      'mnuFileBig',
      'mnuFileOff',
    ]);
  });

  testWidgets('the menu bar in the window: an item is chosen, a greyed one '
      'is not; a Shortcut chooses its item', (tester) async {
    final m = model();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GbMenuBar(model: m),
              GbFormView(model: m),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(gbMenuKey('mnuFile')));
    await tester.pumpAndSettle();
    expect(find.text('Ctrl+N'), findsOneWidget, reason: 'its Shortcut');
    expect(find.byIcon(Icons.check), findsOneWidget, reason: 'Big is Checked');
    await tester.tap(find.byKey(gbMenuKey('mnuFileOff')));
    await tester.pumpAndSettle();
    expect(events, isEmpty);
    await tester.tap(find.byKey(gbMenuKey('mnuFileNew')));
    await tester.pumpAndSettle();
    expect(events, ['mnuFileNew.Click']);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    // F1 is About's, in Help, which is not Enabled.
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    expect(events, ['mnuFileNew.Click', 'mnuFileNew.Click']);

    // A menu that is not Enabled opens nothing.
    await tester.tap(find.byKey(gbMenuKey('mnuHelp')));
    await tester.pumpAndSettle();
    expect(find.byKey(gbMenuKey('mnuHelpAbout')), findsNothing);
  });

  test('for the system menu bar: lines as groups, ✓ for Checked, greyed '
      'items, Command for Ctrl', () {
    final menus = gbPlatformMenus(model());
    expect(menus.map((m) => m.label), ['File', 'Help']);
    final file = menus.first as PlatformMenu;
    expect(file.menus, hasLength(2));
    final [first, second] = [
      for (final g in file.menus) (g as PlatformMenuItemGroup).members,
    ];
    expect(first.single.label, 'New');
    expect((first.single.shortcut! as SingleActivator).meta, isTrue);
    expect(second.map((i) => i.label), ['✓ Big', 'Off']);
    expect(second.last.onSelected, isNull);
    final help = menus.last as PlatformMenu;
    expect(help.menus.single.onSelected, isNull, reason: 'Help is greyed');
  });

  testWidgets('on macOS the form leaves the Shortcuts to the system', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final m = model();
    await tester.pumpWidget(MaterialApp(home: GbFormView(model: m)));
    expect(gbUsesSystemMenus, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    expect(events, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a popup menu where the pointer went down: a menu opens its '
      'items beside it, a greyed item is not chosen, Escape closes it', (
    tester,
  ) async {
    final m = model();
    final dialogs = GbDialogs();
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return Align(
                alignment: Alignment.topLeft,
                child: GbFormView(model: m),
              );
            },
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(100, 60));
    expect(m.lastPointer, const Offset(100, 60));
    var chosen = dialogs.popupMenu(context, m, 'mnuFile', m.lastPointer!);
    await tester.pumpAndSettle();
    expect(dialogs.hasOpenDialog, isTrue);
    expect(
      tester.getTopLeft(find.byKey(gbPopupKey('mnuFileNew'))).dy,
      greaterThanOrEqualTo(60),
    );
    await tester.tap(find.byKey(gbPopupKey('mnuFileOff')));
    await tester.pumpAndSettle();
    expect(dialogs.hasOpenDialog, isTrue, reason: 'Off is not Enabled');
    await tester.tap(find.byKey(gbPopupKey('mnuFileNew')));
    await tester.pumpAndSettle();
    expect(await chosen, 'mnuFileNew');
    expect(events, isEmpty, reason: 'the program runs the Click');

    chosen = dialogs.popupMenu(context, m, 'mnuFile', Offset.zero);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await chosen, isNull);
    expect(find.byKey(gbPopupKey('mnuFileNew')), findsNothing);

    chosen = dialogs.popupMenu(context, m, 'mnuFile', Offset.zero);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(await chosen, isNull, reason: 'a tap outside closes it');
  });
}
