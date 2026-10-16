import 'dart:ui';

import 'package:flutter/material.dart';

import 'src/ide_shell.dart';
import 'src/project/examples.g.dart';
import 'src/project/project.dart';
import 'src/strings.dart';
import 'src/theme.dart';

/// The GuBASIC IDE. For now it opens the example projects and runs them
/// in a run window (docs/ROADMAP.md, stage 1).
void main() {
  final language = PlatformDispatcher.instance.locale.languageCode;
  runApp(
    IdeApp(
      projects: exampleProjects,
      strings: IdeStrings.forLanguage(language),
    ),
  );
}

class IdeApp extends StatefulWidget {
  const IdeApp({
    super.key,
    required this.projects,
    required this.strings,
    this.open = 'hello',
  });

  /// The projects that can be opened: name → files.
  final Map<String, Map<String, String>> projects;
  final IdeStrings strings;

  /// The project opened first.
  final String open;

  @override
  State<IdeApp> createState() => _IdeAppState();
}

class _IdeAppState extends State<IdeApp> {
  late String _open = widget.open;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GuBASIC',
    debugShowCheckedModeBanner: false,
    theme: ideTheme,
    home: IdeShell(
      // A new shell for each project: what ran before is gone.
      key: ValueKey(_open),
      project: Project.read(widget.projects[_open]!),
      strings: widget.strings,
      projects: widget.projects.keys.toList(),
      openProject: _open,
      onOpenProject: (name) => setState(() => _open = name),
    ),
  );
}
