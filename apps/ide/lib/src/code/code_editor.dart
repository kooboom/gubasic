import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart'
    show ComposingTracker, committedText;

import '../project/open_project.dart';
import '../strings.dart';
import '../theme.dart';
import 'code_controller.dart';
import 'code_font.dart';
import 'completion_list.dart';
import 'handlers.dart';

/// The key of the code editor's text field.
const codeFieldKey = ValueKey('code.field');

/// The keys of the lists of objects and of events above the code.
const codeObjectsKey = ValueKey('code.objects');
const codeEventsKey = ValueKey('code.events');

/// The mark behind the line where the last run stopped with an error.
const codeErrorLineKey = ValueKey('code.errorLine');

/// The size of the code, and the height of a line, so that the line
/// numbers stay level with the lines whatever font a character takes.
const codeFontSize = 13.0;
const codeLineHeight = 1.5;

/// How many spaces Tab indents by.
const indentWidth = 4;

/// How long typing pauses before the code is compiled again for the
/// completion list (D50): names typed since then are not offered yet.
const completionCompileDelay = Duration(milliseconds: 300);

/// The keys that open the completion list (D50): ⌥Space on a Mac, where
/// ⌃Space switches the input source, Ctrl+Space elsewhere.
SingleActivator get completionShortcut =>
    defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS
    ? const SingleActivator(LogicalKeyboardKey.space, alt: true)
    : const SingleActivator(LogicalKeyboardKey.space, control: true);

/// The code editor (D36): the code file [file] of [project], coloured as
/// the lexer reads it, with line numbers. Only the characters the input
/// method has committed reach the file (LANGUAGE.md §11.1), so a syllable
/// being composed is never saved or run. Tab and Shift+Tab indent, Enter
/// keeps the line's indentation, and ⌘Z / Ctrl+Z undoes the typing.
/// Enter at the end of a line that opens a block (`If … Then`, `For`,
/// `Sub`, …) that is not closed puts in its closing line (`End If`,
/// `Next`, `End Sub`), unless that Enter committed what the input method
/// was composing. A list of the names that can go at the caret opens
/// after a `.` and
/// after two letters of a name, or with [completionShortcut]; never while
/// the input method composes (D50). Read-only while [locked] (a program
/// runs).
class CodeEditor extends StatefulWidget {
  const CodeEditor({
    super.key,
    required this.project,
    required this.file,
    required this.locked,
    required this.strings,
    this.focusCount = 0,
    this.goTo,
    this.errorLine,
  });

  final OpenProject project;

  /// The code file: `Form1.gbas`.
  final String file;
  final bool locked;

  /// A new number asks the editor to take the focus: the file was chosen
  /// again, and the editor may have been there, hidden, all along.
  final int focusCount;
  final IdeStrings strings;

  /// A procedure to go to, or a handler to add and go to: a double-click
  /// in the designer (D38). A new [GoTo.id] asks again.
  final GoTo? goTo;

  /// The line (1-based) where the last run stopped with an error, shown
  /// marked while the code is as it was run (D40); null for none.
  final int? errorLine;

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late final _controller = CodeController(text: _fileText);
  final _focus = FocusNode(debugLabel: 'code');
  var _undo = UndoHistoryController();
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  /// The text last written to the file from here, or read from it. Set
  /// as the editor opens: read later, it would already be a change made
  /// elsewhere, which then never showed.
  late String _written;

  /// The value before the last change, to see what the change was.
  late TextEditingValue _last;

  var _changing = false;

  String get _fileText => widget.project.files[widget.file] ?? '';

