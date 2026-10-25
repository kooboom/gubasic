import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/designer/form_edit.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

void main() {
  final button = builtinComponents['button']!;
  final label = builtinComponents['label']!;
  final textBox = builtinComponents['textbox']!;

  FormFile read(String text) => readFormFile(text, name: 'Form1').form;
  final hello = read(exampleProjects['hello']!['Form1.form.yaml']!);
  final empty = read('formatVersion: 1\n');

  group('names', () {
    test('the type and the smallest number not used', () {
      expect(newControlName(empty, button), 'Button1');
      expect(newControlName(empty, label), 'Label1');
      expect(newControlName(empty, textBox), 'TextBox1');

      var form = withControl(empty, button, 'button1', _box);
      expect(newControlName(form, button), 'Button2', reason: 'any case');
      form = withControl(form, button, 'Button2', _box);
      form = withoutControl(form, 'BUTTON1');
      expect(form.controls.map((c) => c.name), ['Button2']);
      expect(newControlName(form, button), 'Button1', reason: 'free again');
    });
  });

  group('drawing', () {
    ControlBox draw(
      FormFile form,
      ComponentSpec type,
      Point<double> start,
      Point<double> end, {
      bool grid = true,
    }) => drawnBox(form, type, start: start, end: end, grid: grid);

    test('on the grid, in any direction', () {
      const a = Point(10.0, 10.0), b = Point(100.0, 50.0);
      const box = (left: 8, top: 8, width: 96, height: 40);
      expect(draw(hello, button, a, b), box);
      expect(draw(hello, button, b, a), box, reason: 'up and left');
      expect(
        draw(hello, button, const Point(100, 10), const Point(10, 50)),
        box,
        reason: 'down and left',
      );
    });

    test('off the grid, to the pixel', () {
      expect(
        draw(
          hello,
          button,
          const Point(10, 10),
          const Point(101, 53),
          grid: false,
        ),
        (left: 10, top: 10, width: 91, height: 43),
      );
    });

    test('a drag of a few pixels is a click: the default size', () {
      expect(draw(hello, button, const Point(18, 18), const Point(21, 20)), (
        left: 16,
        top: 16,
        width: 96,
        height: 32,
      ));
      expect(draw(hello, textBox, const Point(18, 18), const Point(18, 18)), (
        left: 16,
        top: 16,
        width: 160,
        height: 32,
      ));
    });

    test('a click near the edge keeps the control inside the form', () {
      // hello's form is 320 x 120.
      expect(
        draw(hello, button, const Point(300, 110), const Point(300, 110)),
        (left: 224, top: 88, width: 96, height: 32),
      );
    });

    test('a short drag gives the smallest size, not less', () {
      expect(draw(hello, label, const Point(40, 40), const Point(45, 45)), (
        left: 40,
        top: 40,
        width: 8,
        height: 8,
      ));
    });

    test('a drag past the form stops at its edge', () {
      expect(draw(hello, label, const Point(200, 80), const Point(900, 900)), (
        left: 200,
        top: 80,
        width: 120,
        height: 40,
      ));
    });

    test('a double-click places in the middle, then below what is there, '
        'then at the top of the next column (D68)', () {
      var form = empty; // 480 x 360
      final placed = <ControlBox>[];
      for (var i = 0; i < 6; i++) {
        final box = centredBox(form, button, grid: true);
        placed.add(box);
        form = withControl(form, button, 'Button${i + 1}', box);
      }
      expect(placed.map((b) => (b.left, b.top)), [
        (192, 168),
        (192, 208),
        (192, 248),
        (192, 288),
        (192, 328),
        (296, 8),
      ]);
    });

    test('a form with no room left places in the middle, a step further '
        'each time, as before', () {
      final first = centredBox(hello, button, grid: true);
      // Below btnHello, which is in the middle.
      expect(first, (left: 112, top: 88, width: 96, height: 32));
      var form = withControl(hello, button, 'Button1', first);
      form = withControl(
        form,
        button,
        'Button2',
        centredBox(form, button, grid: true),
      );
      final label = centredBox(form, builtinComponents['label']!, grid: true);
      expect(label, (left: 104, top: 48, width: 120, height: 24));
    });
  });

  group('the form file', () {
    test('a Button and a Label show their name; a TextBox is empty', () {
      var form = withControl(empty, button, 'Button1', _box);
      form = withControl(form, label, 'Label1', _box);
      form = withControl(form, textBox, 'TextBox1', _box);
      final text = writeFormFile(form);
      expect(text, contains('Caption: Button1'));
      expect(text, contains('Caption: Label1'));
      expect(text, isNot(contains('Text:')));
      final back = readFormFile(text, name: 'Form1');
      expect(back.diagnostics, isEmpty);
      expect(back.form.controls.map((c) => c.name), [
        'Button1',
        'Label1',
        'TextBox1',
      ]);
      expect(boxOf(back.form.control('Label1')!), _box);
    });

    test('a default size is not written', () {
      final form = withControl(empty, button, 'Button1', (
        left: 8,
        top: 8,
        width: 96,
        height: 32,
      ));
      expect(
        writeFormFile(form),
        'formatVersion: 1\n'
        'controls:\n'
        '  - name: Button1\n'
        '    type: Button\n'
        '    properties:\n'
        '      Caption: Button1\n'
        '      Left: 8\n'
        '      Top: 8\n',
      );
    });

    test('a new control comes last, drawn above the others', () {
      final form = withControl(hello, label, 'Label1', _box);
      expect(form.controls.map((c) => c.name), [
        'lblMessage',
        'btnHello',
        'Label1',
      ]);
      expect(hello.controls, hasLength(2), reason: 'hello is unchanged');
    });
  });

  group('history', () {
    test('undo and redo go step by step', () {
      final h = FormHistory()..follow('a');
      expect(h.canUndo, isFalse);
      h
        ..record('a', 'b')
        ..record('b', 'c');
      expect(h.undo(), 'b');
      expect(h.undo(), 'a');
      expect(h.undo(), isNull);
      expect(h.redo(), 'b');
      expect(h.redo(), 'c');
      expect(h.redo(), isNull);
    });

    test('a new step after undo drops the steps undone', () {
      final h = FormHistory()
        ..record('a', 'b')
        ..record('b', 'c');
      h.undo();
      h.record('b', 'd');
      expect(h.canRedo, isFalse);
      expect(h.undo(), 'b');
      expect(h.redo(), 'd');
    });

    test('a text changed some other way starts again', () {
      final h = FormHistory()..record('a', 'b');
      h.follow('x');
      expect(h.canUndo, isFalse);
      h.record('x', 'y');
      expect(h.undo(), 'x');
    });

    test('an action that changes nothing is not a step', () {
      final h = FormHistory()..record('a', 'a');
      expect(h.canUndo, isFalse);
    });

    test('changes of one group are one step until sealed', () {
      final g = Object();
      final h = FormHistory()
        ..record('a', 'b')
        ..record('b', 'c', group: g)
        ..record('c', 'd', group: g);
      expect(h.undo(), 'b');
      expect(h.redo(), 'd');
      h
        ..record('d', 'e', group: g)
        ..seal()
        ..record('e', 'f', group: g);
      expect(h.undo(), 'e', reason: 'sealed: a new step');
      expect(h.undo(), 'd');
    });

    test('a group back where it started is no step', () {
      final g = Object();
      final h = FormHistory()
        ..follow('a')
        ..record('a', 'b', group: g)
        ..record('b', 'a', group: g);
      expect(h.canUndo, isFalse);
    });

    test('the oldest steps are forgotten after the limit', () {
      final h = FormHistory(limit: 3)..follow('0');
      for (var i = 1; i <= 5; i++) {
        h.record('${i - 1}', '$i');
      }
      expect([h.undo(), h.undo(), h.undo(), h.undo()], ['4', '3', '2', null]);
    });

    test('a rename keeps its code change, turned around by undo', () {
      const code = (from: 'a1', to: 'b1', before: 'x = a1', after: 'x = b1');
      final g = Object();
      final h = FormHistory()
        ..record('a', 'b', group: g)
        ..record('b', 'c', code: code);
      expect(h.undo(), 'b');
      expect(h.lastCode, (
        from: 'b1',
        to: 'a1',
        before: 'x = b1',
        after: 'x = a1',
      ));
      expect(h.undo(), 'a');
      expect(h.lastCode, isNull);
      expect(h.redo(), 'b');
      expect(h.redo(), 'c');
      expect(h.lastCode, code);
      // A rename ends the group before it.
      h.record('c', 'd', group: g);
      expect(h.undo(), 'c');
    });
  });

  group('moving and resizing', () {
    const size = (width: 320, height: 120);
    const box = (left: 40, top: 40, width: 80, height: 32);

    test('a move lands on the grid, inside the form', () {
      expect(movedBox(box, 13, 9, size: size, grid: true), (
        left: 56,
        top: 48,
        width: 80,
        height: 32,
      ));
      expect(movedBox(box, 13, 9, size: size, grid: false), (
        left: 53,
        top: 49,
        width: 80,
        height: 32,
      ));
      expect(movedBox(box, 900, -900, size: size, grid: true), (
        left: 240,
        top: 0,
        width: 80,
        height: 32,
      ));
    });

    test('each handle moves its own edges', () {
      ControlBox r(Handle h, double dx, double dy) =>
          resizedBox(box, h, dx, dy, size: size, grid: true);
      expect(r((x: 1, y: 0), 13, 50), (
        left: 40,
        top: 40,
        width: 96,
        height: 32,
      ));
      expect(r((x: -1, y: 0), -13, 0), (
        left: 24,
        top: 40,
        width: 96,
        height: 32,
      ));
      expect(r((x: 0, y: 1), 50, 9), (
        left: 40,
        top: 40,
        width: 80,
        height: 40,
      ));
      expect(r((x: 0, y: -1), 0, -9), (
        left: 40,
        top: 32,
        width: 80,
        height: 40,
      ));
      expect(r((x: 1, y: 1), 900, 900), (
        left: 40,
        top: 40,
        width: 280,
        height: 80,
      ));
      expect(r((x: -1, y: -1), -900, -900), (
        left: 0,
        top: 0,
        width: 120,
        height: 72,
      ));
      expect(r((x: 1, y: -1), 8, -8), (
        left: 40,
        top: 32,
        width: 88,
        height: 40,
      ));
      expect(r((x: -1, y: 1), -8, 8), (
        left: 32,
        top: 40,
        width: 88,
        height: 40,
      ));
    });

    test('a control is never made smaller than 8', () {
      expect(
        resizedBox(box, (x: -1, y: -1), 900, 900, size: size, grid: true),
        (left: 112, top: 64, width: 8, height: 8),
      );
      expect(
        resizedBox(box, (x: 1, y: 1), -900, -900, size: size, grid: false),
        (left: 40, top: 40, width: 8, height: 8),
      );
    });

    test('an arrow key goes to the next grid line, or one pixel', () {
      expect(step(13, 1, grid: true), 16);
      expect(step(13, -1, grid: true), 8);
      expect(step(16, 1, grid: true), 24);
      expect(step(16, -1, grid: true), 8);
      expect(step(13, 1, grid: false), 14);
      expect(step(13, -1, grid: false), 12);
      expect(nudgedBox(box, 1, -1, size: size, grid: true), (
        left: 48,
        top: 32,
        width: 80,
        height: 32,
      ));
      expect(
        nudgedBox(
          (left: 240, top: 0, width: 80, height: 32),
          1,
          -1,
          size: size,
          grid: true,
        ),
        (left: 240, top: 0, width: 80, height: 32),
        reason: 'stays inside the form',
      );
    });

    test('Shift and an arrow key moves the right or bottom edge', () {
      expect(grownBox(box, 1, 0, size: size, grid: true), (
        left: 40,
        top: 40,
        width: 88,
        height: 32,
      ));
      expect(grownBox(box, 0, -1, size: size, grid: false), (
        left: 40,
        top: 40,
        width: 80,
        height: 31,
      ));
      expect(
        grownBox(
          (left: 40, top: 40, width: 8, height: 8),
          -1,
          -1,
          size: size,
          grid: true,
        ),
        (left: 40, top: 40, width: 8, height: 8),
      );
      expect(
        grownBox(
          (left: 240, top: 88, width: 80, height: 32),
          1,
          1,
          size: size,
          grid: true,
        ),
        (left: 240, top: 88, width: 80, height: 32),
        reason: 'the form edge',
      );
    });

    test('the form is resized on the grid, never below 64', () {
      expect(resizedForm(size, 13, 3, grid: true), (width: 336, height: 120));
      expect(resizedForm(size, 13, 3, grid: false), (width: 333, height: 123));
      expect(resizedForm(size, -900, -900, grid: true), (
        width: 64,
        height: 64,
      ));
    });

    test('the file gets the new box and size', () {
      var form = withBox(hello, 'BTNHELLO', box);
      form = withFormSize(form, (width: 400, height: 200));
      final text = writeFormFile(form);
      expect(text, contains('  Width: 400\n  Height: 200\n'));
      expect(
        text,
        contains(
          '      Caption: Say hello\n      Left: 40\n      Top: 40\n'
          '      Width: 80\n',
        ),
      );
      expect(text, isNot(contains('Height: 32')), reason: 'the default');
    });
  });

  test('snap', () {
    expect(snap(11, grid: true), 8);
    expect(snap(13, grid: true), 16);
    expect(snap(13.4, grid: false), 13);
  });

  test('the lines that show an Anchor go from the middle of each anchored '
      'edge out to the form\'s edge', () {
    const size = (width: 100, height: 80);
    expect(anchorLines(_box, '', size), isEmpty);
    expect(anchorLines(_box, 'Left Top Right Bottom', size), [
      (const Point(0.0, 32.0), const Point(16.0, 32.0)),
      (const Point(36.0, 0.0), const Point(36.0, 24.0)),
      (const Point(56.0, 32.0), const Point(100.0, 32.0)),
      (const Point(36.0, 40.0), const Point(36.0, 80.0)),
    ]);
  });

  test('a form resized from a base moves its controls from that base, and '
      'back to its size puts them back', () {
    final form = readFormFile(
      'formatVersion: 1\nproperties: { Width: 300, Height: 200 }\n'
      'controls:\n'
      '  - { name: a, type: Button, properties: { Left: 13, Top: 7, '
      'Anchor: Right Bottom } }\n'
      '  - { name: b, type: Label, properties: { Left: 101, Top: 51, '
      'Anchor: "" } }\n',
      name: 'Form1',
    ).form;
    final base = anchorBaseOf(form);
    final larger = withAnchoredSize(form, (width: 333, height: 211), base);
    expect(boxOf(larger.control('a')!).left, 46);
    expect(boxOf(larger.control('b')!), (
      left: 117,
      top: 56,
      width: 120,
      height: 24,
    ));
    final back = withAnchoredSize(larger, (width: 300, height: 200), base);
    expect(writeFormFile(back), writeFormFile(form));
  });
}

const ControlBox _box = (left: 16, top: 24, width: 40, height: 16);
