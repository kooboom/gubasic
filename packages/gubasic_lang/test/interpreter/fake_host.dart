import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';

/// A host for tests: InputBox answers are given in advance, and everything
/// the program shows is recorded as lines:
///
///     Debug.Print: <text>
///     MsgBox: <prompt>            (or "MsgBox [<title>]: <prompt>")
///     InputBox: <prompt> → <answer>
///     Settings: <the settings as SaveSetting left them>
///
/// The settings start as [settings], as if an earlier run had saved them.
class FakeHost implements Host {
  FakeHost([List<String> answers = const [], this.settings])
      : _answers = List.of(answers);

  String? settings;

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

  @override
  Future<String?> loadSettings() async => settings;

  @override
  Future<void> saveSettings(String text) async {
    settings = text;
    transcript.add(TranscriptLine.saveSettings(text));
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
    {List<String> answers = const [], String? settings}) async {
  final host = FakeHost(answers, settings);
  final result = await runProgram(source, host);
  return [
    ...host.transcript,
    if (result is RunFailed)
      'Error ${result.error.code.code} @ ${result.error.line}',
    if (result is RunNotStarted) 'Not started: ${result.reason.name}',
    if (result is RunEnded) 'Ended',
  ];
}
