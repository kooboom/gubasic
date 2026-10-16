import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'src/ide_shell.dart';
import 'src/project/examples.g.dart';
import 'src/project/folders.dart';
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
      pickers: ProjectPickers(
        openProjectFile: (confirm) async => (await openFile(
          acceptedTypeGroups: const [
            XTypeGroup(label: 'GuBASIC', extensions: ['gbproj']),
          ],
          confirmButtonText: confirm,
        ))?.path,
        saveLocation: (name, confirm) async => (await getSaveLocation(
          suggestedName: name,
          confirmButtonText: confirm,
        ))?.path,
      ),
    ),
  );
}

class IdeApp extends StatefulWidget {
  const IdeApp({
    super.key,
    required this.projects,
    required this.strings,
    this.open = 'hello',
    this.folders,
    this.pickers,
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
    open: widget.open,
  );

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
      home: IdeShell(
        // A new shell for each project: what ran before is gone.
        key: ObjectKey(_controller.current),
        controller: _controller,
        strings: widget.strings,
      ),
    ),
  );
}
