import 'package:gubasic_lang/gubasic_lang.dart';

enum Locale {
  en('en', englishMessages),
  ko('ko', koreanMessages);

  const Locale(this.code, this.diagnosticMessages);

  /// BCP 47 code, used for `<html lang>`.
  final String code;
  final Map<DiagnosticCode, String> diagnosticMessages;

  Locale get other => this == en ? ko : en;

  static Locale fromCode(String? code) =>
      values.firstWhere((l) => l.code == code, orElse: () => en);
}

/// Every piece of text the playground shows.
enum UiText {
  title,

  /// The link to the IDE next to the playground (`ide/`).
  openIde,
  sampleStarter,
  sampleReadme,
  sampleErrors,

  /// Label of the button that switches to the *other* language.
  switchLanguage,
  editorLabel,
  tabTokens,
  tabAst,
  tabDiagnostics,
  tabRun,
  runButton,
  stopButton,
  runIdle,
  runRunning,
  runCompleted,
  runEnded,
  runStopped,
  runFailed,
  runNoStart,
  showProblems,
  dialogOk,
  dialogCancel,
  columnPosition,
  columnKind,
  columnText,
  columnValue,
  tagUnsupported,
  tagStage2,
  noDiagnostics,
  severityError,
  severityWarning,
  diagnosticsOnLine,
  footerPreview,
  footerRepository,
}

const _en = {
  UiText.title: 'GuBASIC Playground',
  UiText.openIde: 'Open the IDE: draw forms and run them →',
  UiText.sampleStarter: 'Starter example',
  UiText.sampleReadme: 'README example',
  UiText.sampleErrors: 'Example with errors',
  UiText.switchLanguage: '한국어',
  UiText.editorLabel: 'GuBASIC source',
  UiText.tabTokens: 'Tokens',
  UiText.tabAst: 'AST',
  UiText.tabDiagnostics: 'Diagnostics',
  UiText.tabRun: 'Run',
  UiText.runButton: '▶ Run',
  UiText.stopButton: '■ Stop',
  UiText.runIdle: 'Press Run to start the program (Ctrl+Enter).',
  UiText.runRunning: 'Running…',
  UiText.runCompleted: 'Finished.',
  UiText.runEnded: 'Ended by an End statement.',
  UiText.runStopped: 'Stopped.',
  UiText.runFailed: 'Stopped by an error. Click it to see the line.',
  UiText.runNoStart: 'Add Sub Main() to run the program.',
  UiText.showProblems: 'Show problems',
  UiText.dialogOk: 'OK',
  UiText.dialogCancel: 'Cancel',
  UiText.columnPosition: 'Line:Col',
  UiText.columnKind: 'Kind',
  UiText.columnText: 'Text',
  UiText.columnValue: 'Value',
  UiText.tagUnsupported: 'not supported',
  UiText.tagStage2: 'stage 2',
  UiText.noDiagnostics: 'No problems found.',
  UiText.severityError: 'Error',
  UiText.severityWarning: 'Warning',
  UiText.diagnosticsOnLine: 'Problems on this line',
  UiText.footerPreview: 'GuBASIC Playground — development preview',
  UiText.footerRepository: 'Source on GitHub',
};

const _ko = {
  UiText.title: 'GuBASIC 놀이터',
  UiText.openIde: 'IDE 열기: 폼을 그리고 실행하기 →',
  UiText.sampleStarter: '기본 예제',
  UiText.sampleReadme: 'README 예제',
  UiText.sampleErrors: '오류가 섞인 예제',
  UiText.switchLanguage: 'English',
  UiText.editorLabel: 'GuBASIC 소스',
  UiText.tabTokens: '토큰',
  UiText.tabAst: '구문 트리',
  UiText.tabDiagnostics: '진단',
  UiText.tabRun: '실행',
  UiText.runButton: '▶ 실행',
  UiText.stopButton: '■ 중지',
  UiText.runIdle: '실행을 누르면 프로그램이 시작됩니다 (Ctrl+Enter).',
  UiText.runRunning: '실행 중…',
  UiText.runCompleted: '끝났습니다.',
  UiText.runEnded: 'End 문으로 끝났습니다.',
  UiText.runStopped: '중지했습니다.',
  UiText.runFailed: '오류로 멈췄습니다. 오류를 누르면 그 줄로 갑니다.',
  UiText.runNoStart: '실행하려면 Sub Main()을 만들어 주세요.',
  UiText.showProblems: '문제 보기',
  UiText.dialogOk: '확인',
  UiText.dialogCancel: '취소',
  UiText.columnPosition: '줄:칸',
  UiText.columnKind: '종류',
  UiText.columnText: '원문',
  UiText.columnValue: '값',
  UiText.tagUnsupported: '지원 안 함',
  UiText.tagStage2: '2단계 예정',
  UiText.noDiagnostics: '문제가 없습니다.',
  UiText.severityError: '오류',
  UiText.severityWarning: '경고',
  UiText.diagnosticsOnLine: '이 줄의 문제',
  UiText.footerPreview: 'GuBASIC 놀이터 — 개발 미리보기',
  UiText.footerRepository: 'GitHub 저장소',
};

const Map<Locale, Map<UiText, String>> uiTexts = {
  Locale.en: _en,
  Locale.ko: _ko,
};

extension LocaleText on Locale {
  String operator [](UiText key) => uiTexts[this]![key]!;
}

/// "2 errors · 1 warning" / "오류 2 · 경고 1". Kinds with no diagnostics
/// are left out; returns an empty string when there are none at all.
String diagnosticSummary(Locale locale, int errors, int warnings) {
  String part(int n, String one, String many, String ko) => switch (locale) {
        Locale.en => '$n ${n == 1 ? one : many}',
        Locale.ko => '$ko $n',
      };
  return [
    if (errors > 0) part(errors, 'error', 'errors', '오류'),
    if (warnings > 0) part(warnings, 'warning', 'warnings', '경고'),
  ].join(' · ');
}

/// Why Run is disabled: "Fix 3 errors first …" / "오류 3개를 먼저 …".
String runBlockedText(Locale locale, int errors) => switch (locale) {
      Locale.en => 'Fix ${errors == 1 ? 'the error' : 'the $errors errors'} '
          'first: a program with errors cannot run (warnings are fine).',
      Locale.ko => '오류 $errors개를 먼저 고쳐 주세요. 오류가 있으면 실행할 수 없습니다(경고는 괜찮습니다).',
    };
