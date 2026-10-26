import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// The words of a running program, in English or Korean: the dialogs'
/// buttons, the diagnostic messages and the run window's own words. The
/// IDE's words include them, so a program says the same in the IDE and in
/// an exported app.
class PlayerStrings {
  const PlayerStrings({
    required this.runtime,
    required this.messages,
    required this.closeForm,
    required this.fitTip,
    required this.errorAt,
    required this.programEnded,
    required this.cannotStart,
    required this.bundleTooNew,
    required this.notABundle,
  });

  /// The words on MsgBox and InputBox.
  final GbStrings runtime;

  /// Diagnostic messages.
  final Map<DiagnosticCode, String> messages;

  /// The run window's close button.
  final String closeForm;

  /// The run window's switch that shrinks a large form to fit (D66).
  final String fitTip;

  /// `{0}` the file, `{1}` the line, `{2}` the message.
  final String errorAt;

  /// What a web app shows once its program has ended (D81): a browser tab
  /// cannot close itself.
  final String programEnded;

  /// Above the errors of a project that cannot start.
  final String cannotStart;

  /// The app's project was made by a newer GuBASIC, `{0}` (D83).
  final String bundleTooNew;

  /// The app's project file is damaged (D83).
  final String notABundle;

  /// [diagnostic] in [file], in this language.
  String problem(String file, Diagnostic diagnostic) => errorAt
      .replaceAll('{0}', file)
      .replaceAll('{1}', '${diagnostic.line}')
      .replaceAll('{2}', diagnostic.formatMessage(messages));

  static const en = PlayerStrings(
    runtime: GbStrings.en,
    messages: englishMessages,
    closeForm: 'Close',
    fitTip: 'Shrink a form larger than the space so that all of it shows; the form itself does not change',
    errorAt: '{0}, line {1}: {2}',
    programEnded: 'The program has ended.',
    cannotStart: 'The program cannot start because of these errors:',
    bundleTooNew:
        'This app\'s program was made with GuBASIC {0}, which is newer than '
        'this app. Export the app again with that GuBASIC.',
    notABundle:
        'This app\'s program file (project.gbz) is damaged. Export the app '
        'again.',
  );

  static const ko = PlayerStrings(
    runtime: GbStrings.ko,
    messages: koreanMessages,
    closeForm: '닫기',
    fitTip: '폼이 자리보다 크면 줄여서 다 보이게 합니다. 폼 자체는 바뀌지 않습니다',
    errorAt: '{0} 파일 {1}번째 줄: {2}',
    programEnded: '프로그램이 끝났습니다.',
    cannotStart: '다음 오류 때문에 프로그램을 시작할 수 없습니다.',
    bundleTooNew: '이 앱의 프로그램은 이 앱보다 새로운 GuBASIC {0} 버전으로 만들었습니다. 그 GuBASIC으로 앱을 다시 내보내 주세요.',
    notABundle: '이 앱의 프로그램 파일(project.gbz)이 손상되었습니다. 앱을 다시 내보내 주세요.',
  );
}
