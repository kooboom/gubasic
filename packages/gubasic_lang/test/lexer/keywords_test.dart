import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  test('every keyword is recognised in any case', () {
    for (final k in Keyword.values) {
      final s = k.spelling;
      final alternating = [
        for (var i = 0; i < s.length; i++)
          i.isEven ? s[i].toLowerCase() : s[i].toUpperCase(),
      ].join();
      for (final spelling in [
        s,
        s.toLowerCase(),
        s.toUpperCase(),
        alternating
      ]) {
        final token = lexClean(spelling).tokens.first;
        expect(token.kind, TokenKind.keyword, reason: spelling);
        expect(token.keyword, k, reason: spelling);
        expect(token.text, spelling, reason: 'original spelling is kept');
      }
    }
  });

  test('the keyword list matches LANGUAGE.md', () {
    expect(
        Keyword.values.where((k) => k.isSupported).map((k) => k.spelling),
        unorderedEquals('''
          Dim As Const Static Public Private Sub Function End Exit Return
          If Then ElseIf Else Select Case For To Step Each In Next Do Loop
          While Until Try Catch Finally Throw New Nothing True False Not And
          Or Xor Mod Me Handles ReDim Preserve Optional Of Is ByVal
          TypeOf CType AddHandler AddressOf
        '''
            .trim()
            .split(RegExp(r'\s+'))));
    expect(
        Keyword.values
            .where((k) => k.support == KeywordSupport.unsupported)
            .map((k) => k.spelling),
        unorderedEquals([
          'On', 'GoTo', 'GoSub', 'Variant', 'Class', //
          'AndAlso', 'OrElse', 'Wend', 'Call', 'Set', 'Let',
        ]));
    expect(
        Keyword.values
            .where((k) => k.support == KeywordSupport.plannedStage2)
            .toList(),
        [Keyword.kwByRef]);
  });

  test('unsupported keywords are still keyword tokens, without errors', () {
    final r = lexClean('On Error GoTo Fail');
    expect(r.tokens[0].keyword, Keyword.kwOn);
    expect(r.tokens[0].isKeyword(Keyword.kwOn), isTrue);
    expect(r.tokens[1].kind, TokenKind.identifier);
    expect(r.tokens[2].keyword, Keyword.kwGoTo);
    expect(r.tokens[2].keyword!.support, KeywordSupport.unsupported);
  });

  test('Is and ByVal are supported keywords', () {
    final r = lexClean('If x Is Nothing Then\nSub F(ByVal a As Integer)');
    expect(r.tokens[2].keyword, Keyword.kwIs);
    expect(Keyword.kwIs.isSupported, isTrue);
    expect(
        r.tokens.firstWhere((t) => t.text == 'ByVal').keyword, Keyword.kwByVal);
    expect(Keyword.kwByVal.isSupported, isTrue);
  });

  test('ByRef is recognised as planned for stage 2', () {
    final t = lexClean('byref').tokens.first;
    expect(t.keyword, Keyword.kwByRef);
    expect(t.keyword!.support, KeywordSupport.plannedStage2);
    expect(t.keyword!.isSupported, isFalse);
  });

  test('identifiers keep their original spelling', () {
    final r = lexClean('clickCount CLICKCOUNT clickcount');
    expect(r.tokens.take(3).map((t) => t.kind),
        everyElement(TokenKind.identifier));
    expect(textsOf('clickCount CLICKCOUNT clickcount'),
        ['clickCount', 'CLICKCOUNT', 'clickcount']);
  });

  test('identifiers may contain digits and underscores', () {
    expect(
        textsOf('btnHello_Click x1 a_b_2'), ['btnHello_Click', 'x1', 'a_b_2']);
    expect(
        kindsOf('btnHello_Click x1 a_b_2'), everyElement(TokenKind.identifier));
  });

  test('a word that merely starts with a keyword is an identifier', () {
    for (final word in ['Endless', 'Dimension', 'Ifx', 'Ending_', 'ToDo']) {
      expect(kindsOf(word), [TokenKind.identifier], reason: word);
    }
  });

  test('types and built-in functions are identifiers, not keywords', () {
    expect(kindsOf('Integer String MsgBox DoEvents'),
        everyElement(TokenKind.identifier));
  });
}
