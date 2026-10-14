import 'package:gubasic_lang/gubasic_lang.dart';

import 'i18n.dart';

/// Where a run is.
enum RunStatus { idle, running, completed, ended, stopped, failed, noStart }

/// One line of the Run tab's output window.
sealed class OutputEntry {
  const OutputEntry();
}

/// A line from Debug.Print.
class PrintedLine extends OutputEntry {
  const PrintedLine(this.text);
  final String text;
}

/// The run-time error that stopped the program.
class ErrorLine extends OutputEntry {
  const ErrorLine(this.error);
  final Diagnostic error;
}

/// The state of the Run tab: kept while other tabs are shown.
class RunState {
  RunStatus status = RunStatus.idle;
  final output = <OutputEntry>[];

  bool get isRunning => status == RunStatus.running;

  /// The status line for [status].
  UiText get statusText => switch (status) {
        RunStatus.idle => UiText.runIdle,
        RunStatus.running => UiText.runRunning,
        RunStatus.completed => UiText.runCompleted,
        RunStatus.ended => UiText.runEnded,
        RunStatus.stopped => UiText.runStopped,
        RunStatus.failed => UiText.runFailed,
        RunStatus.noStart => UiText.runNoStart,
      };

  /// Records how [result] ended.
  void finish(RunResult result) {
    status = switch (result) {
      RunCompleted() => RunStatus.completed,
      RunEnded() => RunStatus.ended,
      RunStopped() => RunStatus.stopped,
      RunFailed() => RunStatus.failed,
      RunNotStarted(reason: NotStartedReason.noStartProcedure) =>
        RunStatus.noStart,
      RunNotStarted() => RunStatus.idle,
    };
    if (result is RunFailed) output.add(ErrorLine(result.error));
  }
}
