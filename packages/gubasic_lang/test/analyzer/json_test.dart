import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Json and Http are checked like everything else (docs/DESIGN.md D125):
/// a Json is not a String or a number until it is taken out as one; the
/// members of Json, HttpResponse and Http come from their tables and
/// Http's component.yaml.
void main() {
  /// The errors of [body] in `Sub Main`: unused locals are not the point.
  List<String> codes(String body) =>
      inMain(body).where((c) => c != 'A026').toList();

  test('a Json is taken out with As…, CInt and the like, not assigned', () {
    expect(codes('''
    Dim j As Json = Json.Parse("{}")
    Dim n As Integer = j("age").AsInteger
    Dim s As String = j("name").AsString
    Dim d As Double = CDbl(j("x")) + j("y").AsDouble
    Dim b As Boolean = CBool(j("ok")) Or j("ok").AsBoolean
    Dim k As String = j.Kind & j.Count & j.Text & CStr(j)
    Dim keys() As String = j.Keys
    Dim inner As Json = j("a")(0)("b")
    Dim o As Object = j
    For Each item In j
        Debug.Print(item.Text)
    Next
    j("age") = 13
    j("name") = "Kim"
    j("x") = 2.5
    j("ok") = True
    j("none") = Nothing
    j("inner") = inner
    j(0) = "x"
    j.Add(1)
    j.Add(j)
    j.Remove("a")
    j.Remove(0)
    If j.Has("a") Then Debug.Print(1)
    Dim made As New Json
    Dim arr As Json = Json.Array()
    If j Is Nothing Then Debug.Print(2)
    Debug.Print(n & s & d & b & k & keys(0) & inner.Kind & made.Kind & arr.Kind)
    Debug.Print(o)
'''), isEmpty);
    expect(
        codes('Dim j As Json = Json.Parse("{}")\nDim n As Integer = j("age")'),
        ['A008']);
    expect(codes('Dim j As Json = Json.Parse("{}")\nDim s As String = j'),
        ['A008']);
    expect(codes('Dim j As Json = Json.Parse("{}")\nDebug.Print("a" & j)'),
        ['A013']);
    expect(
        codes('Dim j As Json = Json.Parse("{}")\nj("d") = Today()'), ['A008']);
    expect(codes('Dim j As Json = Json.Parse("{}")\nj.Add(Today())'), ['A008']);
    expect(codes('Dim j As Json = Json.Parse("{}")\nDebug.Print(j.Length)'),
        ['A019']);
    expect(codes('Dim j As Json = Json.Parse("{}")\nDebug.Print(j(1, 2))'),
        ['A015']);
    expect(codes('Dim j As Json = Json.Parse("{}")\nDebug.Print(j(True))'),
        ['A008']);
    expect(codes('Dim j As New Json(1)'), ['A015']);
    expect(codes('Debug.Print(CInt(Json.Array()))'), isEmpty);
  });

  test('Http is a built-in object with the members of its component.yaml', () {
    expect(codes('''
    Dim t As String = Http.Get("http://x/")
    Dim j As Json = Http.GetJson("http://x/")
    t = Http.Post("http://x/", "body")
    j = Http.PostJson("http://x/", j)
    Dim r As HttpResponse = Http.Send("GET", "http://x/", "")
    Debug.Print(r.Status & r.Ok & r.Text & r.Header("x") & r.Json.Kind)
    Http.Timeout = 10
    Debug.Print(Http.Timeout + 1)
    Http.Header("Accept") = "text/csv"
    Debug.Print(Http.Header("Accept"))
    Debug.Print(t & j.Kind)
'''), isEmpty);
    expect(codes('Http.Get(Json.Array())'), ['A008']);
    expect(codes('Http.Get("a", "b")'), ['A015']);
    expect(codes('Http.PostJson("a", "b")'), ['A008']);
    expect(codes('Http.Timeout = "a"'), ['A009']);
    expect(codes('Dim h As Http'), ['A004']);
    expect(codes('Dim h As New Http'), ['A004']);
    expect(codes('Debug.Print(Http.OpenURL("a"))'), ['A036']);
    expect(codes('Debug.Print(Http.Gets("a"))'), ['A035']);
  });

  test('a form file cannot hold an Http', () {
    final read = readFormFile('''
formatVersion: 1
controls:
  - { name: h, type: Http }
''', name: 'Form1');
    expect(read.diagnostics.map((d) => d.code.code), ['F008']);
  });
}
