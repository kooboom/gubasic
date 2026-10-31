import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import '../analyzer/analysis_result.dart';
import '../analyzer/builtins.dart';
import '../analyzer/compile.dart';
import '../analyzer/conversions.dart';
import '../analyzer/forms.dart';
import '../analyzer/members.dart';
import '../analyzer/symbols.dart';
import '../analyzer/types.dart';
import '../ast/ast.dart';
import '../ast/line_map.dart';
import '../diagnostics/diagnostic.dart';
import '../diagnostics/messages_en.dart';
import '../forms/anchor.dart';
import '../forms/component.dart';
import '../forms/keys.dart';
import '../forms/pictures.dart';
import '../forms/shortcut.dart';
import '../lexer/keyword.dart';
import 'checked_math.dart';
import 'host.dart';
import 'rng.dart';
import 'run_result.dart';
import 'values.dart';

/// How deep procedure calls may nest before R009, on every platform.
/// Chosen by measuring the VM and Chrome (see docs/LANGUAGE.md §9).
const int maxCallDepth = 10000;

/// How often, in loop rounds and calls, the interpreter looks at the
/// clock to see whether it is time to let the screen update.
const int _stepsPerCheck = 256;

/// The interpreter lets the screen update (Host.yieldNow) once this long
/// has passed since it last did, not after a number of rounds: on the web
/// each pause lasts the browser's shortest timer, about 4.5 ms, so pausing
/// every 1000 rounds spent more time waiting than computing
/// (STAGE2_PLAN §7). It does not change what the program computes.
const int _microsecondsPerYield = 10000;

/// The longest the text of a program's settings can be, in characters
/// (about 64 KB), so that a program cannot fill the browser's storage,
/// where the web IDE keeps its projects too (D48).
const settingsLimit = 65536;

/// What became of an event passed to [Interpreter.raiseEvent].
enum EventOutcome {
  /// Its handler started, or waits for the running handler (D28).
  started,

  /// Its handler is still running, so the event is ignored (D5).
  ignored,

  /// A MsgBox or InputBox is open, so the event is blocked (D28).
  blocked,

  /// The control has no handler for it.
  noHandler,

  /// The program is not running.
  notRunning,

  /// A Timer that is not Enabled does not tick (D100).
  disabled,
}

/// Runs an analyzed program (docs/DESIGN.md §3.1).
///
/// Follows the analyzer exactly: names, conversions, call/item decisions
/// and loop variables come from [CompileResult.analysis]. Every call to a
/// user procedure is awaited; expressions without such calls are evaluated
/// synchronously, which computes the same values faster.
///
/// A program with a form runs its event handlers one at a time (D28):
/// another handler starts, or one waiting in DoEvents goes on, only when
/// the running one finishes or waits in DoEvents. MsgBox and InputBox keep
/// the turn, and events while they are open are blocked.
class Interpreter {
  /// Runs [program]: code without a form, or the code of one form.
  Interpreter(
    CompileResult program,
    Host host, {
    Map<DiagnosticCode, String> messages = englishMessages,
    int callDepthLimit = maxCallDepth,
  }) : this._(
          program,
          switch (program.analysis.form) {
            final form? => ProjectProgram(
                [FormProgram(form.name, form, program)],
                FormProgram(form.name, form, program)),
            null => null,
          },
          host,
          messages,
          callDepthLimit,
        );

  /// Runs a project's forms, starting with its startup form (D88).
  Interpreter.project(
    ProjectProgram project,
    Host host, {
    Map<DiagnosticCode, String> messages = englishMessages,
    int callDepthLimit = maxCallDepth,
  }) : this._(project.startup.program, project, host, messages, callDepthLimit);

  Interpreter._(
      this.program, this.project, this.host, this.messages, this.callDepthLimit)
      : _a = _merged(program, project) {
    final project = this.project;
    if (project == null) {
      _top = _FormRun(null, LineMap(program.parseResult.source));
      _frame = _Frame(null, _top);
      return;
    }
    for (final f in project.forms) {
      final run = _FormRun(f, LineMap(f.program.parseResult.source));
      _forms[f.name.toLowerCase()] = run;
      _setUpControls(run);
      for (final symbol in f.program.analysis.fileScope.symbols.values) {
        if (symbol.procedure case final p?) _formOf[p] = run;
      }
    }
    // The modules (D102): code without a form, whose procedures run with
    // no controls and no Me.
    for (final m in project.modules) {
      final run =
          _FormRun(null, LineMap(m.program.parseResult.source), module: m);
      _modules[m.name.toLowerCase()] = run;
      for (final symbol in m.program.analysis.fileScope.symbols.values) {
        if (symbol.procedure case final p?) _formOf[p] = run;
      }
    }
    _top = _forms[project.startup.name.toLowerCase()]!;
    _frame = _Frame(null, _top);
  }

  /// Puts [run]'s form and the controls of its form file on it, as at the
  /// start, each with the handlers its code gives it by name or by
  /// Handles (D98); the controls the program added are gone.
  void _setUpControls(_FormRun run) {
    final f = run.program!;
    run.controls.clear();
    run.designed.clear();
    run.order.clear();
    final form =
        run.controls[null] = GbControl(null, f.file.component, form: f.name);
    for (final c in f.file.controls) {
      final control =
          GbControl(c.name, c.component, form: f.name, container: c.container);
      run.controls[c.name.toLowerCase()] = control;
      run.designed[c.name.toLowerCase()] = control;
      // A Timer is not one of the controls seen on the form (D100).
      if (c.component.visual) run.order.add(control);
    }
    for (final MapEntry(key: decl, value: events)
        in f.program.analysis.handlers.entries) {
      for (final h in events) {
        final target = switch (h.control) {
          null => form,
          final c => run.designed[c.name.toLowerCase()]!,
        };
        target.handlers[h.event.name.toLowerCase()] = decl;
      }
    }
  }

  /// The analysis of every form together: the interpreter looks nodes up
  /// in it, and nodes of different files are different keys.
  static AnalysisResult _merged(CompileResult program, ProjectProgram? p) {
    if (p == null || (p.forms.length == 1 && p.modules.isEmpty)) {
      return program.analysis;
    }
    final a = program.analysis;
    final merged = AnalysisResult(
      diagnostics: a.diagnostics,
      fileScope: a.fileScope,
      form: a.form,
      pictures: a.pictures,
    );
    for (final b in [
      for (final f in p.forms) f.program.analysis,
      for (final m in p.modules) m.program.analysis,
    ]) {
      merged.symbols.addAll(b.symbols);
      merged.types.addAll(b.types);
      merged.conversions.addAll(b.conversions);
      merged.invokeKinds.addAll(b.invokeKinds);
      merged.implicitCalls.addAll(b.implicitCalls);
      merged.members.addAll(b.members);
      merged.loopVariables.addAll(b.loopVariables);
      merged.handlers.addAll(b.handlers);
      merged.castTypes.addAll(b.castTypes);
    }
    return merged;
  }

  /// The startup form's code, or the code without a form.
  final CompileResult program;

  /// The project's forms; null for code without a form.
  final ProjectProgram? project;
  final Host host;

  /// The language of `ex.Message` for run-time errors caught by `Try`.
  final Map<DiagnosticCode, String> messages;
  final int callDepthLimit;

  final AnalysisResult _a;

  final _fields = <Symbol, Object?>{};
  final _statics = <Symbol, Object?>{};
  final _random = GbRandom();
  late _Frame _frame;
  var _depth = 0;
  var _steps = 0;

  /// Time since the screen last had a chance to update.
  final _sinceYield = Stopwatch()..start();
  var _stopRequested = false;

  // Forms and events (D28, D88).
  final _forms = <String, _FormRun>{};

  /// The project's modules, by lower-case name (D102).
  final _modules = <String, _FormRun>{};

  /// The symbol of a module's own code for one another file knew it by
  /// (D102); [symbol] itself otherwise.
  Symbol _canon(Symbol symbol) => project?.canonical[symbol] ?? symbol;
  final _formOf = Map<ProcedureDecl, _FormRun>.identity();

  /// The startup form, or the code without a form.
  late final _FormRun _top;

  /// The forms shown, from the back to the front.
  final _shown = <_FormRun>[];

  /// Those of [_shown] shown by ShowDialog.
  final _shownAsDialog = Set<_FormRun>.identity();

  /// Handlers that are running or waiting for their turn (D5).
  final _running = Set<ProcedureDecl>.identity();

  /// The turn: only its holder runs program code. MsgBox and InputBox keep
  /// it; DoEvents passes it on to the handlers waiting for it, in order.
  var _turnTaken = false;
  final _turnQueue = Queue<Completer<void>>();
  var _openDialogs = 0;

  /// How a program with a form ended; null while it runs.
  RunResult? _ended;
  Completer<RunResult>? _formRun;

  /// The handler of [event] of [control] (null: the form) on [form].
  ProcedureDecl? _handler(_FormRun form, String? control, String event) =>
      form.controls[control?.toLowerCase()]?.handlers[event.toLowerCase()]
          as ProcedureDecl?;

  /// What a call of [handler] gets: [sender], when it has a `sender`
  /// parameter (D98).
  static List<Object?> _senderArgs(ProcedureDecl handler, GbControl? sender) =>
      handler.parameters.length == 1 ? [sender] : const [];

  /// The form in front: the one that takes what the user does.
  _FormRun? get _front => _shown.isEmpty ? null : _shown.last;

  /// The form [name] (any case), or null.
  _FormRun? _formNamed(String name) => _forms[name.toLowerCase()];

  FormHost get _formHost => host as FormHost;

  /// Asks a running program to stop: at its next yield, or at once when it
  /// has a form.
  void stop() {
    _stopRequested = true;
    if (_formRun != null) _finish(const RunStopped());
  }

  /// The user closed the window: the program ends (RunCompleted), after
  /// the Form_Closed of the forms shown, from the front (D88).
  void closeForm() {
    if (_formRun == null || _ended != null) return;
    final closing = [
      for (final f in _shown.reversed)
        if (_handler(f, null, 'Closed') != null) f,
    ];
    if (closing.isEmpty) {
      _finish(const RunCompleted());
      return;
    }
    unawaited(_closeAll());
  }

  Future<void> _closeAll() async {
    await _takeTurn();
    try {
      for (final f in _shown.reversed.toList()) {
        if (_ended != null) break;
        f.loaded = false;
        final closed = _handler(f, null, 'Closed');
        if (closed == null) continue;
        _frame = _Frame(null, f);
        _depth = 0;
        await _guard(() => _runNow(closed, f.controls[null]));
      }
    } finally {
      _passTurn();
    }
    _finish(const RunCompleted());
  }

  /// Whether the program is waiting for the user: no handler is running
  /// (or the running ones wait in DoEvents), or a dialog is open. A test
  /// script takes its next step only then.
  bool get isWaitingForUser =>
      _ended != null || _openDialogs > 0 || (!_turnTaken && _turnQueue.isEmpty);

  /// Whether a MsgBox or InputBox is open.
  bool get hasOpenDialog => _openDialogs > 0;

  /// Runs the handler of [event] of [control] (null: the form), following
  /// D5 and D28. Does not wait for the handler to finish.
  ///
  /// [form] is the form the user acts on; only the one in front takes it
  /// (D88). Null: the one in front.
  EventOutcome raiseEvent(String? control, String event, {String? form}) {
    if (refusal(control, event, form: form) case final refused?) {
      return refused;
    }
    final front = _front!;
    final handler = _handler(front, control, event);
    if (handler == null) return EventOutcome.noHandler;
    _runHandler(handler, front.controls[control?.toLowerCase()]);
    return EventOutcome.started;
  }

