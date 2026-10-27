import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// The IDE's words, in English and Korean.
class IdeStrings {
  const IdeStrings({
    required this.player,
    required this.run,
    required this.stop,
    required this.files,
    required this.runWindow,
    required this.output,
    required this.cannotStart,
    required this.closed,
    required this.ended,
    required this.stopped,
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
    required this.alreadyKept,
    required this.lastProjectGone,
    required this.keptOne,
    required this.keptMany,
    required this.keptOpen,
    required this.keptDismiss,
    required this.newProject,
    required this.newProjectTitle,
    required this.formCaption,
    required this.formSizeLabel,
    required this.createButton,
    required this.edited,
    required this.saveAsTitle,
    required this.projectName,
    required this.downloadZip,
    required this.downloadZipHint,
    required this.uploadZip,
    required this.exportWebApp,
    required this.webAppCannotRun,
    required this.webAppPreparing,
    required this.webAppTemplateUnavailable,
    required this.webAppTemplateNotUsable,
    required this.webAppSaved,
    required this.webAppGuide,
    required this.exportWindowsApp,
    required this.windowsAppPreparing,
    required this.windowsAppTemplateUnavailable,
    required this.windowsAppTemplateNotUsable,
    required this.windowsAppSaved,
    required this.windowsAppGuide,
    required this.exportMacApp,
    required this.macAppOnlyOnMac,
    required this.macAppOnlyOnMacWhy,
    required this.macAppPreparing,
    required this.macAppTemplateUnavailable,
    required this.macAppTemplateNotUsable,
    required this.macAppNotMade,
    required this.macAppSaved,
    required this.macAppGuide,
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
    required this.outsideOne,
    required this.outsideMany,
    required this.fitInside,
    required this.fitInsideTip,
    required this.stoppedAtEdge,
    required this.formHasErrors,
    required this.properties,
    required this.integerRange,
    required this.numberNeeded,
    required this.formNameIsFile,
    required this.addForm,
    required this.formActions,
    required this.startupFormTag,
    required this.makeStartupForm,
    required this.renameForm,
    required this.deleteForm,
    required this.formNameLabel,
    required this.formNameNotUsable,
    required this.formNameTaken,
    required this.formNameUsedInCode,
    required this.deleteFormQuestion,
    required this.deleteFormUses,
    required this.lastFormKept,
    required this.formsNeedProjectFile,
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
    required this.picturesGroup,
    required this.picturesTitle,
    required this.noPictures,
    required this.addPicture,
    required this.addButton,
    required this.removePicture,
    required this.noPicture,
    required this.noAnchor,
    required this.formSize,
    required this.fit,
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
    required this.pictureUnreadable,
    required this.picturesUnreadable,
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

  /// The words of a running program, shared with the player (D79).
  final PlayerStrings player;

  /// The words on MsgBox and InputBox.
  GbStrings get runtime => player.runtime;

  /// Diagnostic messages.
  Map<DiagnosticCode, String> get messages => player.messages;

  String get closeForm => player.closeForm;
  String get fitTip => player.fitTip;

  final String run;
  final String stop;

  /// The heading of the file list: the files of the project.
  final String files;

  /// The file list's entry that goes back to the running program.
  final String runWindow;
  final String output;
  final String cannotStart;
  final String closed;
  final String ended;
  final String stopped;

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

  /// Save on a project kept in the browser with nothing left to keep
  /// (D67).
  final String alreadyKept;

  /// The project open last (D62) is not there any more: {0} its name or
  /// path.
  final String lastProjectGone;

  /// At the start, when an example opens and projects are kept in the
  /// browser (D74): one, or {0} of them; a button to choose one, and one
  /// to close the bar.
  final String keptOne;
  final String keptMany;
  final String keptOpen;
  final String keptDismiss;

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

  /// The tooltip of the web IDE's save-to-computer button.
  final String downloadZipHint;
  final String uploadZip;

  // File → Export as Web App (D84).
  final String exportWebApp;
  final String webAppCannotRun;
  final String webAppPreparing;
  final String webAppTemplateUnavailable;

  /// {0}: the bundle layout the template reads.
  final String webAppTemplateNotUsable;

  /// {0}: the file the web app was saved as.
  final String webAppSaved;

  /// `HOSTING.txt` in the web app: how to put it on the web.
  final String webAppGuide;

  /// File → Export as Windows App (D86).
  final String exportWindowsApp;
  final String windowsAppPreparing;
  final String windowsAppTemplateUnavailable;

  /// {0}: the bundle layout the template reads.
  final String windowsAppTemplateNotUsable;

  /// {0}: the file the Windows app was saved as; {1}: its program,
  /// `NAME.exe`.
  final String windowsAppSaved;

  /// `README.txt` in the Windows app: how to open it. {0}: its program.
  final String windowsAppGuide;

  /// File → Export as macOS App (D87), in the macOS IDE only.
  final String exportMacApp;

  /// After the menu item where it is greyed out: where it works.
  final String macAppOnlyOnMac;

  /// The greyed-out menu item's tooltip: why.
  final String macAppOnlyOnMacWhy;
  final String macAppPreparing;
  final String macAppTemplateUnavailable;

  /// {0}: the bundle layout the template reads.
  final String macAppTemplateNotUsable;

  /// {0}: what the Mac's tool said.
  final String macAppNotMade;

  /// {0}: the file the macOS app was saved as; {1}: the app, `NAME.app`.
  final String macAppSaved;

  /// `README.txt` in the macOS app: how to open it the first time. {0}:
  /// the app.
  final String macAppGuide;

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

  /// Above the designer when controls reach outside the form (D72): one,
  /// or {0} of them, then their names.
  final String outsideOne;
  final String outsideMany;
  final String fitInside;
  final String fitInsideTip;

  /// In the designer's status line while a drag is stopped at the form's
  /// edge (D77).
  final String stoppedAtEdge;
  final String formHasErrors;

  // The Properties window (D35).
  final String properties;

  /// `{0}` the property, `{1}` the smallest value, `{2}` the largest.
  final String integerRange;

  /// `{0}` the property.
  final String numberNeeded;
  final String formNameIsFile;

  /// File → Add Form (D88).
  final String addForm;

  /// The tooltip of a form's ⋮ button in the project list.
  final String formActions;

  /// After the startup form's file in the project list.
  final String startupFormTag;
  final String makeStartupForm;
  final String renameForm;
  final String deleteForm;
  final String formNameLabel;

  /// {0}: the name typed.
  final String formNameNotUsable;

  /// {0}: the name typed.
  final String formNameTaken;

  /// {0}: the name typed; {1}: where the code uses it.
  final String formNameUsedInCode;

  /// {0}: the form.
  final String deleteFormQuestion;

  /// {0}: the form; {1}: where the code uses it.
  final String deleteFormUses;

  /// {0}: the form.
  final String lastFormKept;

  /// The `.gbproj` file has errors, so the forms cannot be changed.
  final String formsNeedProjectFile;

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

  /// The group of the project's pictures in the file list (D68).
  final String picturesGroup;
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

  /// Shrinking a large form to fit (D66): the designer's switch, and what
  /// it does.
  final String fit;
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

  /// A picture that is not whole (D65): one being added ({0} its name),
  /// and those of a project just opened ({0} their names).
  final String pictureUnreadable;
  final String picturesUnreadable;

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
  String problem(String file, Diagnostic diagnostic) =>
      player.problem(file, diagnostic);

  static const en = IdeStrings(
    player: PlayerStrings.en,
    run: 'Run',
    stop: 'Stop',
    files: 'Project',
    runWindow: 'Run window',
    output: 'Output',
    cannotStart:
        'The program cannot start because of the errors below. '
        'Fix them, then run it again.',
    closed: 'The program ended: its form was closed.',
    ended: 'The program ended at End.',
    stopped: 'The program was stopped.',
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
    alreadyKept: 'Already kept in this browser; changes are kept by themselves as you work.',
    lastProjectGone: 'The project open last, {0}, is not there any more, so an example is open.',
    keptOne: 'A project of yours is kept in this browser.',
    keptMany: '{0} projects of yours are kept in this browser.',
    keptOpen: 'Open one',
    keptDismiss: 'Close',
    newProject: 'New Project…',
    newProjectTitle: 'New Project',
    formCaption: 'Form title (Caption)',
    formSizeLabel: 'Form size',
    createButton: 'Create',
    edited: 'Edited',
    saveAsTitle: 'Save As',
    projectName: 'Project name',
    downloadZip: 'Save to my computer',
    downloadZipHint:
        'Downloads the project as one .zip file. You can open it again '
        'later with File → Upload .zip….',
    uploadZip: 'Upload .zip…',
    exportWebApp: 'Export as Web App…',
    webAppCannotRun:
        'The project has errors, so it cannot be exported. Fix the errors, '
        'run it once to check, then export again.',
    webAppPreparing: 'Making the web app…',
    webAppTemplateUnavailable:
        'Could not download the web player (kooboom.github.io). Check the '
        'internet connection and try again.',
    webAppTemplateNotUsable:
        'The web player that was downloaded is for another version of '
        'GuBASIC (bundle layout {0}). Update GuBASIC and export again.',
    webAppSaved:
        'Saved the web app as {0}. Unzip it and put the folder on any web '
        'host, such as GitHub Pages or Netlify; HOSTING.txt in it says how. '
        'Opening index.html straight from the disk does not work: a web app '
        'needs a web server.',
    webAppGuide:
        'This folder is a GuBASIC web app.\n'
        '\n'
        'Put everything in it on a web host, as it is, in any folder:\n'
        '- GitHub Pages: upload the files to a repository and turn on Pages.\n'
        '- Netlify: drag the folder onto app.netlify.com/drop.\n'
        '- Your own server: copy the files into any folder it serves.\n'
        '\n'
        'To try it on your computer, run a small web server in this folder,\n'
        'for example "python3 -m http.server", and open\n'
        'http://localhost:8000. Opening index.html by double-clicking it\n'
        'does not work.\n'
        '\n'
        'project.gbz holds the program. Export the project again to update it.\n'
        'What the program saves with SaveSetting stays in each visitor\'s\n'
        'browser, kept apart by the app ID.\n',
    exportWindowsApp: 'Export as Windows App…',
    windowsAppPreparing: 'Making the Windows app…',
    windowsAppTemplateUnavailable:
        'Could not download the Windows player (kooboom.github.io). Check '
        'the internet connection and try again.',
    windowsAppTemplateNotUsable:
        'The Windows player that was downloaded is for another version of '
        'GuBASIC (bundle layout {0}). Update GuBASIC and export again.',
    windowsAppSaved:
        'Saved the Windows app as {0}. On a Windows PC, unzip it and open {1} '
        'in the folder; README.txt in it says more.',
    windowsAppGuide:
        'This folder is a GuBASIC app for Windows (Windows 10 or later, '
        '64-bit).\n'
        '\n'
        'To run it, open {0}. Keep all the files in the folder together:\n'
        'the program needs the others next to it. Nothing is installed; to\n'
        'remove the app, delete the folder. To give it to someone, zip the\n'
        'whole folder.\n'
        '\n'
        'The program is not signed, so Windows may say "Windows protected\n'
        'your PC". Choose "More info", then "Run anyway".\n'
        '\n'
        'project.gbz holds the program. Export the project again to update it.\n'
        'What the program saves with SaveSetting stays on this PC, kept apart\n'
        'by the app ID, so an updated app finds it again.\n',
    exportMacApp: 'Export as macOS App…',
    macAppOnlyOnMac: 'in the IDE for Mac only',
    macAppOnlyOnMacWhy:
        'A macOS app has to be signed again once the project is inside it, '
        'and only a Mac can do that. Open the project in GuBASIC for Mac to '
        'export it.',
    macAppPreparing: 'Making the macOS app…',
    macAppTemplateUnavailable:
        'Could not download the macOS player (kooboom.github.io). Check the '
        'internet connection and try again.',
    macAppTemplateNotUsable:
        'The macOS player that was downloaded is for another version of '
        'GuBASIC (bundle layout {0}). Update GuBASIC and export again.',
    macAppNotMade:
        'Could not make the macOS app: {0}. Try again; if it fails again, '
        'please report it with this message.',
    macAppSaved:
        'Saved the macOS app as {0}. Unzip it and open {1} in the folder. '
        'On another Mac, macOS blocks it the first time; README.txt in the '
        'folder says how to open it.',
    macAppGuide:
        'This folder is a GuBASIC app for macOS (macOS 12 or later, Intel and\n'
        'Apple silicon).\n'
        '\n'
        'Open {0}. It needs no installing: move it to the Applications folder\n'
        'or anywhere you like, and to remove it, move it to the Trash.\n'
        '\n'
        'The app is not signed with an Apple Developer ID or notarized, so\n'
        'when it comes from the internet, a message or a USB stick made on\n'
        'another Mac, macOS blocks it the first time:\n'
        '- macOS 14 (Sonoma) and earlier: in the Finder, Control-click\n'
        '  (right-click) the app, choose "Open", then click "Open".\n'
        '- macOS 15 (Sequoia) and later: right-click and Open no longer works.\n'
        '  Try to open the app once, then in "System Settings > Privacy &\n'
        '  Security", under Security, click "Open Anyway" and enter your\n'
        '  password. The button shows for about an hour after the attempt.\n'
        'On the Mac that exported it, the app opens at once.\n'
        '\n'
        'The program is inside the app. Export the project again to update it.\n'
        'What the program saves with SaveSetting stays on this Mac, kept apart\n'
        'by the app ID, so an updated app finds it again.\n',
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
    outsideOne: '1 control is outside the form:',
    outsideMany: '{0} controls are outside the form:',
    fitInside: 'Fit inside the form',
    stoppedAtEdge: 'The form\'s edge: a control dragged with the mouse stays inside the form. To put it past the edge, type its Left, Top, Width or Height in the Properties window.',
    fitInsideTip: 'Keeps where each one starts and makes it end at the form\'s edge; one that starts outside the form, or would become smaller than its default size, is moved inside instead. Its Anchor stays as it is.',
    formHasErrors: 'This form file has errors, so the designer only shows it: changing it would drop what could not be read. Fix the file in a text editor, then open the project again.',
    properties: 'Properties',
    integerRange: '{0} takes a whole number from {1} to {2}.',
    numberNeeded: '{0} takes a number, such as 1.5.',
    formNameIsFile:
        'A form is named after its files. To rename it, use ⋮ next to the '
        'form in the project list.',
    addForm: 'Add Form',
    formActions: 'Form',
    startupFormTag: 'starts',
    makeStartupForm: 'Start with This Form',
    renameForm: 'Rename Form…',
    deleteForm: 'Delete Form…',
    formNameLabel: 'Form name',
    formNameNotUsable:
        '"{0}" cannot name a form. Use English letters, digits and _, '
        'starting with a letter; not a keyword, and not Form.',
    formNameTaken: 'The project has a form named {0} already.',
    formNameUsedInCode:
        'The code uses the name {0} already ({1}), so a form cannot take '
        'it: that code would turn into a use of the form. Choose another '
        'name.',
    deleteFormQuestion:
        'Delete {0}? Its design and its code are taken out of the project; '
        'on the disk, its files are deleted when the project is saved.',
    deleteFormUses:
        'The code uses {0} ({1}): those lines will be errors until they are '
        'changed.',
    lastFormKept: 'A project needs a form, so {0} cannot be deleted.',
    formsNeedProjectFile:
        'The project file has errors, so its forms cannot be changed. Fix '
        'the .gbproj file first.',
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
    picturesGroup: 'Pictures',
    picturesTitle: 'Pictures',
    noPictures: 'This project has no pictures yet. Add PNG, JPEG or GIF pictures for its Image controls to show.',
    addPicture: 'Add Picture…',
    addButton: 'Add',
    removePicture: 'Remove',
    noPicture: '(None)',
    noAnchor: '(None: stays near the middle)',
    formSize: 'Size',
    fit: 'Fit',
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
    pictureUnreadable: '"{0}" cannot be read: the file may be damaged or cut short. Open it in another program, save it again, then add it.',
    picturesUnreadable: 'These pictures cannot be read; their files may be damaged: {0}. They show as a broken picture. Replace them in File → Pictures.',
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
    player: PlayerStrings.ko,
    run: '실행',
    stop: '중지',
    files: '프로젝트',
    runWindow: '실행 화면',
    output: '출력',
    cannotStart: '아래 오류 때문에 프로그램을 시작할 수 없습니다. 오류를 고친 뒤 다시 실행합니다.',
    closed: '폼을 닫아서 프로그램이 끝났습니다.',
    ended: 'End 문에서 프로그램이 끝났습니다.',
    stopped: '프로그램을 중지했습니다.',
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
    alreadyKept: '이미 이 브라우저에 보관되어 있습니다. 바꾼 내용은 작업하는 동안 저절로 보관됩니다.',
    lastProjectGone: '마지막에 연 {0} 프로젝트를 찾을 수 없어서 예제를 열었습니다.',
    keptOne: '이 브라우저에 보관된 프로젝트가 1개 있습니다.',
    keptMany: '이 브라우저에 보관된 프로젝트가 {0}개 있습니다.',
    keptOpen: '열기',
    keptDismiss: '닫기',
    newProject: '새 프로젝트…',
    newProjectTitle: '새 프로젝트',
    formCaption: '폼 제목(Caption)',
    formSizeLabel: '폼 크기',
    createButton: '만들기',
    edited: '편집됨',
    saveAsTitle: '다른 이름으로 저장',
    projectName: '프로젝트 이름',
    downloadZip: '내 컴퓨터에 저장',
    downloadZipHint:
        '프로젝트를 .zip 파일 하나로 내려받습니다. 나중에 [파일 → .zip 올리기…]로 다시 열 수 있습니다.',
    uploadZip: '.zip 올리기…',
    exportWebApp: '웹 앱으로 내보내기…',
    webAppCannotRun: '프로젝트에 오류가 있어서 내보낼 수 없습니다. 오류를 고치고 한 번 실행해 본 뒤 다시 내보냅니다.',
    webAppPreparing: '웹 앱을 만드는 중…',
    webAppTemplateUnavailable:
        '웹 플레이어(kooboom.github.io)를 내려받지 못했습니다. 인터넷 연결을 확인하고 다시 시도합니다.',
    webAppTemplateNotUsable:
        '내려받은 웹 플레이어는 다른 버전의 GuBASIC용입니다(묶음 형식 {0}). GuBASIC을 업데이트하고 다시 내보냅니다.',
    webAppSaved:
        '웹 앱을 {0} 파일로 저장했습니다. 압축을 풀고 폴더를 GitHub Pages나 Netlify 같은 웹 호스팅에 올립니다. '
        '방법은 폴더 안의 HOSTING.txt 파일에 있습니다. 웹 앱은 웹 서버가 있어야 해서, '
        'index.html을 디스크에서 바로 열면 실행되지 않습니다.',
    webAppGuide:
        '이 폴더는 GuBASIC 웹 앱입니다.\n'
        '\n'
        '안의 파일을 모두 그대로 웹 호스팅의 아무 폴더에 올립니다.\n'
        '- GitHub Pages: 저장소에 파일을 올리고 Pages를 켭니다.\n'
        '- Netlify: app.netlify.com/drop에 폴더를 끌어다 놓습니다.\n'
        '- 개인 서버: 서버가 제공하는 아무 폴더에 파일을 복사합니다.\n'
        '\n'
        '내 컴퓨터에서 시험하려면 이 폴더에서 작은 웹 서버를 띄우고\n'
        '(예: "python3 -m http.server") http://localhost:8000을 엽니다.\n'
        'index.html을 더블클릭해서 열면 실행되지 않습니다.\n'
        '\n'
        'project.gbz 파일에 프로그램이 들어 있습니다. 고친 뒤에는 다시 내보냅니다.\n'
        '프로그램이 SaveSetting으로 저장한 값은 방문자마다 그 사람의 브라우저에,\n'
        '앱 ID별로 따로 남습니다.\n',
    exportWindowsApp: 'Windows 앱으로 내보내기…',
    windowsAppPreparing: 'Windows 앱을 만드는 중…',
    windowsAppTemplateUnavailable:
        'Windows 플레이어(kooboom.github.io)를 내려받지 못했습니다. 인터넷 연결을 확인하고 다시 시도합니다.',
    windowsAppTemplateNotUsable: '내려받은 Windows 플레이어는 다른 버전의 GuBASIC용입니다(묶음 형식 {0}). GuBASIC을 업데이트하고 다시 내보냅니다.',
    windowsAppSaved:
        'Windows 앱을 {0} 파일로 저장했습니다. Windows PC에서 압축을 풀고 폴더 안의 {1} 파일을 엽니다. '
        '자세한 내용은 폴더 안의 README.txt 파일에 있습니다.',
    windowsAppGuide:
        '이 폴더는 Windows용 GuBASIC 앱입니다(Windows 10 이상, 64비트).\n'
        '\n'
        '{0} 파일을 열면 실행됩니다. 폴더 안의 파일은 모두 함께 둡니다.\n'
        '프로그램은 옆의 다른 파일이 있어야 실행됩니다. 설치하지 않으므로,\n'
        '지우려면 폴더를 지웁니다. 다른 사람에게 줄 때는 폴더 전체를 압축합니다.\n'
        '\n'
        '프로그램에 서명이 없어서 Windows가 "Windows의 PC 보호" 창을 띄울 수\n'
        '있습니다. "추가 정보"를 누른 뒤 "실행"을 누릅니다.\n'
        '\n'
        'project.gbz 파일에 프로그램이 들어 있습니다. 고친 뒤에는 다시 내보냅니다.\n'
        '프로그램이 SaveSetting으로 저장한 값은 이 PC에 앱 ID별로 따로 남아서,\n'
        '다시 내보낸 앱도 그 값을 그대로 씁니다.\n',
    exportMacApp: 'macOS 앱으로 내보내기…',
    macAppOnlyOnMac: 'Mac용 IDE에서만',
    macAppOnlyOnMacWhy:
        'macOS 앱은 프로젝트를 넣은 뒤 다시 서명해야 하는데, 이 일은 Mac에서만 할 수 있습니다. '
        'Mac용 GuBASIC에서 프로젝트를 열어 내보냅니다.',
    macAppPreparing: 'macOS 앱을 만드는 중…',
    macAppTemplateUnavailable:
        'macOS 플레이어(kooboom.github.io)를 내려받지 못했습니다. 인터넷 연결을 확인하고 다시 시도합니다.',
    macAppTemplateNotUsable: '내려받은 macOS 플레이어는 다른 버전의 GuBASIC용입니다(묶음 형식 {0}). GuBASIC을 업데이트하고 다시 내보냅니다.',
    macAppNotMade:
        'macOS 앱을 만들지 못했습니다: {0}. 다시 시도해 보고, 또 안 되면 이 메시지와 함께 알려 주세요.',
    macAppSaved:
        'macOS 앱을 {0} 파일로 저장했습니다. 압축을 풀고 폴더 안의 {1} 앱을 엽니다. '
        '다른 Mac에서는 처음 열 때 macOS가 막습니다. 여는 방법은 폴더 안의 README.txt 파일에 있습니다.',
    macAppGuide:
        '이 폴더는 macOS용 GuBASIC 앱입니다(macOS 12 이상, Intel·Apple Silicon).\n'
        '\n'
        '{0} 앱을 엽니다. 설치는 필요 없습니다. 응용 프로그램 폴더나 원하는 곳으로\n'
        '옮겨 쓰고, 지우려면 휴지통으로 옮깁니다.\n'
        '\n'
        '이 앱은 Apple 개발자 서명과 공증을 받지 않았으므로, 인터넷이나 메신저,\n'
        '다른 Mac에서 만든 USB로 받은 경우 처음 열 때 macOS가 막습니다.\n'
        '- macOS 14(Sonoma) 이하: Finder에서 앱을 Control-클릭(우클릭)하고\n'
        '  "열기"를 고른 뒤, 다시 "열기"를 누릅니다.\n'
        '- macOS 15(Sequoia) 이상: 우클릭→열기로는 열리지 않습니다. 한 번 열어 본 뒤\n'
        '  "시스템 설정 › 개인정보 보호 및 보안"의 보안 항목에서 "그래도 열기"를\n'
        '  누르고 암호를 입력합니다. 이 단추는 열어 본 뒤 한 시간쯤만 보입니다.\n'
        '내보낸 Mac에서는 막히지 않고 바로 열립니다.\n'
        '\n'
        '프로그램은 앱 안에 들어 있습니다. 고친 뒤에는 다시 내보냅니다.\n'
        '프로그램이 SaveSetting으로 저장한 값은 이 Mac에 앱 ID별로 따로 남아서,\n'
        '다시 내보낸 앱도 그 값을 그대로 씁니다.\n',
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
    outsideOne: '폼 밖으로 나간 컨트롤 1개:',
    outsideMany: '폼 밖으로 나간 컨트롤 {0}개:',
    fitInside: '폼 안으로 맞추기',
    stoppedAtEdge: '폼 끝입니다. 마우스로 끄는 컨트롤은 폼 안에 머뭅니다. 폼 밖으로 두려면 속성 창에서 Left, Top, Width나 Height를 칩니다.',
    fitInsideTip: '컨트롤이 시작하는 자리는 지키고 폼 끝까지 줄입니다. 폼 밖에서 시작하거나 기본 크기보다 작아지는 컨트롤은 대신 폼 안으로 옮깁니다. Anchor는 그대로입니다.',
    formHasErrors: '이 폼 파일에는 오류가 있어서 그리기 화면에서 보기만 합니다. 고치면 읽지 못한 부분이 사라지기 때문입니다. 텍스트 편집기로 파일을 고친 뒤 프로젝트를 다시 엽니다.',
    properties: '속성',
    integerRange: '{0} 속성에는 정수만 쓸 수 있습니다. 범위: {1} ~ {2}',
    numberNeeded: '{0} 속성에는 1.5 같은 숫자만 쓸 수 있습니다.',
    formNameIsFile: '폼 이름은 파일 이름입니다. 이름을 바꾸려면 프로젝트 목록에서 폼 옆의 ⋮ 단추를 누릅니다.',
    addForm: '폼 추가',
    formActions: '폼',
    startupFormTag: '시작',
    makeStartupForm: '이 폼으로 시작',
    renameForm: '폼 이름 바꾸기…',
    deleteForm: '폼 지우기…',
    formNameLabel: '폼 이름',
    formNameNotUsable: '"{0}" 이름은 폼 이름으로 쓸 수 없습니다. 영문자로 시작하는 영문자, 숫자, _만 쓰고, 키워드와 Form은 쓸 수 없습니다.',
    formNameTaken: '프로젝트에 {0} 폼이 이미 있습니다.',
    formNameUsedInCode: '코드가 이미 {0} 이름을 씁니다({1}). 그 코드가 폼을 가리키게 되므로 폼 이름으로 쓸 수 없습니다. 다른 이름을 골라 주세요.',
    deleteFormQuestion:
        '{0} 폼을 지울까요? 디자인과 코드가 프로젝트에서 빠지고, 디스크의 파일은 프로젝트를 저장할 때 지워집니다.',
    deleteFormUses: '코드가 {0} 폼을 씁니다({1}). 그 줄은 고칠 때까지 오류가 됩니다.',
    lastFormKept: '프로젝트에는 폼이 하나는 있어야 해서 {0} 폼을 지울 수 없습니다.',
    formsNeedProjectFile:
        '프로젝트 파일에 오류가 있어서 폼을 바꿀 수 없습니다. .gbproj 파일을 먼저 고쳐 주세요.',
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
    picturesGroup: '그림',
    picturesTitle: '그림',
    noPictures: '이 프로젝트에는 아직 그림이 없습니다. Image 컨트롤에 보일 PNG, JPEG, GIF 그림을 추가합니다.',
    addPicture: '그림 추가…',
    addButton: '추가',
    removePicture: '빼기',
    noPicture: '(없음)',
    noAnchor: '(없음: 가운데 가까이 머묾)',
    formSize: '크기',
    fit: '화면에 맞춤',
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
    pictureUnreadable: '"{0}" 그림은 읽을 수 없습니다. 파일이 깨졌거나 끝이 잘렸을 수 있습니다. 다른 프로그램에서 열어 다시 저장한 뒤 추가합니다.',
    picturesUnreadable: '다음 그림은 읽을 수 없습니다. 파일이 깨졌을 수 있습니다: {0}. 깨진 그림으로 보이며, 파일 → 그림에서 바꿀 수 있습니다.',
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
