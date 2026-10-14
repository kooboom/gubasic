import 'package:gubasic_lang/gubasic_lang.dart';

/// A host for tests: InputBox answers are given in advance, and everything
/// the program shows is recorded as lines:
///
///     Debug.Print: <text>
///     MsgBox: <prompt>            (or "MsgBox [<title>]: <prompt>")
///     InputBox: <prompt> → <answer>
class FakeHost implements Host {
  FakeHost([List<String> answers = const []]) : _answers = List.of(answers);

  final List<String> _answers;
  final transcript = <String>[];
  var yields = 0;

  @override
  void debugPrint(String line) => transcript.add('Debug.Print: $line');

  @override
  Future<void> msgBox(String prompt, String title) async => transcript
      .add(title.isEmpty ? 'MsgBox: $prompt' : 'MsgBox [$title]: $prompt');

  @override
  Future<String> inputBox(
      String prompt, String title, String defaultValue) async {
    final answer = _answers.isEmpty ? '' : _answers.removeAt(0);
    transcript.add('InputBox: $prompt → $answer');
    return answer;
  }

  /// Yields to the event loop, as the playground does, so that timers (and
  /// a Stop request) get their turn.
  @override
  Future<void> yieldNow() {
    yields++;
    return Future<void>.delayed(Duration.zero);
  }
}

/// Runs [source] and returns the transcript, with a last line
/// `Error <code> @ <line>` if the run ended with a run-time error.
Future<List<String>> runAndRecord(String source,
    {List<String> answers = const []}) async {
  final host = FakeHost(answers);
  final result = await runProgram(source, host);
  return [
    ...host.transcript,
    if (result is RunFailed)
      'Error ${result.error.code.code} @ ${result.error.line}',
    if (result is RunNotStarted) 'Not started: ${result.reason.name}',
    if (result is RunEnded) 'Ended',
  ];
}