  /// Why [raiseEvent] would not take [event] of [control] now: the program
  /// is not running, a dialog is open, or its handler is running. Null
  /// when it would. A CheckBox asks before the user's click changes it, so
  /// that a click whose Changed would be ignored changes nothing (D44).
  EventOutcome? refusal(String? control, String event, {String? form}) {
    if (_formRun == null || _ended != null) return EventOutcome.notRunning;
    if (_openDialogs > 0) return EventOutcome.blocked;
    final front = _front;
    if (front == null) return EventOutcome.notRunning;
    // A form behind the front one, behind a dialog for one.
    if (form != null && _formNamed(form) != front) return EventOutcome.blocked;
    final handler = _handler(front, control, event);
    if (handler != null && _running.contains(handler)) {
      return EventOutcome.ignored;
    }
    return null;
  }

  /// A Timer's tick (D100), as the host's clock or a test script makes it:
  /// [timer] of [form], shown or hidden, any time from its Form_Load until
  /// its Close, while Enabled. Like a click it waits for the running
  /// handler and does not re-enter (D5, D28), and is dropped while a
  /// MsgBox or InputBox is open; unlike a click, it reaches a form behind
  /// the one in front.
  EventOutcome raiseTick(String timer, {required String form}) {
    if (_formRun == null || _ended != null) return EventOutcome.notRunning;
    final run = _formNamed(form);
    final control = run?.controls[timer.toLowerCase()];
    if (run == null || control == null || !run.loaded) {
      return EventOutcome.notRunning;
    }
    if (_openDialogs > 0) return EventOutcome.blocked;
    if (_formHost.getProperty(run.name, control.name, 'Enabled') != true) {
      return EventOutcome.disabled;
    }
    final handler = control.handlers['tick'] as ProcedureDecl?;
    if (handler == null) return EventOutcome.noHandler;
    if (_running.contains(handler)) return EventOutcome.ignored;
    _runHandler(handler, control);
    return EventOutcome.started;
  }

  /// A key pressed (KeyDown, again while held) or let go (KeyUp) on the
  /// form in front (D101). [inTextBox]: while a TextBox is typed in, the
  /// form gets it only when its KeyPreview is True. Like a click it waits
  /// for the running handler, does not re-enter, and is blocked while a
  /// dialog is open.
  EventOutcome raiseKey(String event, GbKeyEvent key,
      {String? form, bool inTextBox = false}) {
    if (refusal(null, event, form: form) case final refused?) return refused;
    final front = _front!;
    if (inTextBox &&
        _formHost.getProperty(front.name, null, 'KeyPreview') != true) {
      return EventOutcome.noHandler;
    }
    final handler = _handler(front, null, event);
    if (handler == null) return EventOutcome.noHandler;
    _runHandler(handler, front.controls[null], args: [key]);
    return EventOutcome.started;
  }

  /// The user presses or lets go a mouse button on [control] (null: the
  /// form) of the form in front (D111): its MouseDown or MouseUp, told
  /// [mouse]. Refused, as a click is, while a dialog is open or the
  /// handler runs (D5, D28).
  EventOutcome raiseMouse(String? control, String event, GbMouseEvent mouse,
      {String? form}) {
    if (refusal(control, event, form: form) case final refused?) {
      return refused;
    }
    final front = _front!;
    final handler = _handler(front, control, event);
    if (handler == null) return EventOutcome.noHandler;
    _runHandler(handler, front.controls[control?.toLowerCase()], args: [mouse]);
    return EventOutcome.started;
  }

  /// The procedure a run starts with: `Sub Main()`, or else
  /// `Sub Form_Load()`. Null if there is neither.
  ProcedureDecl? get startProcedure {
    for (final name in ['main', 'form_load']) {
      final symbol = _a.fileScope.symbols[name];
      final p = symbol?.procedure;
      if (p != null && !p.isFunction && p.parameters.isEmpty) return p;
    }
    return null;
  }

  /// Runs the program. Without a form: `Sub Main` (or `Sub Form_Load`),
  /// until it returns. With a form: form-level variables, `Form_Load`,
  /// then the form's events, until the form is closed, `End` runs, an
  /// error is not caught or [stop] is called (docs/LANGUAGE.md §9.1).
  Future<RunResult> run() async {
    if (project?.hasErrors ?? program.hasErrors) {
      return const RunNotStarted(NotStartedReason.hasErrors);
    }
    if (_a.form != null) return _runForm();
    final start = startProcedure;
    if (start == null) {
      return const RunNotStarted(NotStartedReason.noStartProcedure);
    }
    await _takeTurn();
    try {
      await _initFields();
      await _callUser(start, const [], start);
      return const RunCompleted();
    } on _EndProgram {
      return const RunEnded();
    } on _Stop {
      return const RunStopped();
    } on _Failure catch (f) {
      return _failed(f.code, f.node, f.args, f.form);
    } on _Thrown catch (t) {
      return _failed(DiagnosticCode.unhandledException, t.node,
          [t.exception.message], t.form);
    } finally {
      _passTurn();
    }
  }

  /// Gives the variables of [form]'s code (outside procedures) their
  /// initial values, or of the code without a form.
  Future<void> _initFields([_FormRun? form]) async {
    final run = form ?? _top;
    final code = run.code ?? program;
    final saved = _frame;
    _frame = _Frame(null, run);
    try {
      for (final member in code.parseResult.unit.members) {
        if (member is FieldDecl) {
          final symbol = _a.symbols[member.declarator.name];
          if (symbol != null) {
            _fields[symbol] = await _initialValue(member.declarator, symbol);
          }
        }
      }
    } finally {
      _frame = saved;
    }
  }

  Future<RunResult> _runForm() async {
    if (host is! FormHost) {
      throw ArgumentError('a program with a form needs a FormHost');
    }
    final done = _formRun = Completer<RunResult>();
    await _takeTurn();
    try {
      // Every module's variables (D102), then every form's, the startup
      // form's first, so that each can use the others' from the start
      // (D88).
      await _guard(() async {
        for (final m in _modules.values) {
          await _initFields(m);
        }
        await _initFields(_top);
        for (final f in _forms.values) {
          if (f != _top) await _initFields(f);
        }
      });
      final main = project?.startsWithMain == true ? project!.main : null;
      if (_ended == null && main != null) {
        // Sub Main shows the forms it wants; when it ends with none shown,
        // so does the program (D102).
        final (module, procedure) = main;
        _frame = _Frame(null, _modules[module.name.toLowerCase()]!);
        _depth = 0;
        await _guard(() => _callUser(procedure, const [], procedure));
        if (_ended == null && _shown.isEmpty) _finish(const RunCompleted());
      } else if (_ended == null) {
        _frame = _Frame(null, _top);
        _depth = 0;
        await _guard(() => _show(_top));
      }
    } finally {
      _passTurn();
    }
    return done.future;
  }

  /// Tells the host which forms are shown.
  void _showForms() => _formHost.showForms([
        for (final f in _shown)
          ShownForm(f.name, dialog: _shownAsDialog.contains(f)),
      ]);

  /// `Show`: puts [form] in front (D88). A form shown already comes to the
  /// front; one not loaded starts (again after Close: its variables and
  /// controls as at the start), runs Form_Load, is shown, then runs
  /// Form_Resize once, as in Visual Basic 6 (D58).
  Future<void> _show(_FormRun form, {bool dialog = false}) async {
    if (_shown.remove(form)) {
      _shown.add(form);
      _showForms();
      return;
    }
    final loading = !form.loaded;
    if (loading) {
      if (form.started) {
        _formHost.resetForm(form.name);
        _setUpControls(form);
        await _initFields(form);
      }
      form
        ..loaded = true
        ..started = true;
      final load = _handler(form, null, 'Load');
      if (load != null) await _runNow(load, form.controls[null]);
      if (_ended != null || !form.loaded) return;
    }
    _shown.add(form);
    if (dialog) _shownAsDialog.add(form);
    _showForms();
    final resize = loading ? _handler(form, null, 'Resize') : null;
    if (resize != null) await _runNow(resize, form.controls[null]);
  }

  /// `ShowDialog`: shows [form] in front as a dialog and waits until it
  /// goes (D88). While it waits, the dialog's handlers run, as in
  /// DoEvents (D28). Gives its DialogResult then; Cancel when it went
  /// without one (D103).
  Future<int> _showDialog(_FormRun form, Node at) async {
    if (_shown.contains(form)) {
      _fail(DiagnosticCode.dialogAlreadyShown, at, [form.name]);
    }
    // A form hidden keeps its properties; one closed starts again anyway.
    if (form.loaded &&
        _formHost.getProperty(form.name, null, 'DialogResult') != 0) {
      _formHost.setProperty(form.name, null, 'DialogResult', 0);
    }
    final gone = form.dialog = Completer<void>();
    await _show(form, dialog: true);
    if (_shown.contains(form)) {
      final frame = _frame;
      final depth = _depth;
      _passTurn();
      await gone.future;
      await _takeTurn();
      _frame = frame;
      _depth = depth;
    }
    if (_ended != null) throw const _Abandoned();
    if (_stopRequested) throw const _Stop();
    final result =
        _formHost.getProperty(form.name, null, 'DialogResult') as int;
    return result == 0 ? dialogResults['Cancel']! : result;
  }

  /// Takes [form] away from the forms shown; the program ends when none is
  /// left (D88).
  void _takeAway(_FormRun form) {
    if (!_shown.remove(form)) return;
    _shownAsDialog.remove(form);
    form.dialog?.complete();
    form.dialog = null;
    if (_shown.isNotEmpty) _showForms();
  }

  /// `Hide`: takes [form] away, keeping its variables and controls.
  void _hide(_FormRun form) {
    _takeAway(form);
    _endIfNoneShown();
  }

  /// `Close`: takes [form] away and runs its Form_Closed; shown again, it
  /// starts again. Its variables keep their values until then, so that a
  /// dialog's answer can be read after it closes.
  Future<void> _close(_FormRun form) async {
    if (!form.loaded) return;
    form.loaded = false;
    _takeAway(form);
    final closed = _handler(form, null, 'Closed');
    if (closed != null) await _runNow(closed, form.controls[null]);
    _endIfNoneShown();
  }

  /// With no form shown, the program has ended: what is running stops.
  void _endIfNoneShown() {
    if (_shown.isNotEmpty || _ended != null) return;
    _finish(const RunCompleted());
    throw const _Abandoned();
  }

  /// Runs [handler] when it gets the turn (D28), for an event of [sender];
  /// with [args] for an event that has parameters (D101).
  Future<void> _runHandler(ProcedureDecl handler, GbControl? sender,
      {List<Object?>? args}) async {
    _running.add(handler);
    try {
      await _takeTurn();
      try {
        if (_ended != null) return;
        _frame = _Frame(null, _formOf[handler] ?? _top);
        _depth = 0;
        await _guard(() => _callUser(
            handler,
            args == null
                ? _senderArgs(handler, sender)
                // A sender before the event's own arguments (D112).
                : handler.parameters.length == args.length + 1
                    ? [sender, ...args]
                    : args,
            handler));
      } finally {
        _passTurn();
      }
    } finally {
      _running.remove(handler);
    }
  }

