import 'dart:async';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'fake_host.dart';

Future<List<String>> _run(String body, {String extra = ''}) =>
    runAndRecord('Sub Main()\n$body\nEnd Sub\n$extra');

void main() {
  group('starting', () {
    test('Sub Main is the start; else Sub Form_Load', () async {
      expect(
          await runAndRecord('Sub Form_Load()\nDebug.Print("load")\nEnd Sub\n'
              'Sub Main()\nDebug.Print("main")\nEnd Sub'),
          ['Debug.Print: main']);
      expect(
          await runAndRecord('Sub Form_Load()\nDebug.Print("load")\nEnd Sub'),
          ['Debug.Print: load']);
    });

    test('no start procedure: not started', () async {
      expect(await runAndRecord('Sub Other()\nEnd Sub'),
          ['Not started: noStartProcedure']);
      expect(await runAndRecord('Sub Main(x As Integer)\nEnd Sub'),
          ['Not started: noStartProcedure']);
    });

    test('errors block the run; warnings do not (D23)', () async {
      expect(await _run('Debug.Print(1 +)'), ['Not started: hasErrors']);
      expect(await _run('Dim unused As Integer\nDebug.Print("ran")'),
          ['Debug.Print: ran']);
    });

    test('form variables get their initial values first', () async {
      expect(
          await runAndRecord('Dim greeting As String = "Hi " & Name()\n'
              'Dim list As New List(Of Integer)\n'
              'Function Name() As String\nReturn "Kim"\nEnd Function\n'
              'Sub Main()\nDebug.Print(greeting & list.Count)\nEnd Sub'),
          ['Debug.Print: Hi Kim0']);
    });
  });

  group('procedures', () {
    test('Optional parameters and default values', () async {
      expect(
          await _run('Greet()\nGreet("Lee")',
              extra: 'Sub Greet(Optional who As String = "Kim")\n'
                  'Debug.Print("Hi " & who)\nEnd Sub'),
          ['Debug.Print: Hi Kim', 'Debug.Print: Hi Lee']);
    });

    test('Exit Sub, and Return inside Try runs Finally', () async {
      expect(
          await _run('Debug.Print(F())\nS()',
              extra: 'Function F() As Integer\nTry\nReturn 1\nFinally\n'
                  'Debug.Print("finally")\nEnd Try\nEnd Function\n'
                  'Sub S()\nExit Sub\nDebug.Print("never")\nEnd Sub'),
          ['Debug.Print: finally', 'Debug.Print: 1']);
    });

    test('a Function without Return gives the default value', () async {
      expect(
          await _run('Debug.Print(F() & "|" & G() & "|")',
              extra: 'Function F() As Integer\nEnd Function\n'
                  'Function G() As String\nEnd Function'),
          ['Debug.Print: 0||']);
    });

    test('R009: endless recursion stops at the limit', () async {
      final host = FakeHost();
      final result = await Interpreter(
              compile('Sub Main()\nLoopForever(1)\nEnd Sub\n'
                  'Sub LoopForever(n As Integer)\nLoopForever(n + 1)\nEnd Sub'),
              host)
          .run();
      final error = (result as RunFailed).error;
      expect(error.code, DiagnosticCode.callsTooDeep);
      expect(error.args, ['$maxCallDepth']);
      expect(error.line, 5);
    });
  });

  group('loops', () {
    test('an existing For variable keeps the value after the loop', () async {
      expect(
          await _run('Dim i As Integer\nFor i = 1 To 3\nNext\nDebug.Print(i)'),
          ['Debug.Print: 4']);
    });

    test('For Each goes through a snapshot of the list', () async {
      expect(
          await _run('Dim l As New List(Of Integer)\nl.Add(1)\nl.Add(2)\n'
              'For Each x In l\nl.Add(x * 10)\nNext\nDebug.Print(l.Count)'),
          ['Debug.Print: 4']);
    });

    test('Step 0 loops forever until stopped', () async {
      final host = FakeHost();
      final interpreter = Interpreter(
          compile('Sub Main()\nFor i = 1 To 2 Step 0\nNext\nEnd Sub'), host);
      final run = interpreter.run();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      interpreter.stop();
      expect(await run, isA<RunStopped>());
      expect(host.yields, greaterThan(0));
    });

    test(
        'a long loop lets the screen update by time, about every 10 ms, '
        'not every 1000 rounds', () async {
      final host = FakeHost();
      final clock = Stopwatch()..start();
      await Interpreter(
              compile('Sub Main()\nDim t As Integer = 0\n'
                  'For i = 1 To 200000\nt = t + i\nNext\nEnd Sub'),
              host)
          .run();
      final ms = clock.elapsedMilliseconds;
      // Every 1000 rounds would be 200 pauses; by time, about one per
      // 10 ms of work.
      expect(host.yields, lessThan(200));
      expect(host.yields, lessThanOrEqualTo(ms ~/ 10 + 1));
    });

    test('DoEvents yields', () async {
      final host = FakeHost();
      await Interpreter(
              compile('Sub Main()\nDoEvents\nDoEvents()\nEnd Sub'), host)
          .run();
      expect(host.yields, 2);
    });
  });

  group('run-time errors', () {
    Future<String> code(String body) async =>
        (await _run(body)).last.split(' ').take(2).join(' ');

    test('R003 item number out of range', () async {
      expect(await code('Dim l As New List(Of Integer)\nDebug.Print(l(0))'),
          'Error R003');
      expect(await code('Debug.Print("abc".Substring(4))'), 'Error R003');
    });

    test('R004 Nothing', () async {
      expect(await code('Dim l As List(Of Integer)\nl.Add(1)'), 'Error R004');
      expect(await code('Dim a() As Integer\nDebug.Print(UBound(a))'),
          'Error R004');
    });

    test('R005 conversion', () async {
      expect(await code('Debug.Print(CDbl("x"))'), 'Error R005');
      expect(await code('Debug.Print(CBool("maybe"))'), 'Error R005');
    });

    test('R006 a member found missing at run time (through Object)', () async {
      expect(await code('Dim o As Object = 5\nDebug.Print(o.Length)'),
          'Error R006');
    });

    test('R007 invalid arguments', () async {
      expect(await code('Debug.Print(Mid("abc", 0))'), 'Error R007');
      expect(await code('Debug.Print(Left("abc", -1))'), 'Error R007');
      expect(await code('Debug.Print(Sqr(-1))'), 'Error R007');
      expect(await code('Debug.Print(Round(1.5, 16))'), 'Error R007');
    });

    test('the error points at the line', () async {
      final r = await _run('Dim a As Integer = 1\n\nDebug.Print(a \\ 0)');
      expect(r.last, 'Error R002 @ 4');
    });

    test('I3: ex.Message uses the language of the run', () async {
      final host = FakeHost();
      await Interpreter(
              compile(
                  'Sub Main()\nTry\nDebug.Print(1 \\ 0)\nCatch ex As Exception\n'
                  'Debug.Print(ex.Message)\nEnd Try\nEnd Sub'),
              host,
              messages: koreanMessages)
          .run();
      expect(host.transcript.single, startsWith('Debug.Print: 0으로 나눌 수 없습니다'));
    });
  });

  test('Static starts once; Dim in a loop starts again each time (I1)',
      () async {
    expect(
        await _run('For i = 1 To 2\nDim d As Integer\nStatic s As Integer\n'
            'd = d + 1\ns = s + 1\nDebug.Print(d & s)\nNext'),
        ['Debug.Print: 11', 'Debug.Print: 12']);
  });

  test('Randomize without a seed still gives numbers from 0 to 1', () async {
    final out = await _run('Randomize\nDim r As Double = Rnd()\n'
        'Debug.Print(r >= 0 And r < 1)');
    expect(out, ['Debug.Print: True']);
  });

  test('Integer.MaxValue and MinValue', () async {
    expect(await _run('Debug.Print(Integer.MaxValue & " " & Integer.MinValue)'),
        ['Debug.Print: 9223372036854775807 -9223372036854775808']);
  });
}
