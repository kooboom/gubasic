import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import '../interpreter/fake_host.dart';

/// Date literals and Format's names in Korean (docs/DESIGN.md D115).
void main() {
  test('#yyyy-MM-dd# and #yyyy-MM-dd HH:mm(:ss)#; anything else is L010', () {
    final r =
        lex('x = #2026-10-29# + #2026-10-29 9:05# + #2026-10-29 23:59:59#');
    expect([
      for (final t in r.tokens)
        if (t.kind == TokenKind.dateLiteral) t.value
    ], [
      DateTime(2026, 10, 29),
      DateTime(2026, 10, 29, 9, 5),
      DateTime(2026, 10, 29, 23, 59, 59),
    ]);
    expect(r.diagnostics, isEmpty);
    for (final bad in [
      '#10/29/2026#',
      '#2026-02-30#',
      '#2026-10-29',
      '#2026-1-2#'
    ]) {
      expect(lex('x = $bad').diagnostics.map((d) => d.code.code), ['L010'],
          reason: bad);
    }
    // A # before anything but a digit is no date.
    expect(lex('a # b').diagnostics.single.code.code, 'L004');
  });

  test('Format names days and AM/PM in the app\'s language', () async {
    final program = compile('Sub Main()\n'
        'Debug.Print(Format(#2026-03-07 14:00#, "yyyy년 M월 d일 dddd tt h시"))\n'
        'End Sub\n');
    final host = FakeHost([], null);
    await Interpreter(program, host, messages: koreanMessages).run();
    expect(host.transcript, ['Debug.Print: 2026년 3월 7일 토요일 오후 2시']);
  });
}
