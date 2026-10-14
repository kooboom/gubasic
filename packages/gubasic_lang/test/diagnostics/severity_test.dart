import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

void main() {
  test('exactly these codes are warnings; every other code is an error', () {
    const warnings = {
      DiagnosticCode.integerInexactOnWeb,
      DiagnosticCode.unusedLocal,
      DiagnosticCode.functionWithoutReturn,
      DiagnosticCode.localHidesField,
    };
    for (final code in DiagnosticCode.values) {
      expect(
          code.severity,
          warnings.contains(code)
              ? DiagnosticSeverity.warning
              : DiagnosticSeverity.error,
          reason: code.code);
    }
  });

  test('hasErrors counts errors only, for lexing and parsing', () {
    const warningOnly = 'Sub A()\nid = 1234567890123456789\nEnd Sub';
    expect(lex(warningOnly).hasErrors, isFalse);
    final parsed = parse(warningOnly);
    expect(parsed.diagnostics.map((d) => d.code.code), ['L007']);
    expect(parsed.hasErrors, isFalse);

    expect(lex('x = "open').hasErrors, isTrue);
    expect(parse('Sub A()\nx = 1 +\nEnd Sub').hasErrors, isTrue,
        reason: 'parser errors count too');
    expect(parse('Sub A()\nEnd Sub').hasErrors, isFalse);
  });

  test('a warning does not silence parser errors on its line', () {
    final r = parse('Sub A()\nx = 1234567890123456789 +\nEnd Sub');
    expect(r.diagnostics.map((d) => d.code.code), ['L007', 'P001']);
  });
}
