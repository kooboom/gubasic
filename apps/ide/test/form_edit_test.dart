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

    test('a double-click places in the middle, then a step further', () {
      final first = centredBox(hello, button, grid: true);
      expect(first, (left: 112, top: 48, width: 96, height: 32));
      final form = withControl(hello, button, 'Button1', first);
      expect(centredBox(form, button, grid: true), (
        left: 120,
        top: 56,
        width: 96,
        height: 32,
      ));
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

    test('the oldest steps are forgotten after the limit', () {
      final h = FormHistory(limit: 3)..follow('0');
      for (var i = 1; i <= 5; i++) {
        h.record('${i - 1}', '$i');
      }
      expect([h.undo(), h.undo(), h.undo(), h.undo()], ['4', '3', '2', null]);
    });
  });

  test('snap', () {
    expect(snap(11, grid: true), 8);
    expect(snap(13, grid: true), 16);
    expect(snap(13.4, grid: false), 13);
  });
}

const ControlBox _box = (left: 16, top: 24, width: 40, height: 16);
