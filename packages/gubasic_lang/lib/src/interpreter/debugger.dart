import 'dart:async';

import 'values.dart';

/// One variable of a paused program, as the IDE shows it (docs/DESIGN.md
/// D127): its name, its type and its value in GuBASIC's own notation.
class DebugVariable {
  const DebugVariable(this.name, this.type, this.value, {required this.local});

  final String name;
  final String type;
  final String value;

  /// A local or a parameter of the procedure, rather than a variable of
  /// the form or module.
  final bool local;
}

/// One procedure on the way to where the program is paused: the one
/// running, then the one that called it, and so on.
class DebugFrame {
  const DebugFrame(this.procedure, this.file, this.line);

  final String procedure;
  final String file;
  final int line;
}

/// Where a program is paused: before the statement at [line] of [file],
/// in [procedure], with the variables it can see.
class DebugPause {
  const DebugPause({
    required this.file,
    required this.line,
    required this.procedure,
    required this.stack,
    required this.variables,
  });

  final String file;
  final int line;
  final String procedure;

  /// The procedures running, the paused one first.
  final List<DebugFrame> stack;

  /// The procedure's locals and parameters, then the form's or module's
  /// variables.
  final List<DebugVariable> variables;
}

/// How the program goes on after a pause.
enum _Mode {
  /// Until a breakpoint.
  run,

  /// To the next statement, wherever it is.
  stepInto,

  /// To the next statement in this procedure or one that called it.
  stepOver,

  /// To the next statement in a procedure that called this one.
  stepOut,

  /// To the next statement, because the user asked for a pause.
  pause,
}

/// The debugger of a running program (docs/DESIGN.md D124 E, D127):
/// breakpoints by file and line, and stepping, as Visual Basic 6's.
///
/// The IDE keeps one across runs, so that breakpoints stay, and gives it
/// to the interpreter, which asks it before every statement
/// ([shouldPause]) and waits in [pausedAt] while the program is paused.
/// The program's screen keeps drawing meanwhile; its other handlers wait
/// their turn, as they do for a dialog (D5, D28).
class Debugger {
  final _breakpoints = <String, Set<int>>{};
  var _mode = _Mode.run;

  /// The call depth where a step over or a step out began.
  var _stepDepth = 0;
  DebugPause? _paused;
  Completer<void>? _resumed;

  /// Called when the program pauses or goes on.
  void Function()? onChanged;

  /// Set by the interpreter: evaluates an expression in the paused frame
  /// (D128).
  Future<String> Function(String text)? evaluator;

  /// The Immediate window: [text] as an expression in the paused
  /// procedure, its value as text, or what is wrong with it. Only while
  /// paused.
  Future<String> evaluate(String text) {
    final evaluate = evaluator;
    if (_paused == null || evaluate == null) {
      throw StateError('the program is not paused');
    }
    return evaluate(text);
  }

  /// Where the program is paused, or null while it runs.
  DebugPause? get paused => _paused;

  bool get isPaused => _paused != null;

  /// Whether the program will pause at its next statement.
  bool get isStepping => _mode != _Mode.run;

  /// The breakpoints of [file], by line.
  Set<int> breakpointsOf(String file) =>
      _breakpoints[file.toLowerCase()] ?? const {};

  /// Every file that has breakpoints, as given.
  Iterable<String> get filesWithBreakpoints => [
        for (final MapEntry(:key, :value) in _breakpoints.entries)
          if (value.isNotEmpty) key
      ];

  bool hasBreakpoint(String file, int line) =>
      _breakpoints[file.toLowerCase()]?.contains(line) ?? false;

  /// Sets a breakpoint at [line] of [file], or takes it away; gives
  /// whether there is one now.
  bool toggleBreakpoint(String file, int line) {
    final lines = _breakpoints.putIfAbsent(file.toLowerCase(), () => {});
    final set = !lines.remove(line);
    if (set) lines.add(line);
    onChanged?.call();
    return set;
  }

  /// Replaces the breakpoints of [file]: the editor moves them with the
  /// lines as the code changes.
  void setBreakpoints(String file, Set<int> lines) {
    _breakpoints[file.toLowerCase()] = Set.of(lines);
    onChanged?.call();
  }

  void clearBreakpoints() {
    _breakpoints.clear();
    onChanged?.call();
  }

  /// Pauses at the next statement the program runs.
  void pause() {
    if (_paused != null) return;
    _mode = _Mode.pause;
  }

  /// Goes on until the next breakpoint (F5 while paused).
  void resume() => _go(_Mode.run);

  /// Runs the next statement, following a call into its procedure (F8).
  void stepInto() => _go(_Mode.stepInto);

  /// Runs the next statement, a call as one step (Shift+F8).
  void stepOver() => _go(_Mode.stepOver);

  /// Runs the rest of this procedure (Ctrl+Shift+F8).
  void stepOut() => _go(_Mode.stepOut);

  void _go(_Mode mode) {
    final resumed = _resumed;
    if (resumed == null) return;
    _mode = mode;
    _stepDepth = _pausedDepth;
    _resumed = null;
    _paused = null;
    resumed.complete();
    onChanged?.call();
  }

  var _pausedDepth = 0;

  // -------------------------------------------------------------------------
  // The interpreter's side

  /// Whether to pause before the statement at [line] of [file], [depth]
  /// calls deep in the handler.
  bool shouldPause(String file, int line, int depth) => switch (_mode) {
        _Mode.run => hasBreakpoint(file, line),
        _Mode.stepInto || _Mode.pause => true,
        _Mode.stepOver => depth <= _stepDepth || hasBreakpoint(file, line),
        _Mode.stepOut => depth < _stepDepth || hasBreakpoint(file, line),
      };

  /// Pauses at [pause], [depth] calls deep, until the user goes on.
  Future<void> pausedAt(DebugPause pause, int depth) {
    _paused = pause;
    _pausedDepth = depth;
    _mode = _Mode.run;
    final resumed = _resumed = Completer<void>();
    onChanged?.call();
    return resumed.future;
  }

  /// A handler ended: a step past its last statement does not pause at the
  /// next event's handler; the program runs on, as Visual Basic's does.
  void handlerEnded() {
    if (_paused == null) _mode = _Mode.run;
  }

  /// The program ended or was stopped: a pause ends with it.
  void runEnded() {
    _mode = _Mode.run;
    final resumed = _resumed;
    _resumed = null;
    _paused = null;
    resumed?.complete();
    if (resumed != null) onChanged?.call();
  }
}

/// A value as the debugger shows it: text in quotes, an array or a list
/// with its items, a Structure with its fields, Nothing by name, and the
/// rest as GuBASIC writes it.
String debugValueText(Object? value) {
  String items(Iterable<Object?> all, int count) =>
      '(${all.take(20).map(debugValueText).join(', ')}${count > 20 ? ', …' : ''})';
  return switch (value) {
    null => 'Nothing',
    String s => '"${s.replaceAll('"', '""')}"',
    GbArray a => items(a.items, a.items.length),
    GbList l => items(l.items, l.items.length),
    // A Structure with its fields (D131).
    GbStruct st => '${st.type.name} { ${[
        for (var i = 0; i < st.values.length; i++)
          '${st.type.fields[i].name} = ${debugValueText(st.values[i])}'
      ].join(', ')} }',
    _ => formatValue(value),
  };
}
