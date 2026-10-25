import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

void main() {
  test('exactly these codes are warnings; every other code is an error', () {
    const warnings = {
      DiagnosticCode.doubleBecomesZero,
      DiagnosticCode.unusedLocal,
      DiagnosticCode.functionWithoutReturn,
      DiagnosticCode.localHidesField,
      DiagnosticCode.localHidesControl,
      DiagnosticCode.unknownKey,
      // The line may never run, and the picture may be added later (D51).
      DiagnosticCode.unknownPictureInCode,
      // The line may never run, as for a picture (D57).
      DiagnosticCode.badAnchorInCode,
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

  test('hasErrors counts errors only', () {
    final warningOnly = compile('Sub A()\nDim unused As Integer\nEnd Sub');
    expect(warningOnly.diagnostics.map((d) => d.code.code), ['A026']);
    expect(warningOnly.hasErrors, isFalse);

    expect(lex('x = "open').hasErrors, isTrue);
    expect(parse('Sub A()\nx = 1 +\nEnd Sub').hasErrors, isTrue,
        reason: 'parser errors count too');
    expect(compile('Sub A()\nDebug.Print(nope)\nEnd Sub').hasErrors, isTrue,
        reason: 'analyzer errors count too');
    expect(compile('Sub A()\nEnd Sub').hasErrors, isFalse);
  });

  test('a warning does not hide errors', () {
    final r = compile(
        'Sub A()\nDim unused As Integer\nDim x As Integer\nx = 1 +\nEnd Sub');
    expect(r.diagnostics.map((d) => d.code.code), ['A026', 'P001']);
  });
}
