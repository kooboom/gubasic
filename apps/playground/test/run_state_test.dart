import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_playground/src/model/i18n.dart';
import 'package:gubasic_playground/src/model/run_state.dart';
import 'package:test/test.dart';

void main() {
  test('status follows how the run ended', () {
    final s = RunState();
    expect(s.statusText, UiText.runIdle);
    s.finish(const RunCompleted());
    expect(s.status, RunStatus.completed);
    s.finish(const RunEnded());
    expect(s.statusText, UiText.runEnded);
    s.finish(const RunStopped());
    expect(s.statusText, UiText.runStopped);
    s.finish(const RunNotStarted(NotStartedReason.noStartProcedure));
    expect(s.statusText, UiText.runNoStart);
  });

  test('a failed run adds its error to the output', () {
    final s = RunState()..output.add(const PrintedLine('before'));
    const error = Diagnostic(
        code: DiagnosticCode.divisionByZero,
        line: 3,
        column: 5,
        offset: 20,
        length: 5);
    s.finish(const RunFailed(error));
    expect(s.status, RunStatus.failed);
    expect(s.output.last, isA<ErrorLine>());
  });

  test('run blocked text in both languages', () {
    expect(runBlockedText(Locale.en, 1), startsWith('Fix the error first'));
    expect(runBlockedText(Locale.en, 3), startsWith('Fix the 3 errors first'));
    expect(runBlockedText(Locale.ko, 3), startsWith('오류 3개를 먼저 고쳐 주세요.'));
  });
}
