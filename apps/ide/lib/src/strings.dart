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
    required this.fileMenu,
    required this.open,
    required this.save,
    required this.saveAs,
    required this.saveButton,
    required this.dontSave,
    required this.overwrite,
    required this.saved,
    required this.unsaved,
    required this.changedOnDisk,
    required this.exampleIsReadOnly,
    required this.badProjectName,
    required this.folderExists,
    required this.missingFiles,
    required this.cannotRead,
    required this.cannotWrite,
    required this.notText,
    required this.openButton,
    required this.saveCopyButton,
    required this.nothingToSave,
    required this.edited,
  });

  /// The words on MsgBox and InputBox.
  final GbStrings runtime;

  /// Diagnostic messages.
  final Map<DiagnosticCode, String> messages;

  final String run;
  final String stop;
  final String closeForm;

  /// The heading of the file list: the files of the project.
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

  // Opening and saving projects (D32).
  final String fileMenu;
  final String open;
  final String save;
  final String saveAs;

  /// The buttons of the dialogs about saving.
  final String saveButton;
  final String dontSave;
  final String overwrite;

  /// `{0}` the folder.
  final String saved;

  /// `{0}` the project.
  final String unsaved;

  /// `{0}` the files.
  final String changedOnDisk;
  final String exampleIsReadOnly;

  final String badProjectName;

  /// `{0}` the name.
  final String folderExists;

  /// `{0}` the files.
  final String missingFiles;

  /// `{0}` the file, `{1}` the reason.
  final String cannotRead;

  /// `{0}` the file, `{1}` the reason.
  final String cannotWrite;

  /// The reason when a file is not UTF-8 text.
  final String notText;
  final String openButton;
  final String saveCopyButton;
  final String nothingToSave;

  /// After the project's name while it has unsaved changes.
  final String edited;

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
    files: 'Project',
    runWindow: 'Run window',
    output: 'Output',
    cannotStart:
        'The program cannot start because of the errors below. '
        'Fix them, then run it again.',
    closed: 'The program ended: its form was closed.',
    ended: 'The program ended at End.',
    stopped: 'The program was stopped.',
    errorAt: '{0}, line {1}: {2}',
    fileMenu: 'File',
    open: 'Open…',
    save: 'Save',
    saveAs: 'Save As…',
    saveButton: 'Save',
    dontSave: 'Don\'t Save',
    overwrite: 'Overwrite',
    saved: 'Saved in {0}.',
    unsaved: 'The project {0} has changes that are not saved. Save them? If you do not, they are lost.',
    changedOnDisk: 'These files were changed outside GuBASIC after they were opened: {0}. Saving replaces them with what the IDE has.',
    exampleIsReadOnly:
        'Examples cannot be changed. Save a copy as a project of your own.',
    badProjectName: 'A project name cannot be empty, start or end with a space, or contain a dot or / \\ : * ? " < > |. Save again with another name.',
    folderExists: 'A folder named {0} is already there. GuBASIC does not overwrite an existing project, even when the save dialog asked to replace it. Save again with another name.',
    missingFiles: 'The project folder does not have these files: {0}. Add them, or remove their form from the .gbproj file.',
    cannotRead: 'The file {0} cannot be read: {1}',
    cannotWrite: 'The file {0} cannot be saved: {1}',
    notText: 'it is not UTF-8 text.',
    openButton: 'Open',
    saveCopyButton: 'Save a Copy',
    nothingToSave: 'There are no changes to save.',
    edited: 'Edited',
  );

  static const ko = IdeStrings(
    runtime: GbStrings.ko,
    messages: koreanMessages,
    run: '실행',
    stop: '중지',
    closeForm: '닫기',
    files: '프로젝트',
    runWindow: '실행 화면',
    output: '출력',
    cannotStart: '아래 오류 때문에 프로그램을 시작할 수 없습니다. 오류를 고친 뒤 다시 실행합니다.',
    closed: '폼을 닫아서 프로그램이 끝났습니다.',
    ended: 'End 문에서 프로그램이 끝났습니다.',
    stopped: '프로그램을 중지했습니다.',
    errorAt: '{0} 파일 {1}번째 줄: {2}',
    fileMenu: '파일',
    open: '열기…',
    save: '저장',
    saveAs: '다른 이름으로 저장…',
    saveButton: '저장',
    dontSave: '저장 안 함',
    overwrite: '덮어쓰기',
    saved: '{0} 폴더에 저장했습니다.',
    unsaved: '{0} 프로젝트에 저장하지 않은 변경이 있습니다. 저장합니까? 저장하지 않으면 변경은 사라집니다.',
    changedOnDisk:
        '다음 파일은 연 뒤에 GuBASIC 밖에서 바뀌었습니다: {0}. 저장하면 IDE에 있는 내용으로 바뀝니다.',
    exampleIsReadOnly: '예제는 바꿀 수 없습니다. 내 프로젝트로 복사본을 저장합니다.',
    badProjectName: '프로젝트 이름은 비워 둘 수 없고, 공백으로 시작하거나 끝날 수 없으며, 점(.)과 / \\ : * ? " < > | 문자를 쓸 수 없습니다. 다른 이름을 입력해 다시 저장합니다.',
    folderExists: '그 자리에 {0} 폴더가 이미 있습니다. GuBASIC은 이미 있는 프로젝트를 덮어쓰지 않습니다(저장 창에서 대치를 눌렀더라도 그렇습니다). 다른 이름을 입력해 다시 저장합니다.',
    missingFiles: '프로젝트 폴더에 다음 파일이 없습니다: {0}. 파일을 넣거나, .gbproj 파일에서 그 폼을 뺍니다.',
    cannotRead: '{0} 파일을 읽을 수 없습니다: {1}',
    cannotWrite: '{0} 파일을 저장할 수 없습니다: {1}',
    notText: 'UTF-8 텍스트 파일이 아닙니다.',
    openButton: '열기',
    saveCopyButton: '복사본 저장',
    nothingToSave: '바뀐 내용이 없어서 저장할 것이 없습니다.',
    edited: '편집됨',
  );

  /// Korean when the system language is Korean, else English.
  static IdeStrings forLanguage(String languageCode) =>
      languageCode == 'ko' ? ko : en;
}
