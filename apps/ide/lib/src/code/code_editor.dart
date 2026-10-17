import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart'
    show ComposingTracker, committedText;

import '../project/open_project.dart';
import '../theme.dart';
import 'code_controller.dart';
import 'code_font.dart';

/// The key of the code editor's text field.
const codeFieldKey = ValueKey('code.field');

/// The size of the code, and the height of a line, so that the line
/// numbers stay level with the lines whatever font a character takes.
const codeFontSize = 14.0;
const codeLineHeight = 1.5;

/// How many spaces Tab indents by.
const indentWidth = 4;

/// The code editor (D36): the code file [file] of [project], coloured as
/// the lexer reads it, with line numbers. Only the characters the input
/// method has committed reach the file (LANGUAGE.md §11.1), so a syllable
/// being composed is never saved or run. Tab and Shift+Tab indent, Enter
/// keeps the line's indentation, and ⌘Z / Ctrl+Z undoes the typing.
/// Read-only while [locked] (a program runs).
class CodeEditor extends StatefulWidget {
  const CodeEditor({
    super.key,
    required this.project,
    required this.file,
    required this.locked,
    this.focusCount = 0,
  });

  final OpenProject project;

  /// The code file: `Form1.gbas`.
  final String file;
  final bool locked;

  /// A new number asks the editor to take the focus: the file was chosen
  /// again, and the editor may have been there, hidden, all along.
  final int focusCount;

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late final _controller = CodeController(text: _fileText);
  final _focus = FocusNode(debugLabel: 'code');
  var _undo = UndoHistoryController();
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  /// The text last written to the file from here, or read from it.
  late String _written = _fileText;

  /// The value before the last change, to see what the change was.
  late TextEditingValue _last = _controller.value;

  var _changing = false;

  String get _fileText => widget.project.files[widget.file] ?? '';

  @override
  void initState() {
    super.initState();
    CodeFont.load();
    _controller.addListener(_changed);
    _focus.addListener(() {
      // This listener comes before the text field's own, so the selection
      // is still the user's here.
      if (!_focus.hasFocus) {
        if (_controller.selection.isValid) _caret = _controller.selection;
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
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(CodeEditor old) {
    super.didUpdateWidget(old);
    _updateControls();
    if (widget.focusCount != old.focusCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
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
    });
  }

  String? _formText;
  var _formRead = false;

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
    _controller.controls = form == null
        ? const {}
        : {
            for (final c in readFormFile(form, name: '').form.controls)
              c.name.toLowerCase(),
          };
  }

  @override
  void dispose() {
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
    _tracker.track(_controller.value);
    if (_changing) return;
    final value = _controller.value;
    final last = _last;
    _last = value;
    if (!widget.locked && _isNewLine(last, value)) {
      _indentNewLine(last);
      return;
    }
    _write();
  }

  /// Writes what the input method has committed, when it changed.
  void _write() {
    if (widget.locked) return;
    final committed = committedText(_tracker.value);
    if (committed == _written) return;
    _written = committed;
    widget.project.setFile(widget.file, committed);
  }

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
  /// the break was made in.
  void _indentNewLine(TextEditingValue before) {
    final text = _controller.text;
    final at = _controller.selection.baseOffset;
    final lineStart = _lineStart(before.text, before.selection.start);
    final indent = RegExp(r'^[ \t]*')
        .firstMatch(before.text.substring(lineStart, before.selection.start))!
        .group(0)!;
    if (indent.isNotEmpty) {
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
          builder: (context, _) =>
              _layout(context, style, strut, theme.colorScheme),
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
        controller: _vertical,
        child: SingleChildScrollView(
          controller: _vertical,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
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
                      },
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
                        decoration: const InputDecoration.collapsed(
                          hintText: null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
