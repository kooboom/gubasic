import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/designer/properties_panel.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// Replays the real input methods' recordings ([logs]: file name → JSON,
/// from packages/gubasic_runtime/test/ime_logs) into the Caption field of
/// the Properties window, and checks what D35 promises: only committed
/// characters reach the form, the final text is the recording's, and the
/// letters typed in one visit of the field are one step of undo.
void defineCaptionImeTests(Map<String, String> logs) {
  final hello = exampleProjects['hello']!;
  const formFile = 'Form1.form.yaml';

  String file(WidgetTester t) => t
      .widget<IdeShell>(find.byType(IdeShell))
      .controller
      .current
      .files[formFile]!;
  String caption(WidgetTester t) => readFormFile(
    file(t),
    name: 'Form1',
  ).form.control('btnHello')!.valueOf('Caption') as String;
  String canvas(WidgetTester t) => t
      .widget<Text>(
        find.descendant(
          of: find.descendant(
            of: find.byKey(designerFormKey),
            matching: find.byType(GbButton),
          ),
          matching: find.byType(Text),
        ),
      )
      .data!;
  Finder field() => find.byKey(propertyFieldKey('Caption'));
  String fieldText(WidgetTester t) =>
      t.widget<TextField>(field()).controller!.text;

  /// A click on btnHello: the focus goes to the form, btnHello stays
  /// selected.
  Future<void> clickButton(WidgetTester t) async {
    final o = t.getTopLeft(find.byKey(designerFormKey));
    final m = await t.startGesture(
      o + const Offset(30, 70),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await m.up();
    await t.pump();
  }

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      IdeApp(projects: {'hello': hello}, strings: IdeStrings.en),
    );
    await t.tap(find.text(formFile));
    await t.pumpAndSettle();
    await clickButton(t);
    await t.pumpAndSettle();
    await t.tap(field());
    await t.pump();
  }

  Future<int> undoSteps(WidgetTester t) async {
    var steps = 0;
    final apple = defaultTargetPlatform == TargetPlatform.macOS;
    final modifier = apple
        ? LogicalKeyboardKey.meta
        : LogicalKeyboardKey.control;
    while (file(t) != hello[formFile] && steps < 20) {
      await t.sendKeyDownEvent(modifier);
      await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await t.sendKeyUpEvent(modifier);
      await t.pumpAndSettle();
      steps++;
    }
    return steps;
  }

  TextEditingValue valueOf(Map<String, Object?> e) {
    final c = (e['composing']! as List).cast<int>();
    final s = (e['selection']! as List).cast<int>();
    return TextEditingValue(
      text: e['text']! as String,
      selection: TextSelection(baseOffset: s[0], extentOffset: s[1]),
      composing: TextRange(start: c[0], end: c[1]),
    );
  }

  for (final MapEntry(key: source, value: json) in logs.entries) {
    final scenarios = (jsonDecode(json)['scenarios'] as Map<String, Object?>)
        .map((k, v) => MapEntry(k, (v! as List).cast<Map<String, Object?>>()));
    for (final MapEntry(key: id, value: all) in scenarios.entries) {
      // As in text_box_test: only what comes after the last 다시 counts.
      final resets = [
        for (var i = 0; i < all.length; i++)
          if (all[i]['kind'] == 'reset') i,
      ];
      final log = all.sublist(resets.isEmpty ? 0 : resets.last + 1);

      testWidgets('Caption field, $source $id', variant: _platformOf(source), (
        t,
      ) async {
        await open(t);
        var inField = true;
        // Visits of the field in which the form changed.
        var visits = 0;
        var changedThisVisit = false;
        var last = const TextEditingValue();
        for (final e in log) {
          switch (e['kind']) {
            case 'value':
              final v = valueOf(e);
              last = v;
              final before = caption(t);
              t.testTextInput.updateEditingValue(v);
              await t.pump();
              final at =
                  'at ${e['ms']} ms (${jsonEncode(v.text)}, '
                  'composing ${v.composing.start}-${v.composing.end})';
              // In the field, only committed characters; after it was
              // left, what was composed then was committed already.
              // A desktop app's recording has no composing ranges: the
              // IDE guesses them (D37), so no jamo may reach the form.
              if (_isApp(source) && inField) {
                expect(_hasJamo(caption(t)), isFalse, reason: 'jamo $at');
              } else {
                expect(
                  caption(t),
                  inField ? committedText(v) : before,
                  reason: 'the form file $at',
                );
              }
              // The canvas shows the field as it is typed (D35).
              expect(
                canvas(t),
                inField ? v.text : caption(t),
                reason: 'the canvas $at',
              );
              if (caption(t) != before) changedThisVisit = true;
            case 'focus' when e['hasFocus'] == false && inField:
              final before = caption(t);
              await clickButton(t);
              // Leaving the field commits what is being composed.
              if (caption(t) != before) changedThisVisit = true;
              inField = false;
              if (changedThisVisit) visits++;
              changedThisVisit = false;
            case 'focus' when e['hasFocus'] == true && !inField:
              await t.tap(field());
              await t.pump();
              inField = true;
          }
        }
        if (inField) {
          final before = caption(t);
          await clickButton(t);
          if (caption(t) != before) changedThisVisit = true;
          if (changedThisVisit) visits++;
        }
        await t.pumpAndSettle();
        expect(caption(t), last.text, reason: 'the final text');
        expect(canvas(t), last.text, reason: 'the canvas, from the file');
        expect(fieldText(t), last.text);
        expect(await undoSteps(t), visits, reason: 'one step per visit');
      });
    }
  }

  // 한글 being typed, with 글 still being composed.
  Future<void> typeHangeul(WidgetTester t) async {
    for (final (text, s, e) in [
      ('', -1, -1),
      ('ㅎ', 0, 1),
      ('하', 0, 1),
      ('한', 0, 1),
      ('한ㄱ', 1, 2),
      ('한그', 1, 2),
      ('한글', 1, 2),
    ]) {
      t.testTextInput.updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange(start: s, end: e),
        ),
      );
      await t.pump();
    }
    expect(caption(t), '한');
  }

  testWidgets('Enter while composing commits it', (t) async {
    await open(t);
    await typeHangeul(t);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(caption(t), '한글');
    expect(fieldText(t), '한글');
    await clickButton(t);
    expect(await undoSteps(t), 1);
  });

  testWidgets('Esc while composing drops only that; again, all', (t) async {
    await open(t);
    await typeHangeul(t);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(caption(t), '한');
    expect(fieldText(t), '한', reason: 'still in the field');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(caption(t), 'Say hello');
    expect(fieldText(t), 'Say hello');
    expect(file(t), hello[formFile]);
  });

  testWidgets('a click on the form while composing keeps it', (t) async {
    await open(t);
    await typeHangeul(t);
    // As recorded: the focus goes first, the commit comes after.
    await clickButton(t);
    t.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '한글',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await t.pumpAndSettle();
    expect(caption(t), '한글');
    expect(fieldText(t), '한글');
    expect(await undoSteps(t), 1);
  });
}

/// Whether [source] was recorded in a desktop app, not a browser.
bool _isApp(String source) => source.endsWith('-app.json');

/// The platform a recording replays on: the app's, or the test default.
TestVariant<Object?> _platformOf(String source) => _isApp(source)
    ? TargetPlatformVariant.only(TargetPlatform.macOS)
    : const DefaultTestVariant();

/// Whether [text] holds a lone jamo (ㄱ, ㅏ): a syllable being composed.
bool _hasJamo(String text) => text.runes.any((r) => r >= 0x3131 && r <= 0x318E);
