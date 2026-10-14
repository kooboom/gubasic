import 'dart:math';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// Pieces that random sources are built from: valid code, broken code,
/// and characters that tend to break lexers.
const _pieces = [
  'Dim',
  'x',
  ' ',
  '\t',
  '\n',
  '\r\n',
  '\r',
  '"',
  '""',
  "'",
  'REM ',
  '_',
  ' _\n',
  ':',
  '.',
  '1',
  '1.5',
  '99999999999999999999',
  '<',
  '>',
  '=',
  '<>',
  '점수',
  '😀',
  '\uD800',
  '﻿',
  '\u0000',
  '@',
  '#',
  '(',
  ')',
  ',',
  'If',
  'End Sub',
  '&',
  r'\',
  '^',
  'Ω',
  '　',
];

void main() {
  test('random input never throws and always keeps the invariants', () {
    final random = Random(20261014);
    for (var i = 0; i < 1000; i++) {
      final length = random.nextInt(40);
      final src = [
        for (var j = 0; j < length; j++)
          _pieces[random.nextInt(_pieces.length)],
      ].join();

      final LexResult r;
      try {
        r = lex(src);
      } catch (e) {
        fail('lex threw $e on ${_show(src)}');
      }

      expect(r.tokens.last.kind, TokenKind.eof, reason: _show(src));
      expect(r.tokens.where((t) => t.kind == TokenKind.eof).length, 1);
      var previousEnd = 0;
      TokenKind? previousKind;
      for (final t in r.tokens) {
        expect(src.substring(t.offset, t.end), t.text, reason: _show(src));
        expect(t.offset, greaterThanOrEqualTo(previousEnd));
        expect(t.line, greaterThanOrEqualTo(1));
        expect(t.column, greaterThanOrEqualTo(1));
        if (t.kind == TokenKind.newline) {
          expect(previousKind, isNot(TokenKind.newline), reason: _show(src));
          expect(previousKind, isNotNull, reason: 'no leading newline');
        }
        previousEnd = t.end;
        previousKind = t.kind;
      }
      for (final d in r.diagnostics) {
        expect(d.offset + d.length, lessThanOrEqualTo(src.length));
        expect(d.message, isNotEmpty);
      }
    }
  });
}

String _show(String s) => s.codeUnits
    .map((c) => c >= 0x20 && c < 0x7F
        ? String.fromCharCode(c)
        : '\\u{${c.toRadixString(16)}}')
    .join();
