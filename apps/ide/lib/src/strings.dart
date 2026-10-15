import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// The IDE's words, in English and Korean.
class IdeStrings {
  const IdeStrings({
    required this.runtime,
    required this.messages,
    required this.run,
    required this.stop,
    required this.closeForm,
    required this.files,
    required this.runWindow,
    required this.output,
    required this.cannotStart,
    required this.closed,
    required this.ended,
    required this.stopped,
    required this.errorAt,
  });

  /// The words on MsgBox and InputBox.
  final GbStrings runtime;

  /// Diagnostic messages.
  final Map<DiagnosticCode, String> messages;

  final String run;
  final String stop;
  final String closeForm;
  final String files;

  /// The file list's entry that goes back to the running program.
  final String runWindow;
  final String output;
  final String cannotStart;
  final String closed;
  final String ended;
  final String stopped;

  /// `{0}` the file, `{1}` the line, `{2}` the message.
  final String errorAt;

  /// [diagnostic] in [file], in this language.
  String problem(String file, Diagnostic diagnostic) => errorAt
      .replaceAll('{0}', file)
      .replaceAll('{1}', '${diagnostic.line}')
      .replaceAll('{2}', diagnostic.formatMessage(messages));

  static const en = IdeStrings(
    runtime: GbStrings.en,
    messages: englishMessages,
    run: 'Run',
    stop: 'Stop',
    closeForm: 'Close',
    files: 'Files',
    runWindow: 'Run window',
    output: 'Output',
    cannotStart:
        'The program cannot start because of the errors below. '
        'Fix them, then run it again.',
    closed: 'The program ended: its form was closed.',
    ended: 'The program ended at End.',
    stopped: 'The program was stopped.',
    errorAt: '{0}, line {1}: {2}',
  );

  static const ko = IdeStrings(
    runtime: GbStrings.ko,
    messages: koreanMessages,
    run: '실행',
    stop: '중지',
    closeForm: '닫기',
    files: '파일',
    runWindow: '실행 화면',
    output: '출력',
    cannotStart: '아래 오류 때문에 프로그램을 시작할 수 없습니다. 오류를 고친 뒤 다시 실행합니다.',
    closed: '폼을 닫아서 프로그램이 끝났습니다.',
    ended: 'End 문에서 프로그램이 끝났습니다.',
    stopped: '프로그램을 중지했습니다.',
    errorAt: '{0} 파일 {1}번째 줄: {2}',
  );

  /// Korean when the system language is Korean, else English.
  static IdeStrings forLanguage(String languageCode) =>
      languageCode == 'ko' ? ko : en;
}
