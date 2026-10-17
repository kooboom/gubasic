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
    required this.saveAsTitle,
    required this.projectName,
    required this.downloadZip,
    required this.uploadZip,
    required this.changedSinceDownloadHint,
    required this.keptStatus,
    required this.exampleStatus,
    required this.none,
    required this.keptInBrowser,
    required this.browserNotice,
    required this.storageFailed,
    required this.keptProjectsTitle,
    required this.noKeptProjects,
    required this.keptAt,
    required this.notDownloaded,
    required this.deleteProject,
    required this.confirmDelete,
    required this.projectExistsInBrowser,
    required this.notAZip,
    required this.zipTooLarge,
    required this.unsafeZipPath,
    required this.zipLayout,
    required this.zipProjectFiles,
    required this.zipNotText,
    required this.zipIgnored,
    required this.pointerTool,
    required this.pointerTip,
    required this.placeTip,
    required this.undo,
    required this.redo,
    required this.grid,
    required this.gridTip,
    required this.viewFormFile,
    required this.viewDesigner,
    required this.lockedWhileRunning,
    required this.formHasErrors,
    required this.properties,
    required this.integerRange,
    required this.numberNeeded,
    required this.formNameIsFile,
    required this.nameUsedInCode,
    required this.badName,
    required this.nameTaken,
    required this.nameInCode,
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

  // Projects kept in the browser, and .zip files (D33).
  final String saveAsTitle;
  final String projectName;
  final String downloadZip;
  final String uploadZip;
  final String changedSinceDownloadHint;

  /// `{0}` the time of the last download, or [none].
  final String keptStatus;
  final String exampleStatus;
  final String none;
  final String keptInBrowser;
  final String browserNotice;
  final String storageFailed;
  final String keptProjectsTitle;
  final String noKeptProjects;

  /// `{0}` the time.
  final String keptAt;
  final String notDownloaded;
  final String deleteProject;

  /// `{0}` the project.
  final String confirmDelete;

  /// `{0}` the name.
  final String projectExistsInBrowser;
  final String notAZip;
  final String zipTooLarge;

  /// `{0}` the path.
  final String unsafeZipPath;
  final String zipLayout;

  /// `{0}` the .gbproj files, or [none].
  final String zipProjectFiles;

  /// `{0}` the file.
  final String zipNotText;

  /// `{0}` the files.
  final String zipIgnored;

  // The form designer (D34).
  final String pointerTool;
  final String pointerTip;

  /// `{0}` the control type.
  final String placeTip;
  final String undo;
  final String redo;
  final String grid;
  final String gridTip;
  final String viewFormFile;
  final String viewDesigner;
  final String lockedWhileRunning;
  final String formHasErrors;

  // The Properties window (D35).
  final String properties;

  /// `{0}` the property, `{1}` the smallest value, `{2}` the largest.
  final String integerRange;

  /// `{0}` the property.
  final String numberNeeded;
  final String formNameIsFile;

  /// `{0}` the control, `{1}` the code file, `{2}` the lines.
  final String nameUsedInCode;

  /// `{0}` the name typed.
  final String badName;

  /// `{0}` the name typed.
  final String nameTaken;

  /// `{0}` the name typed, `{1}` the code file, `{2}` the lines.
  final String nameInCode;

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
    exampleIsReadOnly: 'Examples are not overwritten. Save your changes as a project of your own.',
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
    saveAsTitle: 'Save As',
    projectName: 'Project name',
    downloadZip: 'Download .zip',
    uploadZip: 'Upload .zip…',
    changedSinceDownloadHint:
        'Changed since the last download. Download a .zip to keep it safe.',
    keptStatus: 'Kept in this browser · last download: {0}',
    exampleStatus: 'Example · Save keeps a copy in this browser',
    none: 'none',
    keptInBrowser: 'Kept in this browser.',
    browserNotice: 'This project is kept only in this browser. On a computer whose browser data is cleared, such as a shared school PC, it can be lost, and Safari removes it after 7 days without a visit. Download it as a .zip at the end of each lesson.',
    storageFailed: 'The project could not be kept in this browser: its storage is full or turned off. Download it as a .zip so that nothing is lost.',
    keptProjectsTitle: 'Projects in this browser',
    noKeptProjects: 'No projects are kept in this browser yet.',
    keptAt: 'kept {0}',
    notDownloaded: 'changes not downloaded',
    deleteProject: 'Delete',
    confirmDelete: 'Delete the project {0} from this browser? This cannot be undone. If you may need it, download it as a .zip first.',
    projectExistsInBrowser: 'A project named {0} is already kept in this browser. Enter another name.',
    notAZip: 'This is not a .zip file, or the file is damaged.',
    zipTooLarge: 'This .zip is too large for a GuBASIC project: at most 1 MB, 100 files and 2 MB unpacked.',
    unsafeZipPath: 'The .zip has a file with an unsafe path ({0}): it is absolute or goes up with "..". Nothing was taken from it.',
    zipLayout: 'The project\'s files must be at the top of the .zip or in one folder there.',
    zipProjectFiles:
        'A .zip must hold exactly one .gbproj file. It holds: {0}.',
    zipNotText: 'The file {0} in the .zip is not UTF-8 text.',
    zipIgnored: 'These files are not GuBASIC files and were left out: {0}',
    pointerTool: 'Pointer',
    pointerTip: 'Select a control on the form.',
    placeTip: 'Drag on the form to draw a {0}, or click for the default size. Double-click here to put one in the middle of the form.',
    undo: 'Undo',
    redo: 'Redo',
    grid: 'Grid',
    gridTip: 'With the grid on, controls are placed and sized in steps of 8.',
    viewFormFile: 'View form file',
    viewDesigner: 'View designer',
    lockedWhileRunning: 'The form cannot be changed while the program runs. Stop it (Shift+F5) to change it.',
    formHasErrors: 'This form file has errors, so the designer only shows it: changing it would drop what could not be read. Fix the file in a text editor, then open the project again.',
    properties: 'Properties',
    integerRange: '{0} takes a whole number from {1} to {2}.',
    numberNeeded: '{0} takes a number, such as 1.5.',
    formNameIsFile: 'A form is named after its file. Renaming a form comes with several forms in one project (stage 2).',
    nameUsedInCode: '{0} is used in {1} on lines {2}, so it cannot be renamed here. Change those lines first. Renaming the code together with the control comes with the code editor.',
    badName: '"{0}" cannot be a name. A name starts with an English letter and has only English letters, digits and _; it cannot be a keyword or Form.',
    nameTaken: 'Another control is already named {0}. Choose another name.',
    nameInCode: '{0} is already used in {1} on lines {2}. Renaming the control to it would change what the code means. Choose another name.',
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
    exampleIsReadOnly: '예제는 덮어쓰지 않습니다. 바꾼 내용은 내 프로젝트로 복사본을 저장합니다.',
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
    saveAsTitle: '다른 이름으로 저장',
    projectName: '프로젝트 이름',
    downloadZip: '.zip으로 내려받기',
    uploadZip: '.zip 올리기…',
    changedSinceDownloadHint:
        '마지막으로 내려받은 뒤 바뀐 내용이 있습니다. 안전하게 보관하려면 .zip으로 내려받습니다.',
    keptStatus: '이 브라우저에 보관 중 · 마지막 내려받기: {0}',
    exampleStatus: '예제 · 저장하면 이 브라우저에 복사본을 보관합니다',
    none: '없음',
    keptInBrowser: '이 브라우저에 보관했습니다.',
    browserNotice: '이 프로젝트는 이 브라우저에만 보관됩니다. 학교 공용 PC처럼 브라우저 기록이 지워지는 컴퓨터에서는 사라질 수 있고, Safari는 7일 동안 방문하지 않으면 지웁니다. 수업이 끝날 때마다 .zip으로 내려받습니다.',
    storageFailed:
        '이 브라우저에 프로젝트를 보관할 수 없습니다. 저장소가 가득 찼거나 꺼져 있습니다. 잃지 않도록 .zip으로 내려받습니다.',
    keptProjectsTitle: '이 브라우저의 프로젝트',
    noKeptProjects: '이 브라우저에 보관된 프로젝트가 아직 없습니다.',
    keptAt: '{0} 보관',
    notDownloaded: '내려받지 않은 변경 있음',
    deleteProject: '지우기',
    confirmDelete:
        '{0} 프로젝트를 이 브라우저에서 지웁니까? 되돌릴 수 없습니다. 다시 쓸 수도 있다면 먼저 .zip으로 내려받습니다.',
    projectExistsInBrowser: '이 브라우저에 {0} 프로젝트가 이미 있습니다. 다른 이름을 입력합니다.',
    notAZip: '.zip 파일이 아니거나 망가진 파일입니다.',
    zipTooLarge:
        '이 .zip 파일은 GuBASIC 프로젝트로 보기에 너무 큽니다. 최대 1MB, 파일 100개, 풀었을 때 2MB까지입니다.',
    unsafeZipPath: '.zip 안에 안전하지 않은 경로의 파일이 있습니다({0}). 절대 경로이거나 ".."로 위 폴더를 가리킵니다. 아무것도 가져오지 않았습니다.',
    zipLayout: '프로젝트 파일은 .zip의 맨 위나 그 바로 아래 폴더 하나 안에 있어야 합니다.',
    zipProjectFiles: '.zip에는 .gbproj 파일이 하나만 있어야 합니다. 들어 있는 것: {0}.',
    zipNotText: '.zip 안의 {0} 파일은 UTF-8 텍스트가 아닙니다.',
    zipIgnored: '다음 파일은 GuBASIC 파일이 아니라서 넣지 않았습니다: {0}',
    pointerTool: '포인터',
    pointerTip: '폼 위의 컨트롤을 선택합니다.',
    placeTip:
        '폼 위에서 끌어 {0} 컨트롤을 그리거나, 클릭해서 기본 크기로 놓습니다. 여기를 더블클릭하면 폼 가운데에 놓습니다.',
    undo: '되돌리기',
    redo: '다시 하기',
    grid: '격자',
    gridTip: '격자를 켜면 컨트롤을 8 단위로 놓고 크기를 맞춥니다.',
    viewFormFile: '폼 파일 보기',
    viewDesigner: '그리기 화면 보기',
    lockedWhileRunning: '프로그램이 실행되는 동안에는 폼을 고칠 수 없습니다. 고치려면 중지(Shift+F5)합니다.',
    formHasErrors: '이 폼 파일에는 오류가 있어서 그리기 화면에서 보기만 합니다. 고치면 읽지 못한 부분이 사라지기 때문입니다. 텍스트 편집기로 파일을 고친 뒤 프로젝트를 다시 엽니다.',
    properties: '속성',
    integerRange: '{0} 속성에는 정수만 쓸 수 있습니다. 범위: {1} ~ {2}',
    numberNeeded: '{0} 속성에는 1.5 같은 숫자만 쓸 수 있습니다.',
    formNameIsFile: '폼 이름은 파일 이름입니다. 폼 이름 바꾸기는 한 프로젝트에 폼을 여러 개 두는 2단계에서 합니다.',
    nameUsedInCode: '{0} 컨트롤 이름은 {1} 파일의 {2}번째 줄에서 쓰이므로 여기서 바꿀 수 없습니다. 먼저 코드의 그 줄을 고칩니다. 컨트롤과 함께 코드의 이름까지 바꾸는 기능은 코드 편집기와 함께 들어옵니다.',
    badName: '"{0}" 문자열은 이름으로 쓸 수 없습니다. 이름은 영문자로 시작하고 영문자, 숫자, _만 쓸 수 있으며, 키워드나 Form은 쓸 수 없습니다.',
    nameTaken: '{0} 이름의 컨트롤이 이미 있습니다. 다른 이름을 입력합니다.',
    nameInCode: '{0} 이름은 이미 {1} 파일의 {2}번째 줄에서 쓰입니다. 컨트롤을 이 이름으로 바꾸면 코드의 뜻이 바뀝니다. 다른 이름을 입력합니다.',
  );

  /// Korean when the system language is Korean, else English.
  static IdeStrings forLanguage(String languageCode) =>
      languageCode == 'ko' ? ko : en;
}