  /// Runs [body]; an End, a stop or an error that nothing caught ends the
  /// program with a form.
  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } on _EndProgram {
      _finish(const RunEnded());
    } on _Stop {
      _finish(const RunStopped());
    } on _Failure catch (f) {
      _finish(_failed(f.code, f.node, f.args, f.form));
    } on _Thrown catch (t) {
      _finish(_failed(DiagnosticCode.unhandledException, t.node,
          [t.exception.message], t.form));
    } on _Abandoned {
      // The program ended while this handler waited.
    }
  }

  /// Ends a program with a form. Handlers still waiting are abandoned the
  /// next time they would go on.
  void _finish(RunResult result) {
    final done = _formRun;
    if (done == null || _ended != null) return;
    _ended = result;
    _formHost.endProgram();
    // Handlers waiting for a dialog form go on, and stop (_Abandoned).
    for (final f in _forms.values) {
      f.dialog?.complete();
      f.dialog = null;
    }
    done.complete(result);
  }

  Future<void> _takeTurn() async {
    if (!_turnTaken) {
      _turnTaken = true;
      return;
    }
    final waiter = Completer<void>();
    _turnQueue.add(waiter);
    await waiter.future;
  }

  void _passTurn() {
    if (_turnQueue.isNotEmpty) {
      _turnQueue.removeFirst().complete(); // the turn goes straight on
    } else {
      _turnTaken = false;
    }
  }

  /// `DoEvents`: the waiting handlers run (D28), then this one goes on
  /// with its own procedure frames.
  Future<Object?> _doEvents() async {
    final frame = _frame;
    final depth = _depth;
    _passTurn();
    await host.yieldNow();
    _sinceYield.reset();
    await _takeTurn();
    _frame = frame;
    _depth = depth;
    if (_ended != null) throw const _Abandoned();
    if (_stopRequested) throw const _Stop();
    return null;
  }

  /// MsgBox and InputBox keep the turn: nothing else runs, and events are
  /// blocked, until the dialog is closed (D28).
  Future<Object?> _dialog(Future<Object?> open) async {
    _openDialogs++;
    final Object? answer;
    try {
      answer = await open;
    } finally {
      _openDialogs--;
    }
    if (_ended != null) throw const _Abandoned();
    return answer;
  }

  Diagnostic _diagnostic(
      DiagnosticCode code, Node node, List<String> args, _FormRun form) {
    final (line, column) = form.lines.locate(node.start);
    return Diagnostic(
      code: code,
      line: line,
      column: column,
      offset: node.start,
      length: node.end - node.start,
      args: args,
    );
  }

  Never _fail(DiagnosticCode code, Node node, [List<String> args = const []]) =>
      throw _Failure(code, node, args, _frame.form);

  /// How an error that nothing caught ends the run: with the file it is in.
  RunFailed _failed(
          DiagnosticCode code, Node node, List<String> args, _FormRun form) =>
      RunFailed(_diagnostic(code, node, args, form), file: form.codeFile);

  /// Counts a loop round or a call; true when it is time to yield. Kept
  /// synchronous so that loops do not create a Future every round.
  bool _tick() =>
      ++_steps % _stepsPerCheck == 0 &&
      _sinceYield.elapsedMicroseconds >= _microsecondsPerYield;

  /// Lets the screen update; other handlers do not run (D28).
  Future<void> _yield() async {
    await host.yieldNow();
    _sinceYield.reset();
    if (_ended != null) throw const _Abandoned();
    if (_stopRequested) throw const _Stop();
  }

  /// Runs [block] synchronously when nothing in it waits.
  FutureOr<_Flow> _body(Block block) =>
      _awaits(block) ? _block(block) : _blockSync(block);

  // -------------------------------------------------------------------------
  // Variables

  Object? _read(Symbol symbol) => switch (_canon(symbol)) {
        final s when s.storage == Storage.field => _fields[s],
        final s when s.storage == Storage.staticLocal => _statics[s],
        final s when s.storage == Storage.local => _frame.vars[s],
        // A form or a module of the project, or a control of the form
        // whose code runs.
        final s => switch (s.kind) {
            SymbolKind.form => _formNamed(s.name)!.controls[null],
            SymbolKind.module => GbModule(s.name),
            _ => _frame.form.designed[s.name.toLowerCase()],
          },
      };

  void _write(Symbol written, Object? value) {
    final symbol = _canon(written);
    switch (symbol.storage) {
      case Storage.field:
        _fields[symbol] = value;
      case Storage.staticLocal:
        _statics[symbol] = value;
      default:
        _frame.vars[symbol] = value;
    }
  }

  /// The value a declaration gives its variable: the initial value, a new
  /// object (`As New`), a sized array, or the type's default.
  Future<Object?> _initialValue(VariableDeclarator d, Symbol symbol) async {
    final type = symbol.type;
    if (d.initializer != null) return _value(d.initializer!);
    if (d.isArray) {
      if (d.arrayBound == null) return null;
      final bound = await _value(d.arrayBound!);
      return _newArray(type, bound, d);
    }
    if (d.isNew) {
      final args = [
        for (final a in d.newArguments ?? const <Expr>[]) await _value(a)
      ];
      return _construct(type, args);
    }
    return defaultValue(type);
  }

  GbArray _newArray(GbType type, Object? bound, Node at) {
    final element = type is ArrayType ? type.element : GbType.unknown;
    final upper = (bound as GbInt).toSmallInt();
    if (upper == null || upper < -1 || upper > 100000000) {
      _fail(DiagnosticCode.invalidArgument, at, ['Dim']);
    }
    return GbArray(element,
        List<Object?>.generate(upper + 1, (_) => defaultValue(element)));
  }

  Object? _construct(GbType type, List<Object?> args) => switch (type) {
        ListType(:final element) => GbList(element),
        // A control made at run time, on no form yet (D98).
        ControlType(:final component) =>
          GbControl(null, component, attached: false),
        GbType.exception =>
          GbException(args.isEmpty ? '' : args.first as String),
        _ => defaultValue(type),
      };

  // -------------------------------------------------------------------------
  // Procedures

  Future<Object?> _callUser(
      ProcedureDecl p, List<Object?> args, Node at) async {
    // Every call starts in a fresh microtask: deep recursion grows the heap,
    // not the platform's call stack (J3).
    await Future<void>.value();
    if (_depth >= callDepthLimit) {
      _fail(DiagnosticCode.callsTooDeep, at, ['$callDepthLimit']);
    }
    if (_tick()) await _yield();
    final saved = _frame;
    final frame = _Frame(p, _formOf[p] ?? _top);
    final symbol = _a.symbols[p.name];
    for (var i = 0; i < p.parameters.length; i++) {
      final param = p.parameters[i];
      final paramSymbol = _a.symbols[param.name];
      if (paramSymbol == null) continue;
      if (i < args.length) {
        frame.vars[paramSymbol] = args[i];
      } else {
        _frame = frame; // defaults are evaluated in the callee
        frame.vars[paramSymbol] = param.defaultValue == null
            ? defaultValue(paramSymbol.type)
            : await _value(param.defaultValue!);
        _frame = saved;
      }
    }
    if (p.isFunction) {
      frame.result =
          defaultValue(symbol?.callable?.returnType ?? GbType.unknown);
    }
    _depth++;
    _frame = frame;
    try {
      await _block(p.body);
      return frame.result;
    } catch (_) {
      // Dart passes an error up a chain of awaiting calls synchronously,
      // which overflows the platform stack after about a thousand calls.
      // One microtask per call keeps the stack flat on the way up too.
      await Future<void>.value();
      rethrow;
    } finally {
      _frame = saved;
      _depth--;
    }
  }

  // -------------------------------------------------------------------------
  // Statements

  /// Whether running [node] may need to wait: it calls a user procedure or
  /// MsgBox / InputBox / DoEvents, or contains a loop (which yields).
  bool _awaits(Node node) => _awaitsCache[node] ??= _computeAwaits(node);
  final _awaitsCache = Map<Node, bool>.identity();

  bool _computeAwaits(Node node) {
    switch (node) {
      case ForStmt() || ForEachStmt() || DoLoopStmt() || TryStmt():
        return true;
      case AssignmentStmt(:final MemberExpr target)
          when _assignmentMayRunEvent(target):
        return true;
      case InvokeExpr():
        // Not an item: a call, or through an Object maybe one.
        if (_a.invokeKinds[node] != InvokeKind.item &&
            _callWaits(node.target)) {
          return true;
        }
      case NameExpr() || MemberExpr():
        if (_a.implicitCalls.contains(node) && _callWaits(node as Expr)) {
          return true;
        }
      default:
    }
    return node.children.any(_awaits);
  }

  /// Whether calling the method [target] may run a change event
  /// (ListBox.Clear -> Changed): a control's method, known from the
  /// component or decided at run time through an Object. Other built-in
  /// methods never wait.
  bool _methodMayRunEvent(MemberExpr target) {
    final type = _a.types[target.target];
    // A module's procedure (D102) is user code.
    if (type is ModuleType) {
      return type.module.procedures.containsKey(target.name.name.toLowerCase());
    }
    if (type is ControlType) {
      final name = target.name.name.toLowerCase();
      // A form's procedure (D88) is user code.
      return type.component.methods.containsKey(name) ||
          type.form?.procedures.containsKey(name) == true;
    }
    return type == GbType.object;
  }

  /// Whether assigning to [target] may run a change event (TextBox.Text ->
  /// Changed): known from the component, or decided at run time through
  /// an Object. Other property assignments keep the fast path (D25).
  bool _assignmentMayRunEvent(MemberExpr target) {
    final type = _a.types[target.target];
    if (type is ControlType) {
      final p = type.component.properties[target.name.name.toLowerCase()];
      // A form's DialogResult may close it (D103).
      return p?.changeEvent != null ||
          (type.component == formComponent && p?.name == 'DialogResult');
    }
    return type == GbType.object;
  }

  bool _callWaits(Expr target) {
    if (target is MemberExpr) return _methodMayRunEvent(target);
    final symbol = _a.symbols[target];
    if (symbol == null) return false;
    if (symbol.kind == SymbolKind.procedure) return true;
    return const {'MsgBox', 'InputBox', 'DoEvents', 'SaveSetting', 'GetSetting'}
        .contains(symbol.name);
  }

  Future<_Flow> _block(Block block) async {
    for (final s in block.statements) {
      final flow = _awaits(s) ? await _statementAsync(s) : _statementSync(s);
      if (flow != _Flow.normal) return flow;
    }
    return _Flow.normal;
  }

  _Flow _blockSync(Block block) {
    for (final s in block.statements) {
      final flow = _statementSync(s);
      if (flow != _Flow.normal) return flow;
    }
    return _Flow.normal;
  }

  /// A statement without waits (no loops, no waiting calls inside).
  _Flow _statementSync(Stmt s) {
    switch (s) {
      case LocalDeclStmt():
        _declareSync(s);
      case AssignmentStmt():
        final changed = _assign(s.target, _valueSync(s.value), _indexSync);
        if (changed != null) {
          throw StateError('a change event is always run asynchronously');
        }
      case AddHandlerStmt():
        _addHandler(s, _valueSync(s.event.target));
      case ExpressionStmt():
        _evalSync(s.expression);
      case IfStmt():
        for (final b in s.branches) {
          if (_valueSync(b.condition) as bool) return _blockSync(b.body);
        }
        if (s.elseBlock != null) return _blockSync(s.elseBlock!);
      case SelectStmt():
        final subject = _valueSync(s.subject);
        for (final c in s.cases) {
          if (c.isElse ||
              c.clauses.any((cl) => _caseMatches(cl, subject, _valueSync))) {
            return _blockSync(c.body);
          }
        }
      case ExitStmt():
        return _exitFlow(s);
      case ReturnStmt():
        if (s.value != null) _frame.result = _valueSync(s.value!);
        return _Flow.exitProcedure;
      case TryStmt():
        throw StateError('Try is always run with _statementAsync');
      case ThrowStmt():
        throw _Thrown(_valueSync(s.value)! as GbException, s, _frame.form);
      case ReDimStmt():
        _reDim(s, _valueSync(s.bound));
      case EndStmt():
        throw const _EndProgram();
      case ErrorStmt():
        break;
      case ForStmt() || ForEachStmt() || DoLoopStmt():
        throw StateError('loops are always run with _statementAsync');
    }
    return _Flow.normal;
  }

  Future<_Flow> _statementAsync(Stmt s) async {
    switch (s) {
      case LocalDeclStmt():
        await _declare(s);
      case AssignmentStmt():
        final value = await _value(s.value);
        final index = await _indexAsync(s.target);
        final changed = _assign(s.target, value, (_) => index);
        if (changed != null) await _runNow(changed.handler, changed.control);
        final call = _pendingCall;
        if (call != null) {
          _pendingCall = null;
          await call();
        }
      case AddHandlerStmt():
        _addHandler(s, await _value(s.event.target));
      case ExpressionStmt():
        await _eval(s.expression);
      case IfStmt():
        for (final b in s.branches) {
          if (await _value(b.condition) as bool) return _block(b.body);
        }
        if (s.elseBlock != null) return _block(s.elseBlock!);
      case SelectStmt():
        final subject = await _value(s.subject);
        for (final c in s.cases) {
          var matches = c.isElse;
          for (final cl in c.clauses) {
            if (matches) break;
            matches = await _caseMatchesAsync(cl, subject);
          }
          if (matches) return _block(c.body);
        }
      case ForStmt():
        return _for(s);
      case ForEachStmt():
        return _forEach(s);
      case DoLoopStmt():
        return _doLoop(s);
      case TryStmt():
        return _try(s);
      case ReturnStmt():
        if (s.value != null) _frame.result = await _value(s.value!);
        return _Flow.exitProcedure;
      case ThrowStmt():
        throw _Thrown((await _value(s.value))! as GbException, s, _frame.form);
      case ReDimStmt():
        _reDim(s, await _value(s.bound));
      default:
        return _statementSync(s);
    }
    return _Flow.normal;
  }

  _Flow _exitFlow(ExitStmt s) => switch (s.kind) {
        Keyword.kwFor => _Flow.exitFor,
        Keyword.kwDo => _Flow.exitDo,
        _ => _Flow.exitProcedure,
      };

  void _declareSync(LocalDeclStmt s) {
    final symbol = _a.symbols[s.declarator.name];
    if (symbol == null) return;
    if (s.kind == Keyword.kwStatic && _statics.containsKey(symbol)) return;
    final d = s.declarator;
    final Object? value;
    if (d.initializer != null) {
      value = _valueSync(d.initializer!);
    } else if (d.isArray) {
      value = d.arrayBound == null
          ? null
          : _newArray(symbol.type, _valueSync(d.arrayBound!), d);
    } else if (d.isNew) {
      value = _construct(symbol.type,
          [for (final a in d.newArguments ?? const <Expr>[]) _valueSync(a)]);
    } else {
      value = defaultValue(symbol.type);
    }
    _write(symbol, value);
  }

  Future<void> _declare(LocalDeclStmt s) async {
    final symbol = _a.symbols[s.declarator.name];
    if (symbol == null) return;
    if (s.kind == Keyword.kwStatic && _statics.containsKey(symbol)) return;
    _write(symbol, await _initialValue(s.declarator, symbol));
  }

  Future<_Flow> _for(ForStmt s) async {
    final variable = _a.loopVariables[s]!;
    final from = await _value(s.from);
    final to = await _value(s.to);
    final step = s.step == null ? null : await _value(s.step!);
    final isInteger = variable.type == GbType.integer;
    final stepValue = step ?? (isInteger ? GbInt.one : 1.0);
    final ascending = isInteger
        ? !(stepValue as GbInt).isNegative
        : (stepValue as double) >= 0;
    _write(variable, from);
    while (true) {
      final current = _read(variable);
      final cmp = _compareNumbers(current, to);
      if (ascending ? cmp > 0 : cmp < 0) break;
      final run = _body(s.body);
      final flow = run is Future<_Flow> ? await run : run;
      if (flow == _Flow.exitFor) break;
      if (flow != _Flow.normal) return flow;
      if (_tick()) await _yield();
      final now = _read(variable);
      if (isInteger) {
        final next = (now as GbInt) + (stepValue as GbInt);
        if (next == null) _fail(DiagnosticCode.integerOverflow, s.variable);
        _write(variable, next);
      } else {
        _write(variable, (now as double) + (stepValue as double));
      }
    }
    return _Flow.normal;
  }

  Future<_Flow> _forEach(ForEachStmt s) async {
    final variable = _a.loopVariables[s]!;
    final collection = await _value(s.collection);
    final List<Object?> items = switch (collection) {
      GbList l => List.of(l.items), // a snapshot: changes do not disturb
      GbArray a => List.of(a.items),
      GbControls c => List.of(c.items),
      null => _fail(DiagnosticCode.nothingReference, s.collection),
      _ => _fail(DiagnosticCode.memberNotFound, s.collection,
          ['For Each', typeNameOf(collection)]),
    };
    for (final item in items) {
      _write(variable, item);
      final run = _body(s.body);
      final flow = run is Future<_Flow> ? await run : run;
      if (flow == _Flow.exitFor) break;
      if (flow != _Flow.normal) return flow;
      if (_tick()) await _yield();
    }
    return _Flow.normal;
  }

  Future<_Flow> _doLoop(DoLoopStmt s) async {
    FutureOr<bool> keepGoing(LoopCondition? c) {
      if (c == null) return true;
      bool decide(Object? v) => c.isUntil ? !(v as bool) : v as bool;
      final value = _value(c.condition);
      return value is Future<Object?> ? value.then(decide) : decide(value);
    }

    while (true) {
      final pre = keepGoing(s.preCondition);
      if (!(pre is Future<bool> ? await pre : pre)) break;
      final run = _body(s.body);
      final flow = run is Future<_Flow> ? await run : run;
      if (flow == _Flow.exitDo) break;
      if (flow != _Flow.normal) return flow;
      if (_tick()) await _yield();
      final post = keepGoing(s.postCondition);
      if (!(post is Future<bool> ? await post : post)) break;
    }
    return _Flow.normal;
  }

  Future<_Flow> _try(TryStmt s) async {
    try {
      return await _block(s.body);
    } on _Thrown catch (t) {
      if (s.catches.isEmpty) rethrow;
      return _catch(s, t.exception);
    } on _Failure catch (f) {
      if (s.catches.isEmpty) rethrow;
      // A run-time error caught by Try: its message, in the language of
      // the run (I3).
      final d = _diagnostic(f.code, f.node, f.args, f.form);
      return _catch(s, GbException(d.formatMessage(messages)));
    } finally {
      if (s.finallyBlock != null) {
        // A Finally block cannot leave the procedure early.
        await _block(s.finallyBlock!);
      }
    }
  }

  Future<_Flow> _catch(TryStmt s, GbException exception) async {
    final c = s.catches.first;
    if (c.name != null) {
      final symbol = _a.symbols[c.name!];
      if (symbol != null) _write(symbol, exception);
    }
    return _block(c.body);
  }

  void _reDim(ReDimStmt s, Object? bound) {
    final symbol = _a.symbols[s.name]!;
    final old = _read(symbol);
    final fresh = _newArray(symbol.type, bound, s);
    if (s.preserve && old is GbArray) {
      for (var i = 0; i < fresh.items.length && i < old.items.length; i++) {
        fresh.items[i] = old.items[i];
      }
    }
    _write(symbol, fresh);
  }

  bool _caseMatches(
      CaseClause clause, Object? subject, Object? Function(Expr) eval) {
    return switch (clause) {
      ValueClause(:final value) => valuesEqual(subject, eval(value)),
      RangeClause(:final low, :final high) =>
        _compare(subject, eval(low), clause) >= 0 &&
            _compare(subject, eval(high), clause) <= 0,
      RelationalClause(:final operator, :final value) =>
        _relation(operator, subject, eval(value), clause),
    };
  }

  Future<bool> _caseMatchesAsync(CaseClause clause, Object? subject) async =>
      switch (clause) {
        ValueClause(:final value) => valuesEqual(subject, await _value(value)),
        RangeClause(:final low, :final high) =>
          _compare(subject, await _value(low), clause) >= 0 &&
              _compare(subject, await _value(high), clause) <= 0,
        RelationalClause(:final operator, :final value) =>
          _relation(operator, subject, await _value(value), clause),
      };

  // -------------------------------------------------------------------------
  // Assignment

  /// The item number of an item target (`a(i) = …`), evaluated before the
  /// assignment; null for other targets.
  Object? _indexSync(Expr target) =>
      target is InvokeExpr && target.arguments.isNotEmpty
          ? _valueSync(target.arguments.first)
          : null;

  Future<Object?> _indexAsync(Expr target) async =>
      target is InvokeExpr && target.arguments.isNotEmpty
          ? await _value(target.arguments.first)
          : null;

  /// `AddHandler`: [procedure] handles the event of [target] from now on
  /// (D98); an event has one handler.
  void _addHandler(AddHandlerStmt s, Object? target) {
    if (target is! GbControl) {
      _fail(
          target == null
              ? DiagnosticCode.nothingReference
              : DiagnosticCode.memberNotFound,
          s.event,
          [s.event.name.name, typeNameOf(target)]);
    }
    final event = target.component.events[s.event.name.name.toLowerCase()]!;
    final handler = _canon(_a.symbols[s.procedure]!).procedure!;
    final key = event.name.toLowerCase();
    final existing = target.handlers[key] as ProcedureDecl?;
    if (existing != null && existing != handler) {
      _fail(DiagnosticCode.eventAlreadyHandled, s,
          ['$target.${event.name}', existing.name.name]);
    }
    target.handlers[key] = handler;
  }

  /// Assigns [value]. Returns the handler of a change event the
  /// assignment has to run (TextBox.Text -> txtName_Changed), if any.
  _Change? _assign(Expr target, Object? value, Object? Function(Expr) index) {
    switch (target) {
      case NameExpr():
        _write(_a.symbols[target]!, value);
      case InvokeExpr():
        final container = _evalSync(target.target);
        _setItem(container, index(target), value, target);
      case MemberExpr():
        final receiver = _evalSync(target.target);
        if (receiver is GbControl) {
          return _setProperty(receiver, target, value);
        }
        if (receiver is GbModule) {
          // `Module1.Total = 5` (D102).
          final symbol = _modules[receiver.name.toLowerCase()]!
              .code!
              .analysis
              .fileScope
              .symbols[target.name.name.toLowerCase()];
          if (symbol == null ||
              symbol.storage != Storage.field ||
              symbol.kind == SymbolKind.constant) {
            _fail(DiagnosticCode.memberNotFound, target,
                [target.name.name, receiver.name]);
          }
          _fields[symbol] = value;
          return null;
        }
        _fail(
            receiver == null
                ? DiagnosticCode.nothingReference
                : DiagnosticCode.memberNotFound,
            target,
            [target.name.name, typeNameOf(receiver)]);
      default:
        throw StateError('not assignable: $target');
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Controls (docs/LANGUAGE.md §11)

  PropertySpec _property(GbControl c, MemberExpr e) =>
      switch (c.component.properties[e.name.name.toLowerCase()]) {
        final p? when !p.internal => p,
        _ => _fail(
            DiagnosticCode.memberNotFound, e, [e.name.name, c.component.name]),
      };

  /// A stored property of [c]: from the host while it is on a form, from
  /// itself while it is not (D98).
  Object _raw(GbControl c, String property) => c.attached
      ? _formHost.getProperty(c.form, c.name, property)
      : c.pending[property]!;

  void _rawSet(GbControl c, String property, Object value) {
    if (c.attached) {
      _formHost.setProperty(c.form, c.name, property, value);
    } else {
      c.pending[property] = value;
    }
  }

  Object? _getProperty(GbControl c, MemberExpr e) {
    final spec = _property(c, e);
    final value =
        spec.readOnly ? _computedProperty(c, spec) : _raw(c, spec.name);
    if (spec.type == GbType.integer) return GbInt.of(value as int);
    if (spec.type == GbType.double_) return (value as num).toDouble();
    return value;
  }

  /// Sets a property; returns the handler of its change event if the value
  /// changed and the handler is not already running (D5).
  _Change? _setProperty(GbControl c, MemberExpr e, Object? value) {
    final name = e.name.name.toLowerCase();
    if (name == 'name' && !c.component.properties.containsKey(name)) {
      _setName(c, value, e);
      return null;
    }
    if (c.isForm && !c.component.properties.containsKey(name)) {
      // `Form2.Score = 5`: a variable of another form (D88).
      final symbol = _formSymbol(_formNamed(c.form)!, name);
      if (symbol == null ||
          symbol.storage != Storage.field ||
          symbol.kind == SymbolKind.constant) {
        _fail(DiagnosticCode.memberNotFound, e, [e.name.name, c.form]);
      }
      _fields[symbol] = value;
      return null;
    }
    final spec = _property(c, e);
    if (spec.readOnly) {
      // Only through an Object: the analyzer reports it otherwise (A034).
      _fail(DiagnosticCode.memberNotFound, e, [e.name.name, c.component.name]);
    }
    var v = _propertyValue(spec, value, e);
    if (spec.anchor && v is String) {
      v = normalAnchor(v) ?? _fail(DiagnosticCode.badAnchorValue, e, [v]);
    }
    if (spec.shortcut && v is String) {
      v = normalShortcut(v) ?? _fail(DiagnosticCode.badShortcutValue, e, [v]);
    }
    if (spec.picture && v is String && v.isNotEmpty) {
      // Any case names the picture; the property keeps the project's
      // spelling (D51).
      v = _a.pictures?[pictureKey(v)] ??
          _fail(DiagnosticCode.pictureNotFound, e, [v]);
    }
    if (_isList(c) && spec.name == 'ListIndex') {
      final count = _items(c).length;
      if ((v as int) >= count) {
        _fail(DiagnosticCode.indexOutOfRange, e, ['$v', '$count']);
      }
    }
    final old = _raw(c, spec.name);
    _rawSet(c, spec.name, v);
    if (c.component.name == 'OptionButton' && spec.name == 'Checked') {
      // One of a group is checked; Changed runs only for the one that
      // becomes checked (D104).
      if (v != true) return null;
      for (final other in _optionGroup(c)) {
        if (other != c && _raw(other, 'Checked') == true) {
          _rawSet(other, 'Checked', false);
        }
      }
    }
    if (c.isForm && spec.name == 'DialogResult' && v != 0) {
      // Set while it is shown as a dialog, it closes it (D103).
      final form = _formNamed(c.form)!;
      if (_shownAsDialog.contains(form)) {
        _pendingCall = () async {
          await _close(form);
          return null;
        };
      }
    }
    final event = spec.changeEvent;
    if (event == null || old == v) return null;
    return _changeOf(c, event);
  }

  /// The handler of [c]'s change event [event] to run now, unless it has
  /// none or it is running (D5).
  _Change? _changeOf(GbControl c, String event) {
    final handler = c.handlers[event.toLowerCase()] as ProcedureDecl?;
    return handler == null || _running.contains(handler)
        ? null
        : (handler: handler, control: c);
  }

  /// The OptionButtons of [c]'s group: those on its form (D104); none for
  /// one on no form.
  Iterable<GbControl> _optionGroup(GbControl c) => !c.attached
      ? const []
      : _formNamed(c.form)!.order.where((o) =>
          o.component.name == 'OptionButton' &&
          // The OptionButtons of a Frame are a group of their own
          // (D105).
          o.container?.toLowerCase() == c.container?.toLowerCase());

  /// `c.Name = value`: only a control made with New that is on no form
  /// yet takes a Name (D98).
  void _setName(GbControl c, Object? value, MemberExpr at) {
    if (c.isForm || c.attached) {
      _fail(DiagnosticCode.nameOfControlOnForm, at, ['$c']);
    }
    final name = value is String
        ? value
        : _fail(DiagnosticCode.conversionFailed, at,
            [formatValue(value), 'String']);
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(name)) {
      _fail(DiagnosticCode.badControlName, at, [name]);
    }
    c.name = name;
  }

  /// `Me.Controls`: the controls on [form] (D98).
  GbControls _controlsOf(_FormRun form) => GbControls(form.name, form.order);

  /// `Controls.Add`, `Controls.Remove` and `Controls.Count` (D98).
  Object? _controlsMember(
      GbControls cs, String name, List<Object?> args, Node at, MemberExpr e) {
    final form = _formNamed(cs.form)!;
    switch (name) {
      case 'count':
        return GbInt.of(cs.items.length);
      case 'add':
        _addControl(form, args[0], at);
        return null;
      case 'remove':
        _removeControl(form, args[0], at);
        return null;
    }
    _fail(DiagnosticCode.memberNotFound, at, [e.name.name, 'Controls']);
  }

  /// Puts [value], a control made with New or taken off a form, on [form],
  /// on top of the others of its layer; it gets a name like `Button1` when
  /// it has none.
  void _addControl(_FormRun form, Object? value, Node at) {
    final c = value as GbControl? ?? _fail(DiagnosticCode.nothingReference, at);
    if (c.attached) {
      _fail(DiagnosticCode.controlAlreadyOnForm, at, ['$c', c.form]);
    }
    final name = c.name ?? _freeName(form, c.component);
    if (form.controls.containsKey(name.toLowerCase())) {
      _fail(DiagnosticCode.controlNameTaken, at, [name, form.name]);
    }
    c
      ..name = name
      ..form = form.name
      ..attached = true;
    _formHost.addControl(form.name, name, c.component.name, Map.of(c.pending));
    c.pending.clear();
    form.controls[name.toLowerCase()] = c;
    form.order.add(c);
  }

  /// The component's name and the smallest number from 1 that no control
  /// of [form] has, nor had in its form file: `Button1`.
  String _freeName(_FormRun form, ComponentSpec component) {
    for (var n = 1;; n++) {
      final name = '${component.name}$n';
      final lower = name.toLowerCase();
      if (!form.controls.containsKey(lower) &&
          !form.designed.containsKey(lower)) {
        return name;
      }
    }
  }

  /// Takes [value] off [form]; it keeps its name and properties, and can
  /// be added again.
  void _removeControl(_FormRun form, Object? value, Node at) {
    final c = value as GbControl? ?? _fail(DiagnosticCode.nothingReference, at);
    if (!c.attached ||
        c.isForm ||
        c.form.toLowerCase() != form.name.toLowerCase()) {
      _fail(DiagnosticCode.controlNotOnForm, at, ['$c', form.name]);
    }
    final lower = c.name!.toLowerCase();
    if (form.order.any((o) => o.container?.toLowerCase() == lower)) {
      _fail(DiagnosticCode.frameNotEmpty, at, ['$c']);
    }
    for (final p in c.component.properties.values) {
      if (p.isStored) {
        c.pending[p.name] = _formHost.getProperty(form.name, c.name, p.name);
      }
    }
    _formHost.removeControl(form.name, c.name!);
    form.controls.remove(c.name!.toLowerCase());
    form.order.remove(c);
    // Added again, it is on the form itself (D105).
    c
      ..attached = false
      ..container = null;
  }

  /// `TypeOf value Is T` (D98).
  bool _isOfType(Object? value, Expr e) {
    final target = _a.castTypes[e]!;
    return value is GbControl &&
        !value.isForm &&
        (target.component == controlComponent ||
            value.component == target.component);
  }

  /// `CType(value, T)` (D98): the same control, which must be a [T].
  Object? _castTo(Object? value, Expr e) {
    if (value == null || _isOfType(value, e)) return value;
    _fail(DiagnosticCode.castFailed, e,
        [typeNameOf(value), _a.castTypes[e]!.displayName]);
  }

  /// [value] as the host stores it. Through an Object variable the
  /// analyzer could not check the type, so it is checked here.
  Object _propertyValue(PropertySpec spec, Object? value, MemberExpr at) {
    switch (spec.type) {
      case GbType.integer:
        if (!isGbInt(value)) break;
        final n = (value as GbInt).toSmallInt();
        if (n == null || !spec.accepts(n)) {
          _fail(DiagnosticCode.propertyValueOutOfRange, at,
              [spec.name, '${spec.min}', '${spec.max}']);
        }
        return n;
      case GbType.double_:
        if (isGbInt(value)) return (value as GbInt).toDouble();
        if (isGbDouble(value)) return (value as num).toDouble();
      case GbType.boolean:
        if (value is bool) return value;
      default: // String
        if (value is String) return value;
        if (value != null &&
            (isGbInt(value) ||
                isGbDouble(value) ||
                value is bool ||
                value is DateTime)) {
          return formatValue(value);
        }
    }
    _fail(DiagnosticCode.conversionFailed, at,
        [formatValue(value), spec.type.displayName]);
  }

  /// A [PropertySpec.readOnly] property, worked out by the component's
  /// code: ListBox's ListCount and Text.
  Object _computedProperty(GbControl c, PropertySpec spec) =>
      switch ((_isList(c) ? 'ListBox' : c.component.name, spec.name)) {
        ('ListBox', 'ListCount') => _items(c).length,
        ('ListBox', 'Text') => switch (_listIndex(c)) {
            -1 => '',
            final i => _items(c)[i],
          },
        _ => throw StateError('no code for ${c.component.name}.${spec.name}'),
      };

  /// Whether [c] is a list of items: a ListBox, or a ComboBox (D104).
  static bool _isList(GbControl c) =>
      c.component.name == 'ListBox' || c.component.name == 'ComboBox';

  /// The change event a control's method left to run, if any.
  _Change? _pendingChange;

  List<String> _items(GbControl c) => _raw(c, 'Items') as List<String>;
  int _listIndex(GbControl c) => _raw(c, 'ListIndex') as int;

  /// A member of form [c] that is not its component's (D88): one of its
  /// controls, a variable or a procedure of its code. A procedure is
  /// called through [_pendingCall].
  Object? _formMember(
      GbControl c, String name, List<Object?> args, Node at, MemberExpr e) {
    final form = _formNamed(c.form)!;
    final control = form.designed[name];
    if (args.isEmpty && control != null) return control;
    final symbol = _formSymbol(form, name);
    if (symbol != null && symbol.storage == Storage.field && args.isEmpty) {
      return _fields[symbol];
    }
    if (symbol?.procedure case final p?) {
      _pendingCall = () => _callUser(p, args, at);
      return null;
    }
    _fail(DiagnosticCode.memberNotFound, at, [e.name.name, c.form]);
  }

  /// `Module1.Total`, `Module1.Start()` (D102): a variable of the module,
  /// or a procedure, called through [_pendingCall].
  Object? _moduleMember(
      GbModule m, String name, List<Object?> args, Node at, MemberExpr e) {
    final symbol =
        _modules[m.name.toLowerCase()]!.code!.analysis.fileScope.symbols[name];
    if (symbol != null && symbol.storage == Storage.field && args.isEmpty) {
      return _fields[symbol];
    }
    if (symbol?.procedure case final p?) {
      _pendingCall = () => _callUser(p, args, at);
      return null;
    }
    _fail(DiagnosticCode.memberNotFound, at, [e.name.name, m.name]);
  }

  /// The name [name] (lower case) declared in [form]'s code outside
  /// procedures, or null.
  Symbol? _formSymbol(_FormRun form, String name) =>
      form.program?.program.analysis.fileScope.symbols[name];

  /// A call that has to wait, left by a form's method or a call to a
  /// procedure of a form (D88); [_afterChange] makes it.
  Future<Object?> Function()? _pendingCall;

  /// Calls a method of a control (docs/DESIGN.md D45). The ListBox's
  /// methods change its items and, when the chosen item moves or goes,
  /// ListIndex, whose Changed then runs as part of the call (D46).
  Object? _controlMethod(
      GbControl c, MethodSpec method, List<Object?> args, Node at) {
    // A ComboBox's items are a ListBox's (D104).
    switch ((_isList(c) ? 'ListBox' : c.component.name, method.name)) {
      // The forms shown one over another (D88).
      case ('Form', 'Show'):
        final form = _formNamed(c.form)!;
        _pendingCall = () async {
          await _show(form);
          return null;
        };
        return null;
      case ('Form', 'ShowDialog'):
        final form = _formNamed(c.form)!;
        _pendingCall = () async => GbInt.of(await _showDialog(form, at));
        return null;
      case ('Form', 'Hide'):
        _hide(_formNamed(c.form)!);
        return null;
      case ('Form', 'Close'):
        final form = _formNamed(c.form)!;
        _pendingCall = () async {
          await _close(form);
          return null;
        };
        return null;
      case ('Form', 'PopupMenu'):
        final form = _formNamed(c.form)!;
        final menu =
            args[0] as GbControl? ?? _fail(DiagnosticCode.nothingReference, at);
        if (menu.form.toLowerCase() != form.name.toLowerCase()) {
          _fail(DiagnosticCode.popupOfOtherForm, at,
              ['$menu', menu.form, form.name]);
        }
        if (!form.controls.values.any(
            (m) => m.container?.toLowerCase() == menu.name!.toLowerCase())) {
          _fail(DiagnosticCode.popupWithoutItems, at, ['$menu']);
        }
        _pendingCall = () async {
          await _popupMenu(form, menu);
          return null;
        };
        return null;
      case ('Timer', 'Start'):
        _rawSet(c, 'Enabled', true);
        return null;
      case ('Timer', 'Stop'):
        _rawSet(c, 'Enabled', false);
        return null;
      case ('ListBox', 'AddItem'):
        _rawSet(c, 'Items',
            List<String>.unmodifiable([..._items(c), args[0] as String]));
        return null;
      case ('ListBox', 'RemoveItem'):
        final items = [..._items(c)];
        final i = _itemIndex(items, args[0], at);
        items.removeAt(i);
        _rawSet(c, 'Items', List<String>.unmodifiable(items));
        final chosen = _listIndex(c);
        _changeListIndex(
            c,
            i == chosen
                ? -1
                : i < chosen
                    ? chosen - 1
                    : chosen);
        return null;
      case ('ListBox', 'Clear'):
        _rawSet(c, 'Items', const <String>[]);
        _changeListIndex(c, -1);
        return null;
      case ('ListBox', 'List'):
        final items = _items(c);
        return items[_itemIndex(items, args[0], at)];
    }
    throw StateError('no code for ${c.component.name}.${method.name}');
  }

  /// `PopupMenu` (D106): waits, as for a MsgBox, until the user chooses
  /// one of [menu]'s items or none; the chosen item's Click then runs
  /// before PopupMenu returns, unless it is running already (D5).
  Future<void> _popupMenu(_FormRun form, GbControl menu) async {
    final chosen = await _dialog(_formHost.popupMenu(form.name, menu.name!));
    if (chosen is! String) return;
    final item = form.controls[chosen.toLowerCase()];
    final handler = _handler(form, chosen, 'Click');
    if (item == null || handler == null || _running.contains(handler)) {
      return;
    }
    await _runNow(handler, item);
  }

  /// Sets a ListBox's ListIndex to [index] if it differs; its Changed is
  /// then left to run ([_pendingChange]).
  void _changeListIndex(GbControl c, int index) {
    if (_listIndex(c) == index) return;
    _rawSet(c, 'ListIndex', index);
    _pendingChange = _changeOf(c, 'Changed');
  }

  /// Runs [handler] at once, as part of what the running code does: a
  /// change event (docs/LANGUAGE.md §11.1), or a form's Load, Resize or
  /// Closed when the code shows or closes it (D88). [sender] is the
  /// control or form whose event it is.
  Future<void> _runNow(ProcedureDecl handler, GbControl? sender) async {
    _running.add(handler);
    try {
      await _callUser(handler, _senderArgs(handler, sender), handler);
    } finally {
      _running.remove(handler);
    }
  }

  // -------------------------------------------------------------------------
  // Expressions

  /// [e]'s value after the automatic conversion the analyzer recorded.
  FutureOr<Object?> _value(Expr e) {
    final raw = _eval(e);
    return raw is Future<Object?>
        ? raw.then((v) => _convert(e, v))
        : _convert(e, raw);
  }

  Object? _valueSync(Expr e) => _convert(e, _evalSync(e));

  Object? _convert(Expr e, Object? value) {
    final target = _a.conversions[e];
    if (target == null) return value;
    if (target == GbType.double_ && isGbInt(value)) {
      return (value as GbInt).toDouble();
    }
    if (target == GbType.string && value is! String) return formatValue(value);
    return value;
  }

  FutureOr<Object?> _eval(Expr e) => _awaits(e) ? _evalAsync(e) : _evalSync(e);

  Object? _evalSync(Expr e) {
    switch (e) {
      case IntegerLiteral():
        return GbInt.parse(e.text);
      case DoubleLiteral():
        return e.value;
      case StringLiteral():
        return e.value;
      case BooleanLiteral():
        return e.value;
      case NothingLiteral():
        return null;
      case NameExpr():
        final symbol = _a.symbols[e]!;
        if (_a.implicitCalls.contains(e)) {
          return _callBuiltinSync(symbol.callable!, const [], e);
        }
        return _read(symbol);
      case MemberExpr():
        return _noChange(_member(e, _memberReceiverSync(e), const []));
      case InvokeExpr():
        final args = [for (final a in e.arguments) _valueSync(a)];
        return _noChange(_invoke(e, args, _memberReceiverSync));
      case NewExpr():
        return _construct(_a.types[e] ?? GbType.unknown,
            [for (final a in e.arguments ?? const <Expr>[]) _valueSync(a)]);
      case UnaryExpr():
        return _unary(e, _valueSync(e.operand));
      case BinaryExpr():
        final op = e.operator;
        final left = _valueSync(e.left);
        if (op == BinaryOp.and && left == false) return false;
        if (op == BinaryOp.or && left == true) return true;
        return _binary(e, left, _valueSync(e.right));
      case ParenExpr():
        return _valueSync(e.inner);
      case MeExpr():
        return _frame.form.controls[null];
      case TypeOfExpr():
        return _isOfType(_valueSync(e.operand), e);
      case CastExpr():
        return _castTo(_valueSync(e.operand), e);
      case ErrorExpr():
        throw StateError('not runnable: $e'); // analyzer reported it
    }
  }

  Future<Object?> _evalAsync(Expr e) async {
    switch (e) {
      case NameExpr():
        final symbol = _a.symbols[e]!;
        return _callNamed(symbol, const [], e);
      case MemberExpr():
        final receiver = await _memberReceiverAsync(e);
        return _afterChange(_member(e, receiver, const []));
      case InvokeExpr():
        final args = [for (final a in e.arguments) await _value(a)];
        final target = e.target;
        if (_a.invokeKinds[e] == InvokeKind.call && target is NameExpr) {
          return _callNamed(_a.symbols[target]!, args, e);
        }
        final receiver =
            target is MemberExpr ? await _memberReceiverAsync(target) : null;
        return _afterChange(_invoke(e, args, (_) => receiver,
            container: target is MemberExpr ? null : await _value(target)));
      case NewExpr():
        return _construct(_a.types[e] ?? GbType.unknown,
            [for (final a in e.arguments ?? const <Expr>[]) await _value(a)]);
      case UnaryExpr():
        return _unary(e, await _value(e.operand));
      case BinaryExpr():
        final op = e.operator;
        final left = await _value(e.left);
        if (op == BinaryOp.and && left == false) return false;
        if (op == BinaryOp.or && left == true) return true;
        return _binary(e, left, await _value(e.right));
      case ParenExpr():
        return _value(e.inner);
      case TypeOfExpr():
        return _isOfType(await _value(e.operand), e);
      case CastExpr():
        return _castTo(await _value(e.operand), e);
      default:
        return _evalSync(e);
    }
  }

  /// [value], after running the change event a control's method left to
  /// run (ListBox.Clear -> Changed), as part of the call.
  Future<Object?> _afterChange(Object? value) async {
    final call = _pendingCall;
    if (call != null) {
      _pendingCall = null;
      value = await call();
    }
    final change = _pendingChange;
    if (change != null) {
      _pendingChange = null;
      await _runNow(change.handler, change.control);
    }
    return value;
  }

  /// [value]; a method that runs a change event is always called through
  /// [_evalAsync] ([_methodMayRunEvent]).
  Object? _noChange(Object? value) {
    if (_pendingChange != null || _pendingCall != null) {
      throw StateError('a change event is always run asynchronously');
    }
    return value;
  }

  /// Calls a user procedure or built-in function by its symbol.
  Future<Object?> _callNamed(Symbol named, List<Object?> args, Node at) {
    final symbol = _canon(named);
    if (symbol.kind == SymbolKind.procedure) {
      return _callUser(symbol.procedure!, args, at);
    }
    return Future.value(_callBuiltin(symbol.callable!, args, at));
  }

  Object? _memberReceiverSync(Expr target) {
    final t = target is MemberExpr ? target.target : target;
    if (t is NameExpr && _a.symbols[t]?.kind == SymbolKind.builtinObject) {
      return _BuiltinObject(_a.symbols[t]!.name);
    }
    return _valueSync(t);
  }

  Future<Object?> _memberReceiverAsync(Expr target) async {
    final t = target is MemberExpr ? target.target : target;
    if (t is NameExpr && _a.symbols[t]?.kind == SymbolKind.builtinObject) {
      return _BuiltinObject(_a.symbols[t]!.name);
    }
    return _value(t);
  }

  /// `target(args)`: a call or an item.
  Object? _invoke(
      InvokeExpr e, List<Object?> args, Object? Function(Expr) receiverOf,
      {Object? container}) {
    final target = e.target;
    final kind = _a.invokeKinds[e];
    if (kind == InvokeKind.call) {
      if (target is NameExpr) {
        return _callBuiltinSync(_a.symbols[target]!.callable!, args, e);
      }
      if (target is MemberExpr) {
        return _member(target, receiverOf(target), args, at: e);
      }
    }
    // Through an Object, whether it is a call is decided here.
    if (kind != InvokeKind.item && target is MemberExpr) {
      final receiver = receiverOf(target);
      if (_isMethod(receiver, target.name.name.toLowerCase())) {
        return _member(target, receiver, args, at: e);
      }
    }
    // An item, decided by the analyzer or (through Object) at run time.
    final c = container ??
        (target is MemberExpr
            ? _member(target, receiverOf(target), const [])
            : _evalSync(target));
    return _getItem(c, args.isEmpty ? null : args.first, e);
  }

  /// Whether [name] (lower case) is a method of [receiver]: what decides,
  /// through an Object, between `o.Add(3)` and `o.Items(3)`.
  bool _isMethod(Object? receiver, String name) => switch (receiver) {
        GbList() =>
          membersOf(const ListType(GbType.object))?[name]?.isMethod == true,
        String() => membersOf(GbType.string)?[name]?.isMethod == true,
        GbControl c => c.component.methods.containsKey(name) ||
            (c.isForm &&
                _formSymbol(_formNamed(c.form)!, name)?.procedure != null),
        GbControls() => name == 'add' || name == 'remove',
        GbModule m => _modules[m.name.toLowerCase()]!
                .code!
                .analysis
                .fileScope
                .symbols[name]
                ?.procedure !=
            null,
        _ => false,
      };

  int _itemIndex(List<Object?> items, Object? index, Node at) {
    final i = (index as GbInt).toSmallInt();
    if (i == null || i < 0 || i >= items.length) {
      _fail(DiagnosticCode.indexOutOfRange, at,
          [index.format(), '${items.length}']);
    }
    return i;
  }

  Object? _getItem(Object? container, Object? index, Node at) =>
      switch (container) {
        GbList l => l.items[_itemIndex(l.items, index, at)],
        GbArray a => a.items[_itemIndex(a.items, index, at)],
        GbControls c => c.items[_itemIndex(c.items, index, at)],
        null => _fail(DiagnosticCode.nothingReference, at),
        _ => _fail(DiagnosticCode.memberNotFound, at,
            ['(item)', typeNameOf(container)]),
      };

  void _setItem(Object? container, Object? index, Object? value, Node at) {
    switch (container) {
      case GbList l:
        l.items[_itemIndex(l.items, index, at)] = value;
      case GbArray a:
        a.items[_itemIndex(a.items, index, at)] = value;
      case null:
        _fail(DiagnosticCode.nothingReference, at);
      default:
        _fail(DiagnosticCode.memberNotFound, at,
            ['(item)', typeNameOf(container)]);
    }
  }

  Object? _unary(UnaryExpr e, Object? v) {
    switch (e.operator) {
      case UnaryOp.not:
        return !(v as bool);
      case UnaryOp.plus:
        return v;
      case UnaryOp.negate:
        if (isGbInt(v)) {
          return (v as GbInt).negate() ??
              _fail(DiagnosticCode.integerOverflow, e);
        }
        return -(v as double);
    }
  }

  Object? _binary(BinaryExpr e, Object? l, Object? r) {
    switch (e.operator) {
      case BinaryOp.and:
        return (l as bool) && (r as bool);
      case BinaryOp.or:
        return (l as bool) || (r as bool);
      case BinaryOp.xor:
        return (l as bool) != (r as bool);
      case BinaryOp.concat:
        return formatValue(l) + formatValue(r);
      case BinaryOp.identity:
        return identical(l, r) || (l == null && r == null);
      case BinaryOp.equal ||
            BinaryOp.notEqual ||
            BinaryOp.less ||
            BinaryOp.greater ||
            BinaryOp.lessEqual ||
            BinaryOp.greaterEqual:
        return _relation(e.operator, l, r, e);
      default:
    }
    if (l is String && r is String) return l + r; // + on two Strings
    if (isGbInt(l) && isGbInt(r)) return _integerOp(e, l as GbInt, r as GbInt);
    final a = toDoubleValue(l), b = toDoubleValue(r);
    switch (e.operator) {
      case BinaryOp.add:
        return a + b;
      case BinaryOp.subtract:
        return a - b;
      case BinaryOp.multiply:
        return a * b;
      case BinaryOp.divide:
        if (b == 0) _fail(DiagnosticCode.divisionByZero, e);
        return a / b;
      case BinaryOp.power:
        return math.pow(a, b).toDouble();
      case BinaryOp.modulo:
        if (b == 0) _fail(DiagnosticCode.divisionByZero, e);
        return a.remainder(b);
      default:
        throw StateError('operator ${e.operator} on $l, $r');
    }
  }

  Object? _integerOp(BinaryExpr e, GbInt a, GbInt b) {
    final GbInt? result;
    switch (e.operator) {
      case BinaryOp.add:
        result = a + b;
      case BinaryOp.subtract:
        result = a - b;
      case BinaryOp.multiply:
        result = a * b;
      case BinaryOp.integerDivide:
        if (b.isZero) _fail(DiagnosticCode.divisionByZero, e);
        result = a.quotient(b);
      case BinaryOp.modulo:
        if (b.isZero) _fail(DiagnosticCode.divisionByZero, e);
        result = a.remainder(b);
      default:
        throw StateError('integer operator ${e.operator}');
    }
    return result ?? _fail(DiagnosticCode.integerOverflow, e);
  }

  bool _relation(BinaryOp op, Object? l, Object? r, Node at) {
    if (op == BinaryOp.equal) return valuesEqual(l, r);
    if (op == BinaryOp.notEqual) return !valuesEqual(l, r);
    final c = _compare(l, r, at);
    return switch (op) {
      BinaryOp.less => c < 0,
      BinaryOp.greater => c > 0,
      BinaryOp.lessEqual => c <= 0,
      BinaryOp.greaterEqual => c >= 0,
      _ => throw StateError('$op'),
    };
  }

  int _compare(Object? l, Object? r, Node at) {
    if (l is String && r is String) return l.compareTo(r);
    if (l is DateTime && r is DateTime) return l.compareTo(r);
    return _compareNumbers(l, r);
  }

  int _compareNumbers(Object? l, Object? r) {
    if (isGbInt(l) && isGbInt(r)) return (l as GbInt).compareTo(r as GbInt);
    return toDoubleValue(l).compareTo(toDoubleValue(r));
  }

  // -------------------------------------------------------------------------
  // Members of built-in types and objects

  Object? _member(MemberExpr e, Object? receiver, List<Object?> args,
      {Node? at}) {
    final name = e.name.name.toLowerCase();
    final node = at ?? e;
    switch (receiver) {
      case _BuiltinObject(name: 'Debug'):
        host.debugPrint(formatValue(args.first));
        return null;
      case _BuiltinObject(name: 'Integer'):
        return name == 'maxvalue' ? GbInt.maxValue : GbInt.minValue;
      case _BuiltinObject(name: 'Keys'):
        return GbInt.of(keyCodesByLowerName[name]!.$2);
      case _BuiltinObject(name: 'MouseButtons'):
        return GbInt.of(mouseButtons.entries
            .firstWhere((e) => e.key.toLowerCase() == name)
            .value);
      case GbMouseEvent m:
        return GbInt.of(switch (name) {
          'button' => m.button,
          'x' => m.x,
          _ => m.y,
        });
      case _BuiltinObject(name: 'DialogResult'):
        return GbInt.of(dialogResults.entries
            .firstWhere((e) => e.key.toLowerCase() == name)
            .value);
      case GbKeyEvent k:
        switch (name) {
          case 'keycode':
            return GbInt.of(k.keyCode);
          case 'shift':
            return k.shift;
          case 'control':
            return k.control;
          case 'alt':
            return k.alt;
        }
      case null:
        _fail(DiagnosticCode.nothingReference, node);
      case GbList l:
        return _listMember(l, name, args, node, e);
      case GbArray a when name == 'length':
        return GbInt.of(a.items.length);
      case String s:
        return _stringMember(s, name, args, node, e);
      case GbException ex when name == 'message':
        return ex.message;
      case GbControl c:
        if (c.component.methods[name] case final method?) {
          return _controlMethod(c, method, args, node);
        }
        final property = c.component.properties.containsKey(name);
        if (name == 'name' && !property && args.isEmpty) {
          return c.isForm ? c.form : c.name ?? '';
        }
        if (c.isForm && name == 'controls' && !property && args.isEmpty) {
          return _controlsOf(_formNamed(c.form)!);
        }
        if (c.isForm && !property) {
          return _formMember(c, name, args, node, e);
        }
        if (args.isEmpty) return _getProperty(c, e);
      case GbControls cs:
        return _controlsMember(cs, name, args, node, e);
      case GbModule m:
        return _moduleMember(m, name, args, node, e);
      default:
    }
    _fail(DiagnosticCode.memberNotFound, node,
        [e.name.name, typeNameOf(receiver)]);
  }

  Object? _listMember(
      GbList l, String name, List<Object?> args, Node at, MemberExpr e) {
    final items = l.items;
    switch (name) {
      case 'count':
        return GbInt.of(items.length);
      case 'add':
        items.add(args[0]);
        return null;
      case 'insert':
        final i = (args[0] as GbInt).toSmallInt();
        if (i == null || i < 0 || i > items.length) {
          _fail(DiagnosticCode.indexOutOfRange, at,
              [(args[0] as GbInt).format(), '${items.length}']);
        }
        items.insert(i, args[1]);
        return null;
      case 'remove':
        final i = items.indexWhere((x) => valuesEqual(x, args[0]));
        if (i < 0) return false;
        items.removeAt(i);
        return true;
      case 'removeat':
        items.removeAt(_itemIndex(items, args[0], at));
        return null;
      case 'clear':
        items.clear();
        return null;
      case 'contains':
        return items.any((x) => valuesEqual(x, args[0]));
      case 'indexof':
        return GbInt.of(items.indexWhere((x) => valuesEqual(x, args[0])));
    }
    _fail(DiagnosticCode.memberNotFound, at, [e.name.name, typeNameOf(l)]);
  }

  Object? _stringMember(
      String s, String name, List<Object?> args, Node at, MemberExpr e) {
    String text(int i) => args[i] as String;
    switch (name) {
      case 'length':
        return GbInt.of(s.length);
      case 'substring':
        final start = (args[0] as GbInt).toSmallInt();
        if (start == null || start < 0 || start > s.length) {
          _fail(DiagnosticCode.indexOutOfRange, at,
              [(args[0] as GbInt).format(), '${s.length}']);
        }
        if (args.length < 2) return s.substring(start);
        final length = (args[1] as GbInt).toSmallInt();
        if (length == null || length < 0 || start + length > s.length) {
          _fail(DiagnosticCode.invalidArgument, at, ['Substring']);
        }
        return s.substring(start, start + length);
      case 'indexof':
        return GbInt.of(s.indexOf(text(0)));
      case 'contains':
        return s.contains(text(0));
      case 'startswith':
        return s.startsWith(text(0));
      case 'endswith':
        return s.endsWith(text(0));
      case 'replace':
        return text(0).isEmpty ? s : s.replaceAll(text(0), text(1));
      case 'toupper':
        return s.toUpperCase();
      case 'tolower':
        return s.toLowerCase();
      case 'trim':
        return s.trim();
      case 'split':
        return GbArray(GbType.string, s.split(text(0)));
    }
    _fail(DiagnosticCode.memberNotFound, at, [e.name.name, 'String']);
  }

  // -------------------------------------------------------------------------
  // Built-in functions (docs/LANGUAGE.md §10)

  /// A built-in that does not wait (all but MsgBox, InputBox, DoEvents).
  Object? _callBuiltinSync(Callable f, List<Object?> args, Node at) {
    final result = _callBuiltin(f, args, at);
    if (result is Future) {
      throw StateError('${f.name} waits; it must be called with await');
    }
    return result;
  }

  FutureOr<Object?> _callBuiltin(Callable f, List<Object?> args, Node at) {
    String s(int i) => args[i] as String;
    GbInt n(int i) => args[i] as GbInt;
    int small(int i, String fn) {
      final v = n(i).toSmallInt();
      if (v == null) _fail(DiagnosticCode.invalidArgument, at, [fn]);
      return v;
    }

    switch (f.name) {
      // Text (positions count from 1)
      case 'Len':
        return GbInt.of(s(0).length);
      case 'Left':
        final count = small(1, 'Left');
        if (count < 0) _fail(DiagnosticCode.invalidArgument, at, ['Left']);
        return s(0).substring(0, math.min(count, s(0).length));
      case 'Right':
        final count = small(1, 'Right');
        if (count < 0) _fail(DiagnosticCode.invalidArgument, at, ['Right']);
        final text = s(0);
        return text.substring(text.length - math.min(count, text.length));
      case 'Mid':
        final text = s(0);
        final start = small(1, 'Mid');
        if (start < 1) _fail(DiagnosticCode.invalidArgument, at, ['Mid']);
        final from = math.min(start - 1, text.length);
        if (args.length < 3) return text.substring(from);
        final length = small(2, 'Mid');
        if (length < 0) _fail(DiagnosticCode.invalidArgument, at, ['Mid']);
        return text.substring(from, math.min(from + length, text.length));
      case 'InStr':
        return GbInt.of(s(0).indexOf(s(1)) + 1);
      case 'UCase':
        return s(0).toUpperCase();
      case 'LCase':
        return s(0).toLowerCase();
      case 'Trim':
        return s(0).trim();
      case 'Replace':
        return s(1).isEmpty ? s(0) : s(0).replaceAll(s(1), s(2));
      case 'Split':
        return GbArray(GbType.string, s(0).split(s(1)));
      case 'Join':
        final items = args[0];
        if (items == null) _fail(DiagnosticCode.nothingReference, at);
        return (items as GbArray).items.map(formatValue).join(s(1));

      // Conversion
      case 'CInt':
        return _toInteger(args[0], at);
      case 'CDbl':
        return _toDouble(args[0], at);
      case 'CStr' || 'Str':
        return formatValue(args[0]);
      case 'CBool':
        return _toBoolean(args[0], at);
      case 'Val':
        return _val(s(0));

      // Math
      case 'Abs':
        final v = args[0];
        if (isGbInt(v)) {
          return (v as GbInt).abs() ??
              _fail(DiagnosticCode.integerOverflow, at);
        }
        return (v as double).abs();
      case 'Int':
        return _wholeToInteger((args[0] as double).floorToDouble(), at);
      case 'Round':
        final digits = args.length > 1 ? small(1, 'Round') : 0;
        return roundToDigits(args[0] as double, digits) ??
            _fail(DiagnosticCode.invalidArgument, at, ['Round']);
      case 'Sqr':
        final v = args[0] as double;
        if (v < 0) _fail(DiagnosticCode.invalidArgument, at, ['Sqr']);
        return math.sqrt(v);
      case 'Rnd':
        return _random.next();
      case 'Randomize':
        _random.seed(args.isEmpty ? timeSeed() : n(0));
        return null;
      case 'Min' || 'Max':
        final a = args[0], b = args[1];
        final aFirst = f.name == 'Min'
            ? _compareNumbers(a, b) <= 0
            : _compareNumbers(a, b) >= 0;
        final pick = aFirst ? a : b;
        // Mixed Integer and Double give a Double (as the analyzer typed it).
        return isGbInt(a) && isGbInt(b) ? pick : toDoubleValue(pick);

      // Arrays
      case 'UBound':
        final a = args[0];
        if (a == null) _fail(DiagnosticCode.nothingReference, at);
        return GbInt.of((a as GbArray).items.length - 1);

      // Date and time
      case 'Now':
        return DateTime.now();
      case 'Today':
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day);
      case 'Year':
        return GbInt.of((args[0] as DateTime).year);
      case 'Month':
        return GbInt.of((args[0] as DateTime).month);
      case 'Day':
        return GbInt.of((args[0] as DateTime).day);
      case 'Hour':
        return GbInt.of((args[0] as DateTime).hour);
      case 'Minute':
        return GbInt.of((args[0] as DateTime).minute);
      case 'Second':
        return GbInt.of((args[0] as DateTime).second);

      // Dialogs and program
      case 'MsgBox':
        return _dialog(host.msgBox(s(0), args.length > 1 ? s(1) : ''));
      case 'InputBox':
        return _dialog(host.inputBox(
            s(0), args.length > 1 ? s(1) : '', args.length > 2 ? s(2) : ''));
      case 'DoEvents':
        return _doEvents();

      // Settings (D48)
      case 'GetSetting':
        return _getSetting(s(0), s(1), at);
      case 'SaveSetting':
        return _saveSetting(s(0), s(1), at);
    }
    throw StateError('built-in ${f.name} is not available');
  }

  /// The program's settings, read from the host the first time they are
  /// needed; keys in lower case, as the language does not tell case apart.
  Map<String, String>? _settings;

  Future<Map<String, String>> _loadSettings() async {
    if (_settings case final settings?) return settings;
    final text = await host.loadSettings();
    final settings = <String, String>{};
    if (text != null) {
      try {
        if (jsonDecode(text) case final Map<String, Object?> map) {
          for (final MapEntry(:key, :value) in map.entries) {
            if (value is String) settings[key.toLowerCase()] = value;
          }
        }
      } on FormatException {
        // Not settings this interpreter wrote: start again without them.
      }
    }
    return _settings ??= settings;
  }

  String _settingKey(String key, String function, Node at) {
    if (key.isEmpty) _fail(DiagnosticCode.invalidArgument, at, [function]);
    return key.toLowerCase();
  }

  Future<String> _getSetting(String key, String fallback, Node at) async {
    final k = _settingKey(key, 'GetSetting', at);
    return (await _loadSettings())[k] ?? fallback;
  }

  Future<void> _saveSetting(String key, String value, Node at) async {
    final k = _settingKey(key, 'SaveSetting', at);
    final settings = {...await _loadSettings(), k: value};
    final text = jsonEncode(settings);
    if (text.length > settingsLimit) _fail(DiagnosticCode.settingsTooLarge, at);
    try {
      await host.saveSettings(text);
    } on Exception catch (e) {
      _fail(DiagnosticCode.settingsNotSaved, at, ['$e']);
    }
    _settings = settings;
  }

  GbInt _toInteger(Object? v, Node at) {
    if (isGbInt(v)) return v as GbInt;
    if (isGbDouble(v)) return _roundDouble(toDoubleValue(v), at);
    if (v is String) {
      final text = v.trim();
      if (RegExp(r'^[+-]?\d+$').hasMatch(text)) {
        return GbInt.parse(text) ?? _fail(DiagnosticCode.integerOverflow, at);
      }
      final d = double.tryParse(text);
      if (d == null || !d.isFinite) {
        _fail(DiagnosticCode.conversionFailed, at, [v, 'Integer']);
      }
      return _roundDouble(d, at);
    }
    _fail(DiagnosticCode.conversionFailed, at, [formatValue(v), 'Integer']);
  }

  /// CInt: half away from zero (2.5 → 3, -2.5 → -3).
  GbInt _roundDouble(double d, Node at) =>
      _wholeToInteger(d.roundToDouble(), at);

  /// A whole-number Double as an Integer, exactly, or R001.
  GbInt _wholeToInteger(double whole, Node at) {
    if (!whole.isFinite ||
        whole >= 9223372036854775808.0 ||
        whole < -9223372036854775808.0) {
      _fail(DiagnosticCode.integerOverflow, at);
    }
    return GbInt.fromWholeDouble(whole);
  }

  double _toDouble(Object? v, Node at) {
    if (isGbInt(v) || isGbDouble(v)) return toDoubleValue(v);
    if (v is String) {
      final d = double.tryParse(v.trim());
      if (d == null) _fail(DiagnosticCode.conversionFailed, at, [v, 'Double']);
      return d;
    }
    _fail(DiagnosticCode.conversionFailed, at, [formatValue(v), 'Double']);
  }

  bool _toBoolean(Object? v, Node at) {
    if (v is bool) return v;
    if (isGbInt(v)) return !(v as GbInt).isZero;
    if (isGbDouble(v)) return toDoubleValue(v) != 0;
    if (v is String) {
      switch (v.trim().toLowerCase()) {
        case 'true':
          return true;
        case 'false':
          return false;
      }
    }
    _fail(DiagnosticCode.conversionFailed, at, [formatValue(v), 'Boolean']);
  }

  /// `Val`: the number at the start of the text, or 0.
  double _val(String text) {
    final m =
        RegExp(r'^\s*([+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?)').firstMatch(text);
    return m == null ? 0.0 : double.parse(m[1]!);
  }
}

