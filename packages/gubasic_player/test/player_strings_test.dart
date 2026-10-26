import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';

void main() {
  test('a run-time error reads the same in English and Korean as in the '
      'IDE: the file, the line, the message', () {
    final program = compile('Sub Form_Load()\n    x = \nEnd Sub\n');
    final error = program.diagnostics.firstWhere((d) => d.isError);
    expect(
      PlayerStrings.en.problem('Form1.gbas', error),
      startsWith('Form1.gbas, line 2: '),
    );
    expect(
      PlayerStrings.ko.problem('Form1.gbas', error),
      startsWith('Form1.gbas 파일 2번째 줄: '),
    );
  });
}
