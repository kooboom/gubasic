import '../diagnostics/diagnostic.dart';

/// How a run ended.
sealed class RunResult {
  const RunResult();
}

/// The start procedure returned.
class RunCompleted extends RunResult {
  const RunCompleted();
}

/// The program ran an `End` statement.
class RunEnded extends RunResult {
  const RunEnded();
}

/// Stopped from outside (the Stop button).
class RunStopped extends RunResult {
  const RunStopped();
}

/// A run-time error (an R code) that nothing caught.
class RunFailed extends RunResult {
  const RunFailed(this.error, {this.file});

  final Diagnostic error;

  /// The code file the error is in (`Form2.gbas`); null for code without
  /// a form.
  final String? file;
}

/// Why a program did not start.
enum NotStartedReason {
  /// The program has errors (D23: warnings alone do not block).
  hasErrors,

  /// There is no `Sub Main()` and no `Sub Form_Load()`.
  noStartProcedure,
}

class RunNotStarted extends RunResult {
  const RunNotStarted(this.reason);

  final NotStartedReason reason;
}
