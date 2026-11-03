import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Http is checked from its component.yaml (docs/DESIGN.md D125, D135):
/// Send's headers for one request, and the warning for a secret given to
/// Http.Header (A076).
void main() {
  /// The codes of [body] in `Sub Main`: unused locals are not the point.
  List<String> codes(String body) =>
      inMain(body).where((c) => c != 'A026').toList();

  test('Send takes any number of strings after the body', () {
    expect(codes('''
    Dim token As String = "abc"
    Dim r As HttpResponse = Http.Send("GET", "https://a/", "")
    r = Http.Send("GET", "https://a/", "", "Authorization: Bearer " & token)
    r = Http.Send("POST", "https://a/", "x=1", "X-One: 1", "X-Two: 2")
    '''), isEmpty);
    // A value converts to text as for any String parameter; a Json does not.
    expect(
        codes('Dim r As HttpResponse = Http.Send("GET", "https://a/", "", 5)'),
        isEmpty);
    expect(
        codes('Dim r As HttpResponse = '
            'Http.Send("GET", "https://a/", "", Json.Array())'),
        isNotEmpty);
    expect(codes('Dim r As HttpResponse = Http.Send("GET", "https://a/")'),
        isNotEmpty);
  });

  test('a secret given to Http.Header is a warning (A076)', () {
    final program = compile('''
Sub Main()
    Dim token As String = "abc"
    Http.Header("Authorization") = "Bearer " & token
    Http.Header("x-api-key") = token
    Http.Header("Cookie") = "session=1"
    Http.Header("Accept-Language") = "ko"
    Http.Header("Authorization") = ""
    Dim name As String = "Authorization"
    Http.Header(name) = token
    Debug.Print(Http.Header("Authorization"))
End Sub
''');
    final warnings =
        program.diagnostics.where((d) => d.code == DiagnosticCode.secretHeader);
    expect([for (final w in warnings) '${w.line}:${w.args}'],
        ['3:[Authorization]', '4:[x-api-key]', '5:[Cookie]']);
    expect(warnings.every((w) => !w.isError), isTrue);
    expect(program.hasErrors, isFalse);
  });
}
