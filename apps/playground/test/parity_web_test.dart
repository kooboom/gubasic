import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

import 'parity_cases.g.dart';

/// The parity programs of test/parity/, run on the VM and in Chrome
/// (`dart test -p vm,chrome`): the output must be exactly the same as
/// NAME.out on both platforms (D26: exact 64-bit Integers, same text form,
/// same random numbers).
class _Host implements Host {
  _Host(List<String> answers) : _answers = List.of(answers);
  final List<String> _answers;
  final transcript = <String>[];
  @override
  void debugPrint(String line) => transcript.add('Debug.Print: $line');
  @override
  Future<void> msgBox(String prompt, String title) async => transcript
      .add(title.isEmpty ? 'MsgBox: $prompt' : 'MsgBox [$title]: $prompt');
  @override
  Future<String> inputBox(String prompt, String title, String d) async {
    final answer = _answers.isEmpty ? '' : _answers.removeAt(0);
    transcript.add('InputBox: $prompt → $answer');
    return answer;
  }

  @override
  Future<void> yieldNow() async {}
}

void main() {
  test('parity cases are embedded', () {
    expect(parityCases.length, greaterThanOrEqualTo(12));
  });

  for (final (name, source, answers, expected, form, events) in parityCases) {
    if (form != null) {
      test(name, () async {
        final lines = await runEventScript(
            source, readFormFile(form, name: 'Form1').form, events!);
        expect('${lines.join('\n')}\n', expected);
      });
      continue;
    }
    test(name, () async {
      final host = _Host(answers);
      final result = await runProgram(source, host);
      final lines = [
        ...host.transcript,
        if (result is RunFailed)
          'Error ${result.error.code.code} @ ${result.error.line}',
        if (result is RunEnded) 'Ended',
      ];
      expect('${lines.join('\n')}\n', expected);
    });
  }
}
