import '../diagnostics/diagnostic.dart';
import '../parser/parse_result.dart';
import '../parser/parser.dart';

/// What the code editor does after Enter ends line [line] (from 1) of
/// [text], which already has the line break and an empty line after it
/// (docs/DESIGN.md D61):
///
/// - [indentLine]: the spaces line [line] should start with, when it goes
///   on with or closes a block (`Else`, `End If`) and is not indented as
///   its opener is; null to leave it.
/// - [newIndent]: the spaces the new line starts with: one step inside
///   after an opener or a line that goes on with a block, the opener's
///   after a closing line, else the ended line's own.
/// - [closer]: the closing line (`End If`) to put after the new line,
///   when line [line] opens a block and putting it there leaves fewer
///   blocks unpaired than before: the blocks are counted, so a nested
///   block gets its own even when an `End If` further down closes the
///   outer one.
typedef AfterEnter = ({int? indentLine, int newIndent, String? closer});

final _opener = RegExp(
  r'^[ \t]*(?:(?:public|private)[ \t]+)?(?:if|for|do|while|select|sub|function|try)\b',
  caseSensitive: false,
);

final _goesOn = RegExp(
  r'^[ \t]*(?:else|elseif|case|catch|finally|next|loop|wend|'
  r'end[ \t]+(?:if|sub|function|select|try|while))\b',
  caseSensitive: false,
);

/// See [AfterEnter]. With [closeBlock] false (an Enter that committed
/// what an input method was composing, mostly meant to end a syllable)
/// the new line only keeps the ended line's indentation.
AfterEnter afterEnter(
  String text,
  int line, {
  int indentWidth = 4,
  bool closeBlock = true,
}) {
  final lines = text.split('\n');
  final ended = lines[line - 1];
  int indentOf(int n) => _indent(lines[n - 1]);
  final own = _indent(ended);
  final keep = (indentLine: null, newIndent: own, closer: null);
  if (!closeBlock) return keep;
  if (!_opener.hasMatch(ended) && !_goesOn.hasMatch(ended)) return keep;

  final read = parse(text);
  final blocks = read.blockLines;
  if (blocks.middles[line] ?? blocks.closers[line] case final opener?) {
    final target = indentOf(opener);
    return (
      indentLine: target == own ? null : target,
      newIndent:
          blocks.middles.containsKey(line) ? target + indentWidth : target,
      closer: null,
    );
  }
  final closer = blocks.openers[line];
  if (closer == null) return keep;
  final inside = own + indentWidth;
  // The text with the closing line after the new one: kept only when it
  // pairs more blocks.
  final tried = [
    ...lines.take(line),
    ' ' * inside,
    '${' ' * own}$closer',
    ...lines.skip(line + 1),
  ].join('\n');
  final better = _unpaired(parse(tried)) < _unpaired(read);
  return (indentLine: null, newIndent: inside, closer: better ? closer : null);
}

int _indent(String line) => line.length - line.trimLeft().length;

/// Blocks never closed (P006) and closing lines with no block (P007).
int _unpaired(ParseResult read) => read.parserDiagnostics
    .where(
      (d) =>
          d.code == DiagnosticCode.unclosedBlock ||
          d.code == DiagnosticCode.unmatchedCloser,
    )
    .length;
