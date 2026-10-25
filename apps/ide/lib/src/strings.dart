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
    required this.lastProjectGone,
    required this.newProject,
    required this.newProjectTitle,
    required this.formCaption,
    required this.formSizeLabel,
    required this.createButton,
    required this.edited,
    required this.saveAsTitle,
    required this.projectName,
    required this.downloadZip,
    required this.uploadZip,
    required this.openPlayground,
    required this.clearSettings,
    required this.clearSettingsQuestion,
    required this.clearSettingsYes,
    required this.settingsCleared,
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
    required this.deleteUsedControl,
    required this.deleteHandlersStay,
    required this.deleteUndo,
    required this.deleteControl,
    required this.badName,
    required this.nameTaken,
    required this.nameInCode,
    required this.generalObject,
    required this.declarations,
    required this.objectList,
    required this.eventList,
    required this.didYouMean,
    required this.completionKinds,
    required this.readOnlyProperty,
    required this.noHandlerWhileRunning,
    required this.goToLine,
    required this.viewCode,
    required this.bringToFront,
    required this.sendToBack,
    required this.delete,
    required this.picturesMenu,
    required this.picturesTitle,
    required this.noPictures,
    required this.addPicture,
    required this.addButton,
    required this.removePicture,
    required this.noPicture,
    required this.noAnchor,
    required this.formSize,
    required this.phonePreset,
    required this.tabletPreset,
    required this.desktopPreset,
    required this.turnForm,
    required this.anchorTips,
    required this.confirmRemovePicture,
    required this.pictureInUse,
    required this.replacePicture,
    required this.replaceButton,
    required this.missingPictures,
    required this.pictureProjectFileErrors,
    required this.pictureNameTooLong,
    required this.pictureNameCharacters,
    required this.pictureNotTaken,
    required this.pictureIsHeic,
    required this.pictureTooLarge,
    required this.pictureTooWide,
    required this.reduceButton,
    required this.reduceOffer,
    required this.reduceFirstFrameOnly,
    required this.reducing,
    required this.pictureReduced,
    required this.reduceFailed,
    required this.picturesFull,
    required this.restoredUnsaved,
    required this.missingPicturesKept,
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

  /// The project open last (D62) is not there any more: {0} its name or
  /// path.
  final String lastProjectGone;

  /// File → New Project (D63): the menu item, the dialog's title, its
  /// fields for the form's Caption and size, and its button.
  final String newProject;
  final String newProjectTitle;
  final String formCaption;
  final String formSizeLabel;
  final String createButton;

  /// After the project's name while it has unsaved changes.
  final String edited;

  // Projects kept in the browser, and .zip files (D33).
  final String saveAsTitle;
  final String projectName;
  final String downloadZip;
  final String uploadZip;

  /// The web IDE's link to the playground next to it (`../`).
  final String openPlayground;

  /// File → Clear Saved Settings: forgets what the project's program saved
  /// with SaveSetting (D48). {0}: the project's name.
  final String clearSettings;
  final String clearSettingsQuestion;
  final String clearSettingsYes;
  final String settingsCleared;
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

  /// Deleting a control the code uses (D64): the lines ({0} the control,
  /// {1} the code file, {2} the lines), its handlers that stay ({0}), how
  /// to bring it back ({0} the undo key), and the button.
  final String deleteUsedControl;
  final String deleteHandlersStay;
  final String deleteUndo;
  final String deleteControl;

  /// `{0}` the name typed.
  final String badName;

  /// `{0}` the name typed.
  final String nameTaken;

  /// `{0}` the name typed, `{1}` the code file, `{2}` the lines.
  final String nameInCode;

  // The code editor's lists of objects and events (D38).
  final String generalObject;
  final String declarations;
  final String objectList;
  final String eventList;

  /// Above the suggestions in the completion list (D50).
  final String didYouMean;

  /// What each completion is, shown beside it (D50).
  final Map<CompletionKind, String> completionKinds;

  /// Beside a property the program can only read (D45).
  final String readOnlyProperty;

  /// `{0}` the handler.
  final String noHandlerWhileRunning;

  /// An error in the output, clicked (D40). `{0}` the file, `{1}` the line.
  final String goToLine;

  // The designer's context menu and order buttons (D42).
  final String viewCode;
  final String bringToFront;
  final String sendToBack;
  final String delete;

  // The project's pictures (D51).
  final String picturesMenu;
  final String picturesTitle;
  final String noPictures;
  final String addPicture;

  /// The button of the system dialog that chooses a picture.
  final String addButton;
  final String removePicture;

  /// The first choice of a picture property: no picture.
  final String noPicture;

  /// The Anchor field (D59): what it shows for no edge, and what each
  /// arm of its cross does, by edge (`Left`, `Top`, `Right`, `Bottom`).
  final String noAnchor;

  /// The form size presets (D60): the menu's button, the three presets,
  /// and the button that swaps the form's width and height.
  final String formSize;
  final String phonePreset;
  final String tabletPreset;
  final String desktopPreset;
  final String turnForm;
  final Map<String, String> anchorTips;

  /// `{0}` the picture.
  final String confirmRemovePicture;

  /// `{0}` the picture, `{1}` the controls (`Form1.imgShape`).
  final String pictureInUse;

  /// `{0}` the picture.
  final String replacePicture;
  final String replaceButton;

  /// `{0}` the pictures.
  final String missingPictures;
  final String pictureProjectFileErrors;

  /// `{0}` the file's name, for each of these.
  final String pictureNameTooLong;
  final String pictureNameCharacters;
  final String pictureNotTaken;
  final String pictureIsHeic;

  /// `{1}` its size in MB.
  final String pictureTooLarge;

  /// `{1}` its width, `{2}` its height, in pixels.
  final String pictureTooWide;

  /// Making a picture smaller (D56): the button that does it, what it
  /// will do ({0} the longest side, {1} the copy's name), the note for an
  /// animated GIF, the words while it works, what was added ({0} name,
  /// {1} × {2} pixels, {3} MB) and why it could not be done.
  final String reduceButton;
  final String reduceOffer;
  final String reduceFirstFrameOnly;
  final String reducing;
  final String pictureReduced;
  final String reduceFailed;
  final String picturesFull;

  /// `{0}` the projects (D54).
  final String restoredUnsaved;

  /// `{0}` the pictures.
  final String missingPicturesKept;

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
    lastProjectGone: 'The project open last, {0}, is not there any more, so an example is open.',
    newProject: 'New Project…',
    newProjectTitle: 'New Project',
    formCaption: 'Form title (Caption)',
    formSizeLabel: 'Form size',
    createButton: 'Create',
    edited: 'Edited',
    saveAsTitle: 'Save As',
    projectName: 'Project name',
    downloadZip: 'Download .zip',
    uploadZip: 'Upload .zip…',
    openPlayground: 'Open the Playground',
    clearSettings: 'Clear Saved Settings…',
    clearSettingsQuestion:
        'Clear what the program of {0} saved with SaveSetting? '
        'The next run starts without it. This cannot be undone.',
    clearSettingsYes: 'Clear',
    settingsCleared: 'The saved settings of {0} were cleared.',
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
    zipTooLarge: 'This .zip is too large for a GuBASIC project: at most 12 MB and 100 files; its text files at most 2 MB unpacked, a picture 2 MB and all pictures 10 MB.',
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
    nameUsedInCode:
        '{0} is used in {1} on lines {2}; a new name changes those lines too.',
    deleteUsedControl:
        '{0} is used in {1} on lines {2}. Without it, those lines are errors.',
    deleteHandlersStay: 'Its event handlers ({0}) stay in the code, but nothing runs them any more.',
    deleteUndo: 'Undo ({0}) brings the control back.',
    deleteControl: 'Delete',
    badName: '"{0}" cannot be a name. A name starts with an English letter and has only English letters, digits and _; it cannot be a keyword or Form.',
    nameTaken: 'Another control is already named {0}. Choose another name.',
    nameInCode: '{0} is already used in {1} on lines {2}. Renaming the control to it would change what the code means. Choose another name.',
    generalObject: '(General)',
    declarations: '(Declarations)',
    objectList: 'Object',
    eventList: 'Event',
    didYouMean: 'Did you mean?',
    completionKinds: {
      CompletionKind.suggestion: '',
      CompletionKind.keyword: 'keyword',
      CompletionKind.type: 'type',
      CompletionKind.variable: 'variable',
      CompletionKind.constant: 'constant',
      CompletionKind.procedure: 'procedure',
      CompletionKind.function: 'function',
      CompletionKind.object: 'object',
      CompletionKind.control: 'control',
      CompletionKind.property: 'property',
      CompletionKind.method: 'method',
    },
    readOnlyProperty: 'read-only',
    noHandlerWhileRunning: 'There is no {0} yet, and code cannot be changed while the program runs. Stop it (Shift+F5) first.',
    goToLine: 'Go to {0}, line {1}',
    viewCode: 'View Code',
    bringToFront: 'Bring to Front',
    sendToBack: 'Send to Back',
    delete: 'Delete',
    picturesMenu: 'Pictures…',
    picturesTitle: 'Pictures',
    noPictures: 'This project has no pictures yet. Add PNG, JPEG or GIF pictures for its Image controls to show.',
    addPicture: 'Add Picture…',
    addButton: 'Add',
    removePicture: 'Remove',
    noPicture: '(None)',
    noAnchor: '(None: stays near the middle)',
    formSize: 'Size',
    phonePreset: 'Phone',
    tabletPreset: 'Tablet',
    desktopPreset: 'Desktop',
    turnForm: 'Swap width and height (turn the form)',
    anchorTips: {
      'Left': 'Left: keep the distance to the form\'s left edge',
      'Top': 'Top: keep the distance to the form\'s top edge',
      'Right': 'Right: keep the distance to the form\'s right edge',
      'Bottom': 'Bottom: keep the distance to the form\'s bottom edge',
    },
    confirmRemovePicture: 'Take the picture {0} out of the project? Its file in the pictures folder is deleted when the project is saved.',
    pictureInUse: '{0} is shown by {1}. Choose another picture there, or clear Picture, then remove it.',
    replacePicture: 'The project already has a picture named {0}. Replace it with the new one? Every control showing it then shows the new picture.',
    replaceButton: 'Replace',
    missingPictures: 'The project\'s pictures folder does not have these pictures: {0}. Put them there, or remove them in File → Pictures.',
    pictureProjectFileErrors: 'The .gbproj file has errors, so pictures cannot be added to it. Fix the file in a text editor, then open the project again.',
    pictureNameTooLong: 'The name "{0}" is too long for a picture: at most 100 characters. Rename the file, then add it again.',
    pictureNameCharacters: '"{0}" cannot be the name of a picture: it has one of / \\ : * ? " < > |, or starts or ends with a dot or a space. Rename the file, then add it again.',
    pictureNotTaken: '"{0}" is not a PNG, JPEG or GIF picture, the formats a project takes. Save it in one of them, then add it.',
    pictureIsHeic: '"{0}" is an HEIC photo, which a project does not take because not every platform shows it. Save it as JPEG or PNG, then add it.',
    pictureTooLarge: '"{0}" takes {1} MB; a picture can take at most 2 MB. Make it smaller (fewer pixels, or JPEG for a photo), then add it.',
    pictureTooWide: '"{0}" is {1} × {2} pixels; a picture can be at most 4096 pixels wide and high. Make it smaller, then add it.',
    reduceButton: 'Make Smaller and Add',
    reduceOffer: 'Make Smaller and Add makes a copy as a PNG, at most {0} pixels on its longest side (smaller if needed), and adds it as "{1}". The file you chose is not changed.',
    reduceFirstFrameOnly:
        'This GIF moves; the copy keeps its first frame only.',
    reducing: 'Making the picture smaller…',
    pictureReduced: 'Added "{0}", made smaller: {1} × {2} pixels, {3} MB.',
    reduceFailed: '"{0}" cannot be made small enough to add. Use a smaller picture, or remove pictures the project does not use.',
    picturesFull: 'With "{0}", the project\'s pictures would take more than 10 MB. Remove pictures it does not use, or make them smaller.',
    restoredUnsaved: 'Brought back changes that were not saved: {0}. The page closed before they were kept in this browser; they are kept now.',
    missingPicturesKept: 'These pictures were not kept with the project: {0}. Add them again in File → Pictures, or remove them there.',
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
    lastProjectGone: '마지막에 연 {0} 프로젝트를 찾을 수 없어서 예제를 열었습니다.',
    newProject: '새 프로젝트…',
    newProjectTitle: '새 프로젝트',
    formCaption: '폼 제목(Caption)',
    formSizeLabel: '폼 크기',
    createButton: '만들기',
    edited: '편집됨',
    saveAsTitle: '다른 이름으로 저장',
    projectName: '프로젝트 이름',
    downloadZip: '.zip으로 내려받기',
    uploadZip: '.zip 올리기…',
    openPlayground: '놀이터 열기',
    clearSettings: '저장된 설정 지우기…',
    clearSettingsQuestion:
        '{0} 프로젝트의 프로그램이 SaveSetting으로 저장한 설정을 지울까요? '
        '다음 실행은 설정 없이 시작합니다. 되돌릴 수 없습니다.',
    clearSettingsYes: '지우기',
    settingsCleared: '{0} 프로젝트에 저장된 설정을 지웠습니다.',
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
    zipTooLarge: '이 .zip 파일은 GuBASIC 프로젝트로 보기에 너무 큽니다. 최대 12MB, 파일 100개까지이고, 풀었을 때 텍스트 파일은 2MB, 그림은 하나에 2MB, 모두 합쳐 10MB까지입니다.',
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
    nameUsedInCode: '{0} 이름은 {1} 파일의 {2}번째 줄에서 쓰입니다. 새 이름으로 바꾸면 그 줄도 함께 바뀝니다.',
    deleteUsedControl: '{0} 컨트롤은 {1} 파일의 {2}번째 줄에서 쓰입니다. 지우면 그 줄은 오류가 됩니다.',
    deleteHandlersStay: '이벤트 처리기({0})는 코드에 남지만, 더는 실행되지 않습니다.',
    deleteUndo: '되돌리기({0})로 컨트롤을 다시 살릴 수 있습니다.',
    deleteControl: '지우기',
    badName: '"{0}" 문자열은 이름으로 쓸 수 없습니다. 이름은 영문자로 시작하고 영문자, 숫자, _만 쓸 수 있으며, 키워드나 Form은 쓸 수 없습니다.',
    nameTaken: '{0} 이름의 컨트롤이 이미 있습니다. 다른 이름을 입력합니다.',
    nameInCode: '{0} 이름은 이미 {1} 파일의 {2}번째 줄에서 쓰입니다. 컨트롤을 이 이름으로 바꾸면 코드의 뜻이 바뀝니다. 다른 이름을 입력합니다.',
    generalObject: '(일반)',
    declarations: '(선언)',
    objectList: '개체',
    eventList: '이벤트',
    didYouMean: '혹시 이것인가요?',
    completionKinds: {
      CompletionKind.suggestion: '',
      CompletionKind.keyword: '키워드',
      CompletionKind.type: '타입',
      CompletionKind.variable: '변수',
      CompletionKind.constant: '상수',
      CompletionKind.procedure: '프로시저',
      CompletionKind.function: '함수',
      CompletionKind.object: '객체',
      CompletionKind.control: '컨트롤',
      CompletionKind.property: '속성',
      CompletionKind.method: '메서드',
    },
    readOnlyProperty: '읽기 전용',
    noHandlerWhileRunning:
        '{0} 처리기가 아직 없고, 프로그램이 실행되는 동안에는 코드를 바꿀 수 없습니다. 먼저 중지(Shift+F5)합니다.',
    goToLine: '{0} 파일 {1}번째 줄로 갑니다',
    viewCode: '코드 보기',
    bringToFront: '맨 앞으로',
    sendToBack: '맨 뒤로',
    delete: '삭제',
    picturesMenu: '그림…',
    picturesTitle: '그림',
    noPictures: '이 프로젝트에는 아직 그림이 없습니다. Image 컨트롤에 보일 PNG, JPEG, GIF 그림을 추가합니다.',
    addPicture: '그림 추가…',
    addButton: '추가',
    removePicture: '빼기',
    noPicture: '(없음)',
    noAnchor: '(없음: 가운데 가까이 머묾)',
    formSize: '크기',
    phonePreset: '폰',
    tabletPreset: '태블릿',
    desktopPreset: '데스크톱',
    turnForm: '가로·세로 바꾸기(폼 돌리기)',
    anchorTips: {
      'Left': 'Left: 폼의 왼쪽 가장자리와의 거리를 지킵니다',
      'Top': 'Top: 폼의 위쪽 가장자리와의 거리를 지킵니다',
      'Right': 'Right: 폼의 오른쪽 가장자리와의 거리를 지킵니다',
      'Bottom': 'Bottom: 폼의 아래쪽 가장자리와의 거리를 지킵니다',
    },
    confirmRemovePicture:
        '프로젝트에서 {0} 그림을 뺄까요? 프로젝트를 저장할 때 pictures 폴더의 그림 파일도 지웁니다.',
    pictureInUse:
        '{0} 그림은 {1} 컨트롤에서 보입니다. 그 컨트롤의 Picture 속성을 다른 그림으로 바꾸거나 비운 뒤 뺍니다.',
    replacePicture:
        '프로젝트에 {0} 그림이 이미 있습니다. 새 그림으로 바꿀까요? 이 그림을 보이는 컨트롤은 모두 새 그림을 보입니다.',
    replaceButton: '바꾸기',
    missingPictures:
        '프로젝트의 pictures 폴더에 다음 그림이 없습니다: {0}. 그림 파일을 넣거나, 파일 → 그림에서 뺍니다.',
    pictureProjectFileErrors:
        '.gbproj 파일에 오류가 있어서 그림을 추가할 수 없습니다. 텍스트 편집기로 파일을 고친 뒤 프로젝트를 다시 엽니다.',
    pictureNameTooLong:
        '"{0}" 이름은 그림 이름으로 쓰기에 너무 깁니다. 100자까지 쓸 수 있습니다. 파일 이름을 바꾼 뒤 다시 추가합니다.',
    pictureNameCharacters: '"{0}" 이름은 그림 이름으로 쓸 수 없습니다. / \\ : * ? " < > | 문자가 들어 있거나, 점이나 공백으로 시작하거나 끝납니다. 파일 이름을 바꾼 뒤 다시 추가합니다.',
    pictureNotTaken: '"{0}" 파일은 프로젝트에 넣을 수 있는 PNG, JPEG, GIF 그림이 아닙니다. 이 중 한 형식으로 저장한 뒤 추가합니다.',
    pictureIsHeic: '"{0}" 파일은 HEIC 사진입니다. 모든 플랫폼에서 보이지는 않아서 프로젝트에 넣을 수 없습니다. JPEG나 PNG로 저장한 뒤 추가합니다.',
    pictureTooLarge: '"{0}" 파일의 크기는 {1}MB입니다. 그림 하나는 2MB까지 넣을 수 있습니다. 픽셀 수를 줄이거나 사진은 JPEG로 저장해 크기를 줄인 뒤 추가합니다.',
    pictureTooWide: '"{0}" 그림의 크기는 {1} × {2}픽셀입니다. 그림의 가로와 세로는 4096픽셀까지입니다. 크기를 줄인 뒤 추가합니다.',
    reduceButton: '줄여서 넣기',
    reduceOffer: '[줄여서 넣기]를 누르면 긴 변이 {0}픽셀 이하인 PNG 사본을 만들어(필요하면 더 작게) "{1}" 이름으로 추가합니다. 고른 파일은 바뀌지 않습니다.',
    reduceFirstFrameOnly: '움직이는 GIF입니다. 사본에는 첫 장면만 남습니다.',
    reducing: '그림을 줄이는 중입니다…',
    pictureReduced: '"{0}" 그림을 {1} × {2}픽셀, {3} MB로 줄여서 추가했습니다.',
    reduceFailed:
        '"{0}" 그림은 추가할 수 있을 만큼 줄일 수 없습니다. 더 작은 그림을 쓰거나, 프로젝트에서 쓰지 않는 그림을 지웁니다.',
    picturesFull:
        '"{0}" 파일을 넣으면 프로젝트의 그림이 모두 10MB를 넘습니다. 쓰지 않는 그림을 빼거나 그림 크기를 줄입니다.',
    restoredUnsaved:
        '저장되지 않았던 변경을 되살렸습니다: {0}. 이 브라우저에 보관하기 전에 페이지가 닫혔던 변경이며, 지금은 보관되었습니다.',
    missingPicturesKept:
        '다음 그림은 프로젝트와 함께 보관되지 않았습니다: {0}. 파일 → 그림에서 다시 추가하거나 뺍니다.',
  );

  /// Korean when the system language is Korean, else English.
  static IdeStrings forLanguage(String languageCode) =>
      languageCode == 'ko' ? ko : en;
}
