import 'dart:async';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

/// Http waits where it is called (docs/DESIGN.md D124 A, D125): the
/// program's other handlers wait for the answer and run after it, in
/// turn, the same handler is not started again, and where there is no
/// Http the program stops with R038.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: btnA, type: Button }
  - { name: btnB, type: Button }
''', name: 'Form1').form;

/// An Http whose answers the test gives when it chooses.
class _SlowHttp extends HttpComponent {
  final waiting = <Completer<HttpReply>>[];

  @override
  Future<HttpReply> send(HttpRequest request, Duration timeout) {
    final c = Completer<HttpReply>();
    waiting.add(c);
    return c.future;
  }

  void answer(String text) => waiting
      .removeAt(0)
      .complete(HttpReply(200, {'content-type': 'text/plain'}, text.codeUnits));
}

class _Host extends ScriptedHost {
  _Host(super.form, this.component);

  final HttpComponent? component;

  @override
  ComponentInstance? createComponent(String type, {String name = ''}) =>
      component;
}

Future<void> _idle(Interpreter i) async {
  for (var n = 0; n < 10000 && !i.isWaitingForUser; n++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _settle() async {
  for (var n = 0; n < 10; n++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('clicks made while Http waits run after it, in turn', () async {
    final http = _SlowHttp();
    final host = _Host(_form, http);
    final program = compile('''
Sub btnA_Click()
    Debug.Print("A asks")
    Debug.Print("A got " & Http.Get("http://x/a"))
End Sub
Sub btnB_Click()
    Debug.Print("B")
End Sub
''', form: _form);
    expect(program.diagnostics.where((d) => d.isError), isEmpty);
    final i = Interpreter(program, host);
    final run = i.run();
    await _idle(i);
    expect(i.raiseEvent('btnA', 'Click'), EventOutcome.started);
    await _settle();
    expect(http.waiting, hasLength(1), reason: 'the request was sent');
    expect(i.isWaitingForUser, isFalse);
    expect(i.raiseEvent('btnB', 'Click'), EventOutcome.started,
        reason: 'B waits for its turn (D28)');
    expect(i.raiseEvent('btnA', 'Click'), EventOutcome.ignored,
        reason: 'A is still running (D5)');
    await _settle();
    expect(host.transcript, ['Debug.Print: A asks']);
    http.answer('hello');
    await _idle(i);
    expect(host.transcript,
        ['Debug.Print: A asks', 'Debug.Print: A got hello', 'Debug.Print: B']);
    i.closeForm();
    expect(await run, isA<RunCompleted>());
  });

  test('Stop works while Http waits', () async {
    final http = _SlowHttp();
    final host = _Host(_form, http);
    final i = Interpreter(compile('''
Sub btnA_Click()
    Debug.Print(Http.Get("http://x/a"))
End Sub
''', form: _form), host);
    final run = i.run();
    await _idle(i);
    i.raiseEvent('btnA', 'Click');
    await _settle();
    i.stop();
    expect(await run, isA<RunStopped>());
    http.answer('late');
    await _settle();
    expect(host.transcript, isEmpty);
  });

  test('without an Http, the program stops with R038', () async {
    final host = _Host(_form, null);
    final i = Interpreter(compile('''
Sub btnA_Click()
    Debug.Print(Http.Get("http://x/a"))
End Sub
''', form: _form), host);
    final run = i.run();
    await _idle(i);
    i.raiseEvent('btnA', 'Click');
    final result = await run;
    expect(result, isA<RunFailed>());
    expect(
        (result as RunFailed).error.code, DiagnosticCode.componentUnavailable);
    expect(result.error.args, ['Http']);
  });
}