  @override
  void initState() {
    super.initState();
    CodeFont.load();
    // A caret from the start: the field's undo history records only values
    // with one, so the code as it was opened is the first step back.
    _controller.selection = const TextSelection.collapsed(offset: 0);
    _written = _fileText;
    _last = _controller.value;
    _tracker.track(_controller.value);
    _controller.addListener(_changed);
    HardwareKeyboard.instance.addHandler(_countKey);
    _focus.addListener(() {
      // This listener comes before the text field's own, so the selection
      // is still the user's here.
      if (!_focus.hasFocus) {
        if (_controller.selection.isValid) _caret = _controller.selection;
        _closeCompletion();
        _commitComposing();
      } else if (!_controller.selection.isValid) {
        // Back after a run hid the editor: the caret where it was, not at
        // the end of the code.
        final s = _caret;
        final n = _controller.text.length;
        _controller.selection = s.copyWith(
          baseOffset: min(s.baseOffset, n),
          extentOffset: min(s.extentOffset, n),
        );
      }
    });
    _updateControls();
    // The editor takes the focus when it opens, as the designer does: the
    // view it replaced may have had it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      if (widget.goTo case final goTo?) _goToFocused(goTo);
    });
  }

  @override
  void didUpdateWidget(CodeEditor old) {
    super.didUpdateWidget(old);
    _updateControls();
    if (widget.locked) _closeCompletion();
    if (widget.errorLine != old.errorLine) _built = null;
    final goTo = widget.goTo;
    final again = goTo != null && goTo.id != old.goTo?.id;
    if (widget.focusCount != old.focusCount || again) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _reload();
        _focus.requestFocus();
        if (again) _goToFocused(goTo);
      });
    }
    // The file changed some other way (the designer made a handler or
    // renamed a control): show it, with an undo history of its own.
    if (_fileText != _written) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
    }
  }

  void _reload() {
    if (!mounted || _fileText == _written) return;
    final text = _fileText;
    final offset = min(_controller.selection.baseOffset, text.length);
    _written = text;
    _changing = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: max(0, offset)),
    );
    _changing = false;
    _last = _controller.value;
    setState(() {
      _undo.dispose();
      _undo = UndoHistoryController();
      _built = null;
    });
  }

  String? _formText;
  var _formRead = false;

  /// The form the code belongs to, for the lists of objects and events.
  FormFile? _form;

  /// The form's control names, coloured in the code; read again only when
  /// the form file changed.
  void _updateControls() {
    final formFile = widget.file.replaceFirst(
      RegExp(r'\.gbas$', caseSensitive: false),
      '.form.yaml',
    );
    final form = widget.project.files[formFile];
    if (form == _formText && _formRead) return;
    _formText = form;
    _formRead = true;
    _built = null;
    _program = null;
    _form = form == null ? null : readFormFile(form, name: '').form;
    _controller.controls = {
      for (final c in _form?.controls ?? const <ControlDecl>[])
        c.name.toLowerCase(),
    };
  }

  /// The handler just added, and the code before it: ⌘Z takes it out
  /// while nothing else was typed, also when the field's own history,
  /// which keeps a step only every half second, has not recorded the code
  /// as it was opened.
  ({TextEditingValue before, String after})? _handlerAdded;

  /// ⌘Z: takes out the handler just added, if the field's history
  /// cannot; true when it did.
  bool _undoHandlerAdded() {
    final added = _handlerAdded;
    _handlerAdded = null;
    if (added == null || _undo.value.canUndo) return false;
    if (_controller.text != added.after) return false;
    _controller.value = added.before;
    return true;
  }

  /// Goes where [goTo] says once the editor has the focus: the field's
  /// undo history records only while it has the focus, and a handler
  /// added is undone in one step.
  void _goToFocused(GoTo goTo) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (goTo.line case final line?) {
        _controller.selection = TextSelection.collapsed(
          offset: caretAtLine(_controller.text, line),
        );
      } else {
        _goTo(goTo.name, goTo.signature);
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Goes to the procedure [name] (the top of the code when empty); adds
  /// the handler `Sub [signature]` first when there is none, unless a
  /// program runs.
  void _goTo(String name, String? signature) {
    final text = _controller.text;
    if (name.isEmpty) {
      _controller.selection = const TextSelection.collapsed(offset: 0);
      return;
    }
    final p = procedureNamed(text, name);
    if (p != null) {
      _controller.selection = TextSelection.collapsed(offset: caretIn(text, p));
    } else if (signature != null && !widget.locked) {
      final added = withHandler(text, signature);
      final before = _controller.value;
      _controller.value = TextEditingValue(
        text: added.text,
        selection: TextSelection.collapsed(offset: added.caret),
      );
      _handlerAdded = (before: before, after: added.text);
    } else if (signature != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            widget.strings.noHandlerWhileRunning.replaceAll('{0}', name),
          ),
        ),
      );
    }
  }

  /// The objects of the form, as the list shows them: `Form`, then the
  /// controls, each with its component.
  List<(String, ComponentSpec)> get _objects => [
    ('Form', formComponent),
    for (final c in _form?.controls ?? const <ControlDecl>[])
      (c.name, c.component),
  ];

  /// The object a procedure is the handler of, and its event; null for a
  /// procedure of its own ((General)).
  (String, String)? _handlerOf(String procedure) {
    final lower = procedure.toLowerCase();
    for (final (name, component) in _objects) {
      final prefix = '${name.toLowerCase()}_';
      if (!lower.startsWith(prefix)) continue;
      final event = component.events[lower.substring(prefix.length)];
      if (event != null) return (name, event.name);
    }
    return null;
  }

  /// The object chosen in the list; null for (General). Follows the caret
  /// until the user chooses one.
  String? _object;
  Procedure? _caretIn;

  /// Keeps the lists with the procedure the caret is in.
  void _followCaret() {
    final s = _controller.selection;
    if (!s.isValid) return;
    final procs = proceduresOf(_controller.text);
    Procedure? here;
    for (final p in procs) {
      if (p.contains(s.baseOffset)) here = p;
    }
    if (here?.name == _caretIn?.name && here != null) return;
    _caretIn = here;
    _object = here == null ? null : _handlerOf(here.name)?.$1;
  }

  Widget _lists(BuildContext context) {
    final s = widget.strings;
    final theme = Theme.of(context);
    final text = _controller.text;
    final procs = proceduresOf(text);
    final names = {for (final p in procs) p.name.toLowerCase()};
    final object = _object;
    final here = _caretIn == null ? null : _handlerOf(_caretIn!.name);
    final component = object == null
        ? null
        : _objects
              .firstWhere((o) => o.$1 == object, orElse: () => _objects.first)
              .$2;
    final events = <(String, String, String?)>[
      // (key, label, signature)
      if (component == null) ...[
        ('', s.declarations, null),
        for (final p in procs)
          if (_handlerOf(p.name) == null) (p.name, p.name, null),
      ] else
        for (final e in component.events.values)
          ('${object}_${e.name}', e.name, e.handlerSignature(object!)),
    ];
    final eventValue = component == null
        ? (_caretIn != null && here == null ? _caretIn!.name : '')
        : (here != null && here.$1 == object ? '${object}_${here.$2}' : null);
    TextStyle? bold(String key) => names.contains(key.toLowerCase())
        ? const TextStyle(fontWeight: FontWeight.bold)
        : null;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: s.objectList,
              child: DropdownButton<String>(
                key: codeObjectsKey,
                isExpanded: true,
                underline: const SizedBox(),
                value: object ?? '',
                onChanged: (v) => setState(() {
                  _object = v!.isEmpty ? null : v;
                  _built = null;
                }),
                items: [
                  DropdownMenuItem(value: '', child: Text(s.generalObject)),
                  for (final (name, c) in _objects)
                    DropdownMenuItem(
                      value: name,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            c.name,
                            style: TextStyle(color: theme.hintColor),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Tooltip(
              message: s.eventList,
              child: DropdownButton<String>(
                key: codeEventsKey,
                isExpanded: true,
                underline: const SizedBox(),
                value: events.any((e) => e.$1 == eventValue)
                    ? eventValue
                    : null,
                onChanged: (key) {
                  final e = events.firstWhere((e) => e.$1 == key);
                  _goTo(e.$1, e.$3);
                  _focus.requestFocus();
                },
                items: [
                  for (final (key, label, _) in events)
                    DropdownMenuItem(
                      value: key,
                      child: Text(label, style: bold(key)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_countKey);
    _compileTimer?.cancel();
    _completion.dispose();
    _controller.dispose();
    _focus.dispose();
    _undo.dispose();
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  /// The last valid selection: the editor puts the caret back there when
  /// it takes the focus again.
  var _caret = const TextSelection.collapsed(offset: 0);

  /// What is being composed, as the platform says or as guessed where it
  /// says nothing (the macOS app, D37).
  late final _tracker = ComposingTracker(_controller.value);

  void _changed() {
    final wasComposing = _composing || _isComposing(_last);
    _tracker.track(_controller.value);
    _followCaret();
    if (_changing) return;
    final value = _controller.value;
    final last = _last;
    _last = value;
    if (!widget.locked && _isNewLine(last, value)) {
      // An Enter that committed what was being composed, even when the
      // line break comes in a change of its own after the commit (as
      // browsers send it), closes no block.
      final committing = wasComposing || _committedAt == _keyDowns;
      _committedAt = null;
      _closeCompletion();
      _indentNewLine(last, closeBlock: !committing);
      return;
    }
    if (value.text == last.text) {
      if (wasComposing && !_composing && !_isComposing(value)) {
        _committedAt = _keyDowns;
      }
    } else {
      _committedAt = null;
    }
    _write();
    _completeAfter(last, value);
  }

  static bool _isComposing(TextEditingValue v) =>
      v.composing.isValid && !v.composing.isCollapsed;

  /// How many keys went down in the IDE so far, and how many had when the
  /// input method last committed without changing the text: a line break
  /// with no key pressed since is that commit's Enter.
  var _keyDowns = 0;
  int? _committedAt;

  bool _countKey(KeyEvent event) {
    if (event is KeyDownEvent) _keyDowns++;
    return false;
  }

  /// Writes what the input method has committed, when it changed.
  void _write() {
    if (widget.locked) return;
    final committed = committedText(_tracker.value);
    if (committed == _written) return;
    _written = committed;
    widget.project.setFile(widget.file, committed);
    _compileTimer?.cancel();
    _compileTimer = Timer(completionCompileDelay, _compile);
  }

  // ---------------------------------------------------------------------
  // The completion list (D50)

  /// The list shown under the caret, and the row chosen in it; null when
  /// none is shown.
  final _completion = ValueNotifier<({Completions list, int selected})?>(null);
  final _completionPortal = OverlayPortalController();
  final _caretLink = LayerLink();
  final _caretKey = GlobalKey();

  /// The code's visible area: the list shows only while its word is in
  /// it, also when the code scrolls under it.
  final _viewKey = GlobalKey();
  late final _scrolled = Listenable.merge([_vertical, _horizontal]);

  /// The last compilation of the code, which the list looks names up in.
  /// Compiled when typing pauses, not at every key.
  CompileResult? _program;
  Timer? _compileTimer;

  /// Where the word was when Esc closed the list: it does not open by
  /// itself again for that word.
  int? _dismissedAt;

  /// A completion is being put in: that change opens nothing.
  var _accepting = false;

  void _compile() {
    if (!mounted) return;
    _program = compile(_written, form: _form);
  }

  /// [_program], compiled now if it is not of the code as it is.
  CompileResult _freshProgram() {
    _compileTimer?.cancel();
    final program = _program;
    if (program != null && program.parseResult.source == _written) {
      return program;
    }
    return _program = compile(_written, form: _form);
  }

  bool get _canComplete {
    final value = _controller.value;
    return !widget.locked &&
        _focus.hasFocus &&
        !_composing &&
        !(value.composing.isValid && !value.composing.isCollapsed) &&
        value.selection.isValid &&
        value.selection.isCollapsed;
  }

  /// Opens, follows or closes the list after the text or the caret
  /// changed from [last] to [value].
  void _completeAfter(TextEditingValue last, TextEditingValue value) {
    if (_accepting) return;
    if (!_canComplete) {
      _closeCompletion();
      return;
    }
    final open = _completion.value != null;
    final caret = value.selection.baseOffset;
    if (value.text == last.text) {
      // The caret moved: the list follows it within the word.
      if (open) _showCompletions(keepStart: true);
      return;
    }
    final typed = _typed(last, value);
    if (typed == '.') {
      _dismissedAt = null;
      _showCompletions(onlyAfterDot: true);
    } else if (typed != null && _isNamePart(typed)) {
      _showCompletions(byTyping: !open);
    } else if (open && last.text.length == value.text.length + 1) {
      // Backspace: the list follows the shorter word.
      _showCompletions(keepStart: true);
    } else {
      _closeCompletion();
    }
    if (_dismissedAt != null && caret < _dismissedAt!) _dismissedAt = null;
  }

  /// The one character typed at the caret between [last] and [now]; null
  /// for any other change.
  static String? _typed(TextEditingValue last, TextEditingValue now) {
    final s = last.selection;
    final c = now.selection.baseOffset;
    if (!s.isValid ||
        !s.isCollapsed ||
        now.text.length != last.text.length + 1) {
      return null;
    }
    if (c != s.baseOffset + 1) return null;
    final ch = now.text.substring(c - 1, c);
    return now.text.replaceRange(c - 1, c, '') == last.text ? ch : null;
  }

  static bool _isNamePart(String ch) => RegExp(r'^[A-Za-z0-9_]$').hasMatch(ch);

  /// Shows the names for the caret, or closes the list when there are
  /// none. [byTyping]: opened by the letters of a name, so only from two
  /// of them on, and not for a word Esc closed it on. [onlyAfterDot]:
  /// only members. [keepStart]: closes it when the caret left the word.
  void _showCompletions({
    bool byTyping = false,
    bool onlyAfterDot = false,
    bool keepStart = false,
    bool explicit = false,
  }) {
    final value = _controller.value;
    final caret = value.selection.baseOffset;
    final c = completionsAt(
      value.text,
      caret,
      program: explicit ? _freshProgram() : _program,
      form: _form,
    );
    final shown = _completion.value;
    final ok =
        c != null &&
        c.items.isNotEmpty &&
        (!onlyAfterDot || c.afterDot) &&
        (!keepStart || shown == null || shown.list.start == c.start) &&
        (!byTyping ||
            (c.prefix.length >= 2 &&
                c.prefix.codeUnitAt(0) > 0x39 &&
                c.start != _dismissedAt)) &&
        // Nothing to add to a word typed in full, unless asked for.
        (explicit || !_onlyItself(c, value.text));
    if (!ok) {
      _closeCompletion();
      return;
    }
    _completion.value = (list: c, selected: 0);
    if (!_completionPortal.isShowing) _completionPortal.show();
  }

  /// Whether the only name offered is the word itself.
  static bool _onlyItself(Completions c, String text) =>
      c.items.length == 1 &&
      c.items.single.kind != CompletionKind.suggestion &&
      c.items.single.name.toLowerCase() ==
          text.substring(c.start, c.end).toLowerCase();

  void _closeCompletion() {
    if (_completion.value == null) return;
    _completion.value = null;
    if (_completionPortal.isShowing) _completionPortal.hide();
  }

  /// [completionShortcut]: the list for the caret, whatever is typed, with
  /// "did you mean" for the word it is on.
  void _completeNow() {
    if (!_canComplete) return;
    _dismissedAt = null;
    _showCompletions(explicit: true);
  }

  /// Puts row [index] of the list in place of the word.
  void _accept(int index) {
    final shown = _completion.value;
    if (shown == null) return;
    final c = shown.list;
    final name = c.items[index].name;
    final text = _controller.text;
    _closeCompletion();
    if (c.end > text.length) return;
    _accepting = true;
    _controller.value = TextEditingValue(
      text: text.replaceRange(c.start, c.end, name),
      selection: TextSelection.collapsed(offset: c.start + name.length),
    );
    _accepting = false;
  }

  /// The keys of the open list: ↑ ↓ choose, Enter and Tab put the choice
  /// in, Esc closes it. Enter on a word typed in full breaks the line.
  KeyEventResult _completionKey(FocusNode node, KeyEvent event) {
    final shown = _completion.value;
    if (shown == null || event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final n = shown.list.items.length;
    void select(int i) => _completion.value = (list: shown.list, selected: i);
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        select((shown.selected + 1) % n);
      case LogicalKeyboardKey.arrowUp:
        select((shown.selected - 1 + n) % n);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        if (event is KeyRepeatEvent) return KeyEventResult.ignored;
        final c = shown.list;
        final word = _controller.text.substring(c.start, c.end);
        if (c.items[shown.selected].name.toLowerCase() == word.toLowerCase()) {
          _closeCompletion();
          return KeyEventResult.ignored;
        }
        _accept(shown.selected);
      case LogicalKeyboardKey.tab when !keyboard.isShiftPressed:
        if (event is KeyRepeatEvent) return KeyEventResult.ignored;
        _accept(shown.selected);
      case LogicalKeyboardKey.escape:
        _dismissedAt = shown.list.start;
        _closeCompletion();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// Where the word being completed starts, from the top left of the
  /// text: lines and columns, the font being monospaced.
  Offset _wordOffset(int start, TextStyle style) {
    final text = _controller.text;
    final lineStart = _lineStart(text, start);
    final line = '\n'.allMatches(text.substring(0, lineStart)).length;
    final column = _columns(text.substring(lineStart, start));
    return Offset(
      column * _columnWidth(style),
      line * codeFontSize * codeLineHeight,
    );
  }

  Widget _completionOverlay(BuildContext context, TextStyle style) =>
      ListenableBuilder(
        listenable: Listenable.merge([_completion, _scrolled]),
        builder: (context, _) {
          final shown = _completion.value;
          if (shown == null) return const SizedBox();
          final height = CompletionList.heightOf(shown.list);
          // Above the line when there is no room below it.
          var below = true;
          final box = _caretKey.currentContext?.findRenderObject();
          final view = _viewKey.currentContext?.findRenderObject();
          if (box is RenderBox && box.attached) {
            final word = box.localToGlobal(Offset.zero) & box.size;
            if (view is RenderBox && view.attached) {
              final area = view.localToGlobal(Offset.zero) & view.size;
              if (word.top < area.top - 1 ||
                  word.bottom > area.bottom + 1 ||
                  word.left < area.left + 40 || // under the line numbers
                  word.left > area.right) {
                return const SizedBox();
              }
            }
            below = word.bottom + height <= MediaQuery.sizeOf(context).height;
          }
          return CompositedTransformFollower(
            link: _caretLink,
            showWhenUnlinked: false,
            targetAnchor: below ? Alignment.bottomLeft : Alignment.topLeft,
            followerAnchor: below ? Alignment.topLeft : Alignment.bottomLeft,
            // Clear of the line's descenders.
            offset: Offset(0, below ? 2 : -2),
            child: Align(
              alignment: below ? Alignment.topLeft : Alignment.bottomLeft,
              child: TextFieldTapRegion(
                child: CompletionList(
                  completions: shown.list,
                  selected: shown.selected,
                  strings: widget.strings,
                  style: style,
                  onPick: _accept,
                ),
              ),
            ),
          );
        },
      );

  /// Takes what is being composed as committed (the field lost the focus
  /// before the input method committed it).
  void _commitComposing() {
    final value = _controller.value;
    if (value.composing.isValid && !value.composing.isCollapsed) {
      _controller.value = value.copyWith(composing: TextRange.empty);
    } else if (_tracker.composing) {
      _tracker.commit();
      _write();
    }
  }

  /// Whether [now] is [before] with its selection replaced by a line
  /// break: Enter.
  static bool _isNewLine(TextEditingValue before, TextEditingValue now) {
    final s = before.selection;
    if (!s.isValid || now.composing.isValid && !now.composing.isCollapsed) {
      return false;
    }
    return now.text == before.text.replaceRange(s.start, s.end, '\n') &&
        now.selection.isCollapsed &&
        now.selection.baseOffset == s.start + 1;
  }

  /// After Enter: the new line starts with the indentation of the line
  /// the break was made in. With [closeBlock], a block that line opens
  /// and nothing closes gets its closing line, and the caret goes inside.
  void _indentNewLine(TextEditingValue before, {required bool closeBlock}) {
    final text = _controller.text;
    final at = _controller.selection.baseOffset;
    final lineStart = _lineStart(before.text, before.selection.start);
    final indent = RegExp(r'^[ \t]*')
        .firstMatch(before.text.substring(lineStart, before.selection.start))!
        .group(0)!;
    final closer = closeBlock ? _closerFor(before, lineStart, text) : null;
    if (closer != null) {
      final inside = '$indent${' ' * indentWidth}';
      _changing = true;
      _controller.value = TextEditingValue(
        text: text.replaceRange(at, at, '$inside\n$indent$closer'),
        selection: TextSelection.collapsed(offset: at + inside.length),
      );
      _changing = false;
      _last = _controller.value;
    } else if (indent.isNotEmpty) {
      _changing = true;
      _controller.value = TextEditingValue(
        text: text.replaceRange(at, at, indent),
        selection: TextSelection.collapsed(offset: at + indent.length),
      );
      _changing = false;
      _last = _controller.value;
    }
    _write();
  }

  bool get _composing => _tracker.composing;

  static final _opener = RegExp(
    r'^[ \t]*(?:(?:public|private)[ \t]+)?(?:if|for|do|select|sub|function|try)\b',
    caseSensitive: false,
  );

  /// The closing line (`End If`) for the block that the line at
  /// [lineStart] of [before] opens, when Enter was pressed at its end and
  /// the parser finds the block not closed in [now] (P006).
  static String? _closerFor(
    TextEditingValue before,
    int lineStart,
    String now,
  ) {
    final text = before.text;
    var lineEnd = text.indexOf('\n', before.selection.end);
    if (lineEnd < 0) lineEnd = text.length;
    if (text.substring(before.selection.end, lineEnd).trim().isNotEmpty) {
      return null; // The line was split, not ended.
    }
    if (!_opener.hasMatch(text.substring(lineStart, lineEnd))) return null;
    final line = '\n'.allMatches(text.substring(0, lineStart)).length + 1;
    for (final d in parse(now).parserDiagnostics) {
      if (d.code == DiagnosticCode.unclosedBlock && d.line == line) {
        return d.args[2];
      }
    }
    return null;
  }

  /// The first and the last line of the selection, as offsets: the start
  /// of the first and the end of the last.
  (int, int) _selectedLines() {
    final text = _controller.text;
    final s = _controller.selection;
    final start = _lineStart(text, s.start);
    var endAt = s.end;
    // A selection that ends at the start of a line leaves that line out.
    if (s.end > s.start && s.end > 0 && text[s.end - 1] == '\n') endAt--;
    final end = text.indexOf('\n', endAt);
    return (start, end < 0 ? text.length : end);
  }

  void _tab() {
    if (widget.locked || _composing) return;
    final s = _controller.selection;
    final text = _controller.text;
    if (!s.isValid) return;
    if (s.isCollapsed || !text.substring(s.start, s.end).contains('\n')) {
      // To the next indentation stop.
      final column = s.start - _lineStart(text, s.start);
      final spaces = ' ' * (indentWidth - column % indentWidth);
      _controller.value = TextEditingValue(
        text: text.replaceRange(s.start, s.end, spaces),
        selection: TextSelection.collapsed(offset: s.start + spaces.length),
      );
      return;
    }
    _eachLine((line) => '${' ' * indentWidth}$line');
  }

  void _untab() {
    if (widget.locked || _composing) return;
    _eachLine((line) {
      final spaces = RegExp(r'^ {0,4}').firstMatch(line)!.group(0)!.length;
      return line.substring(spaces);
    });
  }

  /// Changes each selected line with [change], and selects them all.
  void _eachLine(String Function(String line) change) {
    final (start, end) = _selectedLines();
    final text = _controller.text;
    final lines = text.substring(start, end).split('\n').map(change).join('\n');
    _controller.value = TextEditingValue(
      text: text.replaceRange(start, end, lines),
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + lines.length,
      ),
    );
  }

  /// What [build] gave last, and for which [CodeEditor.locked]: the IDE
  /// redraws around the editor at each key, and the editor follows its
  /// text and font by itself.
  Widget? _built;
  bool? _builtLocked;
  ThemeData? _builtTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_built != null &&
        _builtLocked == widget.locked &&
        identical(_builtTheme, theme)) {
      return _built!;
    }
    _builtLocked = widget.locked;
    _builtTheme = theme;
    return _built = ValueListenableBuilder(
      valueListenable: CodeFont.loaded,
      builder: (context, _, _) {
        final style = codeStyle.copyWith(
          fontSize: codeFontSize,
          height: codeLineHeight,
          color: theme.colorScheme.onSurface,
        );
        final strut = StrutStyle(
          fontFamily: style.fontFamily,
          fontFamilyFallback: style.fontFamilyFallback,
          fontSize: codeFontSize,
          height: codeLineHeight,
          forceStrutHeight: true,
        );
        return ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _lists(context),
              const Divider(height: 1),
              Expanded(
                child: _layout(context, style, strut, theme.colorScheme),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _layout(
    BuildContext context,
    TextStyle style,
    StrutStyle strut,
    ColorScheme scheme,
  ) {
    final text = _controller.text;
    final lines = '\n'.allMatches(text).length + 1;
    // Long lines scroll sideways rather than wrap, so that a line number
    // stands for one line. The font is monospaced: the widest line is the
    // one with the most columns, a wide character (Hangul) taking two.
    final columns = text
        .split('\n')
        .fold(0, (most, line) => max(most, _columns(line)));
    final widest = columns * _columnWidth(style);
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        key: _viewKey,
        controller: _vertical,
        child: SingleChildScrollView(
          controller: _vertical,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Stack(
            children: [
              if (widget.errorLine case final line? when line <= lines)
                Positioned(
                  key: codeErrorLineKey,
                  left: 0,
                  right: 0,
                  top: (line - 1) * codeFontSize * codeLineHeight,
                  height: codeFontSize * codeLineHeight,
                  child: ColoredBox(color: scheme.errorContainer),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _gutter(lines, style, strut, scheme),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _horizontal,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: max(constraints.maxWidth - 48, widest + 32),
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.tab): _tab,
                            const SingleActivator(
                              LogicalKeyboardKey.tab,
                              shift: true,
                            ): _untab,
                            completionShortcut: _completeNow,
                          },
                          child: Focus(
                            canRequestFocus: false,
                            skipTraversal: true,
                            onKeyEvent: _completionKey,
                            child: OverlayPortal(
                              controller: _completionPortal,
                              overlayChildBuilder: (context) =>
                                  _completionOverlay(context, style),
                              child: Stack(
                                children: [
                                  _caretTarget(style),
                                  _field(style, strut),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A point where the word being completed starts, one line high, that
  /// the completion list hangs from.
  Widget _caretTarget(TextStyle style) => ValueListenableBuilder(
    valueListenable: _completion,
    builder: (context, shown, _) {
      final at = shown == null
          ? Offset.zero
          : _wordOffset(shown.list.start, style);
      return Positioned(
        left: at.dx,
        top: at.dy,
        child: CompositedTransformTarget(
          key: _caretKey,
          link: _caretLink,
          child: const SizedBox(
            width: 1,
            height: codeFontSize * codeLineHeight,
          ),
        ),
      );
    },
  );

  Widget _field(TextStyle style, StrutStyle strut) => Actions(
    actions: {UndoTextIntent: _UndoHandlerAdded(_undoHandlerAdded)},
    child: TextField(
      key: codeFieldKey,
      controller: _controller,
      focusNode: _focus,
      undoController: _undo,
      readOnly: widget.locked,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      style: style,
      strutStyle: strut,
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      decoration: const InputDecoration.collapsed(hintText: null),
    ),
  );

  /// The offset where the line holding [offset] starts.
  static int _lineStart(String text, int offset) =>
      offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;

  // The line numbers, built again only when the number of lines or the
  // style changes.
  Widget? _gutterBuilt;
  (int, TextStyle)? _gutterFor;

  Widget _gutter(int lines, TextStyle style, StrutStyle strut, ColorScheme s) {
    if (_gutterBuilt != null && _gutterFor == (lines, style)) {
      return _gutterBuilt!;
    }
    _gutterFor = (lines, style);
    return _gutterBuilt = Container(
      width: 48,
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        [for (var i = 1; i <= lines; i++) '$i'].join('\n'),
        textAlign: TextAlign.right,
        strutStyle: strut,
        style: style.copyWith(color: s.outline),
      ),
    );
  }

  /// The columns [line] takes: two for a wide character (East Asian
  /// Wide or Fullwidth, such as Hangul), one for others.
  static int _columns(String line) {
    var n = 0;
    for (final r in line.runes) {
      n += _isWide(r) ? 2 : 1;
    }
    return n;
  }

  static bool _isWide(int r) =>
      (r >= 0x1100 && r <= 0x115F) || // Hangul Jamo
      (r >= 0x2E80 && r <= 0xA4CF) || // CJK, Hangul compatibility jamo
      (r >= 0xAC00 && r <= 0xD7A3) || // Hangul syllables
      (r >= 0xF900 && r <= 0xFAFF) ||
      (r >= 0xFE30 && r <= 0xFE4F) ||
      (r >= 0xFF00 && r <= 0xFF60) ||
      (r >= 0xFFE0 && r <= 0xFFE6) ||
      (r >= 0x1F300 && r <= 0x1FAFF) ||
      (r >= 0x20000 && r <= 0x3FFFD);

  /// The width of one column in [style], measured once per style.
  double _columnWidth(TextStyle style) {
    if (_measured != style) {
      final painter = TextPainter(
        text: TextSpan(text: 'M', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      _column = painter.width;
      painter.dispose();
      _measured = style;
    }
    return _column;
  }

  TextStyle? _measured;
  var _column = 0.0;
}

/// ⌘Z / Ctrl+Z in the code editor: first [undoHandlerAdded], then the
/// field's own undo.
class _UndoHandlerAdded extends ContextAction<UndoTextIntent> {
  _UndoHandlerAdded(this.undoHandlerAdded);

  final bool Function() undoHandlerAdded;

  @override
  Object? invoke(UndoTextIntent intent, [BuildContext? context]) {
    if (undoHandlerAdded()) return null;
    return callingAction?.invoke(intent);
  }
}
