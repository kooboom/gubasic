import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:gubasic_player/bench.dart';
import 'package:gubasic_player/gubasic_player.dart';

/// The benchmarks of STAGE2_PLAN §7 stay programs that run: each compiles,
/// and its script drives it to the end, through the interpreter alone.
void main() {
  for (final name in benchFiles.keys) {
    test('$name compiles and its script runs', () async {
      final project = Project.read(benchFiles[name]!);
      expect([
        for (final d in project.diagnostics)
          if (d.diagnostic.isError) d,
      ], isEmpty);
      final startup = project.startup!;
      final transcript = await runEventScript(
        project.files[startup.codeFile]!,
        startup.form,
        benchScripts[name]!,
        pictures: benchPictures[name]!.keys.toList(),
      );
      expect(transcript.last, anyOf('Closed', 'Ended'));
      // The game waits in DoEvents every round, which lets a script go on,
      // so here it is only started; the probe waits for its end.
      final mark = switch (name) {
        'loop' || 'text' => 'bench:end',
        'game' => 'bench:start',
        _ => null,
      };
      if (mark != null) {
        expect(transcript.any((l) => l.contains(mark)), isTrue);
      }
    });
  }
}
