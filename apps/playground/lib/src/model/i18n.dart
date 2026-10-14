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
  sampleReadme,
  sampleErrors,

  /// Label of the button that switches to the *other* language.
  switchLanguage,
  editorLabel,
  tabTokens,
  tabAst,
  tabDiagnostics,
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
  UiText.sampleReadme: 'README example',
  UiText.sampleErrors: 'Example with errors',
  UiText.switchLanguage: '한국어',
  UiText.editorLabel: 'GuBASIC source',
  UiText.tabTokens: 'Tokens',
  UiText.tabAst: 'AST',
  UiText.tabDiagnostics: 'Diagnostics',
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
  UiText.sampleReadme: 'README 예제',
  UiText.sampleErrors: '오류가 섞인 예제',
  UiText.switchLanguage: 'English',
  UiText.editorLabel: 'GuBASIC 소스',
  UiText.tabTokens: '토큰',
  UiText.tabAst: '구문 트리',
  UiText.tabDiagnostics: '진단',
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