enum _Flow { normal, exitFor, exitDo, exitProcedure }

/// A change event to run: [handler], for [control]'s change.
typedef _Change = ({ProcedureDecl handler, GbControl control});

class _Frame {
  _Frame(this.procedure, this.form);

  final ProcedureDecl? procedure;

  /// The form whose code runs: its controls are the names' and `Me` (D88).
  final _FormRun form;
  final Map<Symbol, Object?> vars = Map.identity();
  Object? result;
}

class _BuiltinObject {
  const _BuiltinObject(this.name);
  final String name;
}

class _Failure implements Exception {
  _Failure(this.code, this.node, this.args, this.form);
  final DiagnosticCode code;
  final Node node;
  final List<String> args;

  /// Whose code [node] is in.
  final _FormRun form;
}

class _Thrown implements Exception {
  _Thrown(this.exception, this.node, this.form);
  final GbException exception;
  final Node node;
  final _FormRun form;
}

/// A form of the project while the program runs (D88), or the code
/// without a form ([program] null).
class _FormRun {
  _FormRun(this.program, this.lines, {this.module});

  final FormProgram? program;

  /// The module this is, for a module's code (D102).
  final ModuleProgram? module;

  /// To tell an error's line in the form's code.
  final LineMap lines;

  String get name => program?.name ?? module?.name ?? '';

  /// The code: the form's, or the module's.
  CompileResult? get code => program?.program ?? module?.program;

  /// The file the code is in, for errors.
  String? get codeFile => program?.codeFile ?? module?.codeFile;

  /// The form itself (null) and the controls on it, by lower-case name.
  final controls = <String?, GbControl>{};

  /// The controls of its form file, by lower-case name, which its code
  /// names: on it or not (D98).
  final designed = <String, GbControl>{};

  /// The controls on it, in the form file's order, then as added.
  final order = <GbControl>[];

  /// Shown since the start or since it was last closed: its Form_Load has
  /// run.
  var loaded = false;

  /// Ever loaded: shown again after Close, it starts again.
  var started = false;

  /// Completes when the form, shown by ShowDialog, goes.
  Completer<void>? dialog;
}

class _EndProgram implements Exception {
  const _EndProgram();
}

class _Stop implements Exception {
  const _Stop();
}

/// A handler that waited while the program ended: it does not go on.
class _Abandoned implements Exception {
  const _Abandoned();
}

/// Runs [source] (compile + interpret) with [host].
Future<RunResult> runProgram(String source, Host host,
        {Map<DiagnosticCode, String> messages = englishMessages}) =>
    Interpreter(compile(source), host, messages: messages).run();
