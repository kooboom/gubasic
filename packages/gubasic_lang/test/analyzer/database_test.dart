import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Database is checked from its component.yaml (docs/DESIGN.md D126): the
/// SQL and then any number of values that can go into SQL, Query as a
/// Table, and the warning for SQL joined with & (A060).
void main() {
  /// The codes of [body] in `Sub Main`: unused locals are not the point.
  List<String> codes(String body) =>
      inMain(body).where((c) => c != 'A026').toList();

  test('the SQL and then values of the kinds SQL takes', () {
    expect(codes('''
    Dim points As Integer = 3
    Dim n As Integer = Database.Execute("DELETE FROM t")
    n = Database.Execute("INSERT INTO t VALUES (?, ?, ?, ?, ?, ?)", "a", points, 2.5, True, #2026-03-01#, Nothing)
    Dim t As Table = Database.Query("SELECT * FROM t WHERE a = ?", "a")
    Dim s As String = Database.Scalar("SELECT COUNT(*) FROM t")
    Debug.Print(Database.Path & Database.LastWasNull & Database.LastId)
    Database.Open("scores.db")
    Database.Close()
    Debug.Print(t.Cell(0, "a"))
    '''), isEmpty);
  });

  test('values that cannot go into SQL, and the wrong count', () {
    expect(codes('''
    Dim j As Json = Json.Parse("{}")
    Database.Execute("INSERT INTO t VALUES (?)", j)
    '''), ['A008']);
    expect(codes('''
    Dim t As Table = Database.Query("SELECT 1")
    Database.Execute("INSERT INTO t VALUES (?)", t)
    '''), ['A008']);
    expect(codes('Database.Query()'), ['A015']);
    expect(codes('Database.Open()'), ['A015']);
    expect(codes('Database.Open("a.db", "b.db")'), ['A015']);
    expect(codes('Database.Close(1)'), ['A015']);
    // The results have their types.
    expect(codes('Dim s As String = Database.Query("SELECT 1")'), ['A008']);
    expect(codes('Database.Path = "x"'), isNotEmpty);
  });

  test('SQL put together with & is a warning (A060)', () {
    final program = compile('''
Sub Main()
    Dim name As String = "O'Brien"
    Database.Execute("DELETE FROM t WHERE name = '" & name & "'")
    Debug.Print(Database.Scalar("SELECT COUNT(*) FROM " & "t"))
    Debug.Print(Database.Scalar("SELECT COUNT(*) FROM t WHERE name = ?", name))
    Debug.Print(Database.Scalar("SELECT 1" & name))
    Dim sql As String = "SELECT " & name
    Debug.Print(Database.Scalar(sql))
End Sub
''');
    final warnings =
        program.diagnostics.where((d) => d.code == DiagnosticCode.sqlJoined);
    expect([for (final w in warnings) '${w.line}:${w.args}'],
        ['3:[Execute]', '6:[Scalar]']);
    expect(warnings.every((w) => !w.isError), isTrue);
    expect(program.hasErrors, isFalse);
    // Not for Http, whose address is often joined.
    expect(
        compile('Sub Main()\nDim u As String = "x"\n'
                'Debug.Print(Http.Get("https://a/" & u))\nEnd Sub\n')
            .diagnostics
            .where((d) => d.code == DiagnosticCode.sqlJoined),
        isEmpty);
  });

  test('other names point to GuBASIC\'s (A036)', () {
    expect(codes('Database.ExecuteNonQuery("DELETE FROM t")'), ['A036']);
    expect(
        codes('Dim t As Table = Database.OpenRecordset("SELECT 1")'), ['A036']);
  });

  test('Database is not a type, a control or a value', () {
    expect(codes('Dim d As Database'), ['A004']);
    expect(codes('Dim d As New Database'), isNotEmpty);
  });

  test('completion shows ParamArray values', () {
    final spec = builtinObjectMembers('Database')['execute']!;
    expect(spec.method!.isVariadic, isTrue);
    expect(spec.method!.requiredCount, 1);
    expect(spec.method!.parameters.last.kind, ArgKind.sqlValue);
    expect(spec.type, GbType.integer);
    expect(builtinObjectMembers('Database')['query']!.type, GbType.table);
    expect(builtinObjectMembers('Database').keys, [
      'path',
      'lastwasnull',
      'lastid',
      'open',
      'execute',
      'query',
      'scalar',
      'close'
    ]);
  });
}
