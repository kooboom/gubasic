import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import 'src/ide_shell.dart';
import 'src/project/examples.g.dart';
import 'src/project/browser.dart';
import 'src/project/folders.dart';
import 'src/project/platform_browser.dart';
import 'src/project/platform_folders.dart';
import 'src/project/project_controller.dart';
import 'src/strings.dart';
import 'src/theme.dart';

/// The GuBASIC IDE. It opens the example projects and, on the desktop,
/// projects on disk (D32), and runs them in a run window (docs/ROADMAP.md,
/// stage 1).
void main() {
  final language = PlatformDispatcher.instance.locale.languageCode;
  runApp(
    IdeApp(
      projects: exampleProjects,
      strings: IdeStrings.forLanguage(language),
      folders: platformFolders(),
      browser: platformBrowser(),
      pickZip: () async => (await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'zip', extensions: ['zip']),
        ],
      ))?.readAsBytes(),
      pickers: ProjectPickers(
        openProjectFile: (confirm) async => (await openFile(
          acceptedTypeGroups: const [_gbproj],
          confirmButtonText: confirm,
        ))?.path,
        // Telling the dialog it saves a .gbproj makes macOS add the
        // extension, so it does not ask to replace the project's folder
        // of the same name; the IDE says so itself (D32).
        saveLocation: (name, confirm) async => (await getSaveLocation(
          acceptedTypeGroups: const [_gbproj],
          suggestedName: name,
          confirmButtonText: confirm,
        ))?.path,
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => BoldFont.load());
}

/// GuBASIC project files, for the system's open and save dialogs.
///
/// macOS knows `.gbproj` from the type the app declares in its
/// Info.plist (`io.github.kooboom.gubasic.project`); without it, the save dialog made
/// up a type and added another extension (D32).
const _gbproj = XTypeGroup(
  label: 'GuBASIC',
  extensions: ['gbproj'],
  uniformTypeIdentifiers: ['io.github.kooboom.gubasic.project'],
);

class IdeApp extends StatefulWidget {
  const IdeApp({
    super.key,
    required this.projects,
    required this.strings,
    this.open = 'hello',
    this.folders,
    this.pickers,
    this.browser,
    this.pickZip,
    this.settings,
  });

  /// The built-in projects: name → files.
  final Map<String, Map<String, String>> projects;
  final IdeStrings strings;

  /// The project opened first.
  final String open;

  /// The disk and the system's file dialogs, where projects can be opened
  /// and saved (D32); null on the web for now.
  final ProjectFolders? folders;
  final ProjectPickers? pickers;

  /// The web browser and its file dialog for `.zip` files, where projects
  /// are kept in the browser (D33); null on the desktop.
  final Browser? browser;
  final Future<List<int>?> Function()? pickZip;

  /// Where the programs' settings are kept; shared_preferences when null.
  final GbSettingsStore? settings;

  @override
  State<IdeApp> createState() => _IdeAppState();
}

class _IdeAppState extends State<IdeApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late final _controller = ProjectController(
    examples: widget.projects,
    strings: widget.strings,
    folders: widget.folders,
    pickers: widget.pickers,
    browser: widget.browser,
    pickZip: widget.pickZip,
    settings: widget.settings,
    open: widget.open,
  );

  /// Whether the designer's grid is on.
  final _grid = ValueNotifier(true);

  /// Asks about unsaved changes when the app is about to quit.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onExitRequested: _exit);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    _grid.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _exit() async {
    final context = _navigator.currentContext;
    if (context == null || !_controller.current.isDirty) {
      return AppExitResponse.exit;
    }
    return await _controller.mayLeave(context)
        ? AppExitResponse.exit
        : AppExitResponse.cancel;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => MaterialApp(
      title: 'GuBASIC',
      debugShowCheckedModeBanner: false,
      theme: ideTheme,
      navigatorKey: _navigator,
      // While a system file dialog is open, the whole IDE shows the arrow:
      // otherwise the code view's text cursor showed through the dialog.
      builder: (context, child) => Stack(
        children: [
          child!,
          if (_controller.picking)
            const Positioned.fill(
              child: MouseRegion(cursor: SystemMouseCursors.basic),
            ),
        ],
      ),
      home: IdeShell(
        // A new shell for each project: what ran before is gone.
        key: ObjectKey(_controller.current),
        controller: _controller,
        strings: widget.strings,
        grid: _grid,
      ),
    ),
  );
}
