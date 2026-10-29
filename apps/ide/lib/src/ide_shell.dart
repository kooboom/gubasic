import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import 'code/code_editor.dart';
import 'code/code_font.dart';
import 'code/handlers.dart';
import 'designer/form_designer.dart';
import 'designer/form_edit.dart';
import 'project/app_export.dart' show AppTemplate;
import 'project/open_project.dart';
import 'project/pictures_dialog.dart';

import 'package:gubasic_player/gubasic_player.dart';

import 'project/project_controller.dart';
import 'project/project_forms.dart' show moduleHasMain;
import 'strings.dart';
import 'theme.dart';

/// The IDE's main window: the project's files on the left, the selected
/// file or the running program in the middle, the output below. F5 runs
/// the project, Shift+F5 stops it.
///
/// While a program runs, the file list starts with its run window. The
/// user can look at a file and come back: the run window, with any open
/// MsgBox or InputBox, stays as it was. The files cannot be changed while
/// the program runs.
///
/// The File menu opens and saves projects on disk (D32); the menu at the
/// top right switches between the examples and the project on disk. Both
/// wait while a program runs.
///
/// A form file opens in the form designer (D34). Its undo history lasts
/// as long as this shell: a new project gets a new shell.
class IdeShell extends StatefulWidget {
  const IdeShell({
    super.key,
    required this.controller,
    required this.strings,
    required this.grid,
    this.fitDesigner,
    this.fitRun,
    this.explorerFiles,
    this.autoRun = false,
  });

  /// Runs the project once the IDE has started (IdeApp.autoRun).
  final bool autoRun;

  /// The open project, [ProjectController.current], and the commands
  /// that open and save projects.
  final ProjectController controller;
  final IdeStrings strings;

  /// Whether the designer's grid is on, kept from project to project.
  final ValueNotifier<bool> grid;

  /// Whether the designer and the run window shrink a large form to fit
  /// (D66), each kept from project to project.
  final ValueNotifier<bool>? fitDesigner;
  final ValueNotifier<bool>? fitRun;

  /// Whether the project explorer shows the files on disk rather than the
  /// forms (D94), kept from project to project.
  final ValueNotifier<bool>? explorerFiles;

  @override
  State<IdeShell> createState() => _IdeShellState();
}

class _IdeShellState extends State<IdeShell> {
  Project get _project => widget.controller.current.project;

  late String _chosenFile = _firstFile;

  /// The file shown first: the first form, in the designer, as the
  /// project's look comes first; the code editor, and its font, open when
  /// a code file is chosen (D36).
  String get _firstFile => _project.files.keys.firstWhere(
    (f) => f.endsWith('.form.yaml'),
    orElse: () => _project.files.keys.firstWhere(
      (f) => f.endsWith('.gbas'),
      orElse: () => _project.files.keys.first,
    ),
  );

  /// The file shown; the first form when the chosen one is gone
  /// (Save As renames the .gbproj file).
  String get _file =>
      _project.files.containsKey(_chosenFile) ? _chosenFile : _firstFile;
  set _file(String file) => _chosenFile = file;
  RunSession? _session;

  /// The IDE's focus: its keys (F5, ⌘S…) work while it or anything in it
  /// has the focus.
  final _focus = FocusNode(debugLabel: 'ide');

  @override
  void initState() {
    super.initState();
    // The project open last (D62), then text brought back from a page
    // that closed too soon (D54); each only once.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = widget.controller;
      if (mounted) await controller.openLast(context);
      if (mounted) await controller.showRestored(context);
      if (mounted && widget.autoRun) _run();
    });
  }

  /// Counts the times a file was chosen, so that the code editor takes
  /// the focus each time, also one that stayed built during a run.
  var _codeFocusCount = 0;

  /// The designer's undo history of each form file.
  final _histories = <String, FormHistory>{};

  /// Whether the middle shows the run window rather than [_file].
  var _showRun = false;

  /// Shown instead of a run when the project cannot start.
  var _problems = <_Output>[];

  /// The files as the last run started, or as F5 found them when the
  /// project could not start: to tell whether the line of an error is
  /// still that line.
  Map<String, String> _runFiles = const {};

  /// Where the last run stopped with an error, while the code is still as
  /// it was run (D40).
  ({String file, int line})? get _errorAt {
    final session = _session;
    if (session?.result case RunFailed(:final error, :final file?)) {
      if (_project.files[file] == _runFiles[file]) {
        return (file: file, line: error.line);
      }
    }
    return null;
  }

  /// The lines of [file] with errors that kept the project from starting,
  /// while the file is as it was then (D76).
  Set<int> _problemLinesIn(String file) =>
      _project.files[file] == _runFiles[file]
      ? {
          for (final p in _problems)
            if ((p.file, p.line) case (final f?, final line?) when f == file)
              line,
        }
      : const {};

  bool get _running => _session?.isRunning ?? false;

  void _run() {
    if (_running) return;
    final project = _project;
    final s = widget.strings;
    _session?.dispose();
    _session = null;
    final startup = project.startup;
    if (!project.canRun || startup == null) {
      _runFiles = Map.of(project.files);
      setState(
        () => _problems = [
          (text: s.cannotStart, file: null, line: null),
          for (final d in project.diagnostics)
            if (d.diagnostic.isError)
              (
                text: s.problem(d.file, d.diagnostic),
                file: d.file,
                line: d.diagnostic.line,
              ),
        ],
      );
      return;
    }
    setState(() {
      _problems = [];
      _runFiles = Map.of(project.files);
      _session = RunSession(
        startup,
        strings: s.player,
        project: project.name,
        settings: widget.controller.settings,
        // The pictures as the run starts; they cannot change while it runs.
        pictures: pictureSource(widget.controller.current.pictures),
      );
      _showRun = true;
    });
    // The view that had the focus is hidden now.
    _focus.requestFocus();
  }

  void _stop() => _session?.stop();

  @override
  void dispose() {
    if (widget.explorerFiles == null) _explorerFiles.dispose();
    _clickTimer?.cancel();
    _focus.dispose();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final session = _session;
    final controller = widget.controller;
    final files =
        (controller.canUseFolders || controller.canUseBrowser) && !_running;
    // On macOS a running program's menus go on the system's menu bar
    // (D106).
    return SystemMenus(
      appName: 'GuBASIC',
      strings: s.player,
      session: session,
      // While no program runs, the standard Edit menu (D110).
      editMenu: true,
      child: _shell(context, s, session, controller, files),
    );
  }

  Widget _shell(
    BuildContext context,
    IdeStrings s,
    RunSession? session,
    ProjectController controller,
    bool files,
  ) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): _run,
        const SingleActivator(LogicalKeyboardKey.f5, shift: true): _stop,
        if (files) ...{
          _shortcut(LogicalKeyboardKey.keyO): _open,
          _shortcut(LogicalKeyboardKey.keyS): _save,
          _shortcut(LogicalKeyboardKey.keyS, shift: true): _saveAs,
        },
        if (files && controller.canUseBrowser)
          _shortcut(LogicalKeyboardKey.keyE, shift: true): _download,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            session ?? const _Never(),
            widget.controller,
            widget.controller.current,
            // The code font arrives later; code shows in it from then on.
            CodeFont.loaded,
          ]),
          builder: (context, _) => Scaffold(
            appBar: AppBar(
              // The File menu at the top left, where Visual Basic and most
              // desktop programs have it.
              leading: controller.canUseFolders || controller.canUseBrowser
                  ? _fileMenu(context)
                  : null,
              leadingWidth: 96,
              automaticallyImplyLeading: false,
              title: Text(
                widget.controller.current.isDirty
                    ? '${_project.name} — ${widget.strings.edited}'
                    : _project.name,
              ),
              // On the web, the .zip is what keeps a project safe (D33):
              // its button is always there, and stands out while there are
              // changes that were not downloaded.
              bottom: controller.canUseBrowser ? _browserStatus(context) : null,
              actions: [
                if (controller.canUseBrowser) _downloadButton(context),
                if (widget.controller.menuEntries.length > 1)
                  DropdownButton<String>(
                    value: widget.controller.currentKey,
                    underline: const SizedBox(),
                    onChanged: _running
                        ? null
                        : (key) => widget.controller.choose(context, key!),
                    items: [
                      for (final (key, label) in widget.controller.menuEntries)
                        DropdownMenuItem(value: key, child: Text(label)),
                    ],
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _running ? null : _run,
                  icon: const Icon(Icons.play_arrow),
                  label: Text('${s.run} (F5)'),
                ),
                TextButton.icon(
                  onPressed: _running ? _stop : null,
                  icon: const Icon(Icons.stop),
                  label: Text('${s.stop} (Shift+F5)'),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 220, child: _explorer(context)),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _main(context)),
                      const Divider(height: 1),
                      SizedBox(height: 160, child: _output(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open() => widget.controller.canUseBrowser
      ? widget.controller.openKept(context)
      : widget.controller.open(context);
  void _download() => widget.controller.downloadZip(context);
  void _upload() => widget.controller.uploadZip(context);

  Widget _downloadButton(BuildContext context) {
    final s = widget.strings;
    final changed = widget.controller.changedSinceDownload;
    final label = Text(s.downloadZip);
    const icon = Icon(Icons.download);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: changed
            ? '${s.downloadZipHint}\n${s.changedSinceDownloadHint}'
            : s.downloadZipHint,
        child: changed
            ? FilledButton.icon(onPressed: _download, icon: icon, label: label)
            : OutlinedButton.icon(
                onPressed: _download,
                icon: icon,
                label: label,
              ),
      ),
    );
  }

  PreferredSizeWidget _browserStatus(BuildContext context) {
    final s = widget.strings;
    final controller = widget.controller;
    final text = switch (controller.current.location) {
      BrowserLocation(:final name) => s.keptStatus.replaceAll(
        '{0}',
        switch (controller.kept?.read(name)?.downloadedAt) {
          final at? => formatTime(at),
          null => s.none,
        },
      ),
      _ => s.exampleStatus,
    };
    return PreferredSize(
      preferredSize: const Size.fromHeight(24),
      child: Container(
        height: 24,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: controller.storageFailed
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          controller.storageFailed ? s.storageFailed : text,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }

  void _pictures() => showDialog<void>(
    context: context,
    builder: (context) => PicturesDialog(controller: widget.controller),
  );

  /// Opens [file], a form or code file, as a click in the list does.
  void _openFile(String? file) {
    if (file == null || !mounted) return;
    setState(() {
      _file = file;
      _showRun = false;
    });
    _focus.requestFocus();
  }

  /// File → Add Form (D88): the new form opens in the designer.
  Future<void> _addForm() async =>
      _openFile(await widget.controller.addForm(context));

  /// File → Add Module (D102): the new module's code opens.
  Future<void> _addModule() async =>
      _openFile(await widget.controller.addModule(context));

  /// What a module's ⋮ menu in the project explorer does (D102).
  Future<void> _moduleAction(String module, String action) async {
    final controller = widget.controller;
    switch (action) {
      case 'main':
        controller.startWithMain();
      case 'rename':
        final open = _file;
        final file = await controller.renameModule(context, module);
        if (file != null &&
            open.toLowerCase() == '${module.toLowerCase()}.gbas') {
          _openFile(file);
        }
      case 'delete':
        if (await controller.deleteModule(context, module) &&
            !_project.files.containsKey(_file)) {
          _openFile('${controller.forms.first}.form.yaml');
        }
    }
  }

  /// What a form's ⋮ menu in the project list does (D88).
  Future<void> _formAction(String form, String action) async {
    final controller = widget.controller;
    switch (action) {
      case 'startup':
        controller.makeStartupForm(form);
      case 'rename':
        // The file open before: renaming takes it away.
        final open = _file;
        final file = await controller.renameForm(context, form);
        if (file != null &&
            open.toLowerCase().startsWith('${form.toLowerCase()}.')) {
          _openFile(file);
        }
      case 'delete':
        if (await controller.deleteForm(context, form) &&
            !_project.files.containsKey(_file)) {
          _openFile('${controller.forms.first}.form.yaml');
        }
    }
  }

  void _save() => widget.controller.save(context);
  void _saveAs() => widget.controller.saveAs(context);

  Widget _fileMenu(BuildContext context) {
    final s = widget.strings;
    MenuItemButton item(
      String label,
      VoidCallback action,
      LogicalKeyboardKey key, {
      bool shift = false,
    }) => MenuItemButton(
      onPressed: _running ? null : action,
      shortcut: _shortcut(key, shift: shift),
      child: Text(label),
    );
    return MenuAnchor(
      menuChildren: [
        if (widget.controller.canCreateProjects)
          MenuItemButton(
            key: const ValueKey('menu.newProject'),
            onPressed: _running
                ? null
                : () => widget.controller.newProject(context),
            child: Text(s.newProject),
          ),
        item(s.open, _open, LogicalKeyboardKey.keyO),
        item(s.save, _save, LogicalKeyboardKey.keyS),
        item(s.saveAs, _saveAs, LogicalKeyboardKey.keyS, shift: true),
        const Divider(),
        MenuItemButton(
          key: const ValueKey('menu.addForm'),
          onPressed: _running ? null : _addForm,
          child: Text(s.addForm),
        ),
        MenuItemButton(
          key: const ValueKey('menu.addModule'),
          onPressed: _running ? null : _addModule,
          child: Text(s.addModule),
        ),
        MenuItemButton(
          key: const ValueKey('menu.pictures'),
          onPressed: _running ? null : _pictures,
          child: Text(s.picturesMenu),
        ),
        MenuItemButton(
          key: const ValueKey('menu.clearSettings'),
          onPressed: _running
              ? null
              : () => widget.controller.clearSettings(context),
          child: Text(s.clearSettings),
        ),
        if (widget.controller.canExportApps) ...[
          const Divider(),
          MenuItemButton(
            key: const ValueKey('menu.exportWebApp'),
            onPressed: _running
                ? null
                : () => widget.controller.exportApp(context, AppTemplate.web),
            child: Text(s.exportWebApp),
          ),
          MenuItemButton(
            key: const ValueKey('menu.exportWindowsApp'),
            onPressed: _running
                ? null
                : () =>
                      widget.controller.exportApp(context, AppTemplate.windows),
            child: Text(s.exportWindowsApp),
          ),
          // Greyed out, saying why, where macOS apps cannot be made (D87).
          if (widget.controller.canExportMacApp)
            MenuItemButton(
              key: const ValueKey('menu.exportMacApp'),
              onPressed: _running
                  ? null
                  : () =>
                        widget.controller.exportApp(context, AppTemplate.macos),
              child: Text(s.exportMacApp),
            )
          else
            Tooltip(
              message: s.macAppOnlyOnMacWhy,
              child: MenuItemButton(
                key: const ValueKey('menu.exportMacApp'),
                child: Text('${s.exportMacApp} (${s.macAppOnlyOnMac})'),
              ),
            ),
        ],
        if (widget.controller.canUseBrowser) ...[
          const Divider(),
          item(s.downloadZip, _download, LogicalKeyboardKey.keyE, shift: true),
          MenuItemButton(
            onPressed: _running ? null : _upload,
            child: Text(s.uploadZip),
          ),
          const Divider(),
          MenuItemButton(
            key: const ValueKey('menu.playground'),
            onPressed: () => widget.controller.browser!.open('../'),
            child: Text(s.openPlayground),
          ),
        ],
      ],
      builder: (context, menu, _) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: TextButton(
          onPressed: () => menu.isOpen ? menu.close() : menu.open(),
          child: Text(s.fileMenu),
        ),
      ),
    );
  }

  /// Whether the explorer shows the files on disk (D94); a shell of its
  /// own keeps it when the IDE does not.
  late final _explorerFiles = widget.explorerFiles ?? ValueNotifier(false);

  /// The project explorer (D94): the forms, as Visual Basic shows a
  /// project, or the files as they are on disk.
  Widget _explorer(BuildContext context) => ValueListenableBuilder(
    valueListenable: _explorerFiles,
    builder: (context, showFiles, _) => ListView(
      children: [
        if (_running)
          ListTile(
            dense: true,
            leading: const Icon(Icons.play_arrow),
            title: Text(widget.strings.runWindow),
            selected: _showRun,
            onTap: () {
              setState(() => _showRun = true);
              _focus.requestFocus();
            },
          ),
        _explorerHeader(context, showFiles),
        if (showFiles)
          for (final f in _project.files.keys) _fileTile(context, f)
        else
          ..._formTiles(context),
        // The project's pictures, a group of their own (D68): a click
        // opens File → Pictures.
        if (widget.controller.current.pictures.isNotEmpty) ...[
          ListTile(
            key: const ValueKey('files.pictures'),
            dense: true,
            leading: const Icon(Icons.image_outlined, size: 18),
            title: Text(widget.strings.picturesGroup),
            onTap: _running ? null : _pictures,
          ),
          for (final name in widget.controller.current.pictures.keys)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 36, right: 10),
              title: Text(name),
              onTap: _running ? null : _pictures,
            ),
        ],
        // In the forms view the project's settings come last, as a line
        // of their own.
        if (!showFiles)
          for (final f in _project.files.keys)
            if (f.toLowerCase().endsWith('.gbproj'))
              _fileTile(
                context,
                f,
                key: const ValueKey('explorer.settings'),
                leading: const Icon(Icons.settings_outlined, size: 18),
                subtitle: widget.strings.projectSettings,
              ),
      ],
    ),
  );

  /// "Project", and the switch between the forms and the files.
  Widget _explorerHeader(BuildContext context, bool showFiles) {
    final s = widget.strings;
    return ListTile(
      dense: true,
      title: Text(s.files),
      trailing: Tooltip(
        message: s.explorerViewHint,
        child: SegmentedButton<bool>(
          key: const ValueKey('explorer.view'),
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity(horizontal: -4, vertical: -4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          segments: [
            ButtonSegment(value: false, label: Text(s.explorerForms)),
            ButtonSegment(value: true, label: Text(s.explorerFiles)),
          ],
          selected: {showFiles},
          onSelectionChanged: (chosen) => _explorerFiles.value = chosen.first,
        ),
      ),
    );
  }

  /// A file of the project, as it is on disk; the file shown is in the
  /// accent colour (D68).
  Widget _fileTile(
    BuildContext context,
    String f, {
    Key? key,
    Widget? leading,
    String? subtitle,
  }) => ListTile(
    key: key,
    dense: true,
    leading: leading,
    title: Text(f),
    // A form's actions, and which one starts (D88).
    subtitle: subtitle != null
        ? Text(subtitle)
        : f == '${widget.controller.startupForm}.form.yaml' &&
              widget.controller.forms.length > 1
        ? Text(widget.strings.startupFormTag)
        : null,
    trailing: _formMenu(f),
    // The open file in the accent colour, not a grey (D68).
    selectedColor: Theme.of(context).colorScheme.primary,
    selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
    selected: f == _file && !(_running && _showRun),
    onTap: () => _show(f),
  );

  /// Shows [file] in the middle.
  void _show(String file) {
    setState(() {
      _file = file;
      _showRun = false;
      _codeFocusCount++;
    });
    // The IDE takes the focus, so that F5 and ⌘S work: the view that had
    // it may be hidden now. A designer or code editor that opens takes it
    // next.
    _focus.requestFocus();
  }

  /// One line for each form (D94), then the project's other files that
  /// are not its settings (none in a project GuBASIC wrote).
  List<Widget> _formTiles(BuildContext context) {
    final files = _project.files;
    final forms = widget.controller.forms;
    final modules = widget.controller.modules;
    final listed = {
      for (final form in forms) ...['$form.form.yaml', '$form.gbas'],
      for (final module in modules) '$module.gbas',
    };
    return [
      for (final form in forms) _formTile(context, form),
      // The modules (D102), a group of their own.
      if (modules.isNotEmpty) ...[
        ListTile(
          key: const ValueKey('explorer.modules'),
          dense: true,
          leading: const Icon(Icons.data_object, size: 18),
          title: Text(widget.strings.modulesGroup),
        ),
        for (final module in modules) _moduleTile(context, module),
      ],
      for (final f in files.keys)
        if (!listed.contains(f) && !f.toLowerCase().endsWith('.gbproj'))
          _fileTile(context, f),
    ];
  }

  /// A module's line (D102): a click opens its code; it says when the
  /// project starts with its Sub Main.
  Widget _moduleTile(BuildContext context, String module) {
    final s = widget.strings;
    final file = '$module.gbas';
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final hasMain = moduleHasMain(_project.files, module);
    return ListTile(
      key: ValueKey('explorer.module.$module'),
      dense: true,
      contentPadding: const EdgeInsets.only(left: 36, right: 4),
      title: Text(module, overflow: TextOverflow.ellipsis),
      subtitle: controller.startsWithMain && hasMain
          ? Text(s.startupFormTag)
          : null,
      trailing: PopupMenuButton<String>(
        key: ValueKey('files.module.$module'),
        tooltip: s.moduleActions,
        enabled: !_running,
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (action) => _moduleAction(module, action),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'main',
            enabled: hasMain && !controller.startsWithMain,
            child: Text(s.startWithMain),
          ),
          PopupMenuItem(value: 'rename', child: Text(s.renameModule)),
          PopupMenuItem(value: 'delete', child: Text(s.deleteModule)),
        ],
      ),
      selectedColor: scheme.primary,
      selectedTileColor: scheme.primaryContainer,
      selected: file == _file && !(_running && _showRun),
      onTap: () => _show(file),
    );
  }

  /// The form clicked in the explorer within the last double-click time:
  /// a second click on it opens its code (D94). The first click opens the
  /// design at once, without waiting to see whether a second comes.
  String? _clickedForm;
  Timer? _clickTimer;

  /// A form's line: its name, its Caption and whether it starts; a click
  /// opens its design, a double-click its code (D94).
  Widget _formTile(BuildContext context, String form) {
    final s = widget.strings;
    final design = '$form.form.yaml';
    final code = '$form.gbas';
    final shown = !(_running && _showRun) ? _file : null;
    final caption = _captionOf(form);
    final startup =
        form == widget.controller.startupForm &&
        widget.controller.forms.length > 1;
    final subtitle = [
      if (startup) s.startupFormTag,
      if (caption.isNotEmpty) caption,
    ].join(' · ');
    final scheme = Theme.of(context).colorScheme;
    Widget open(String file, IconData icon, String tooltip, String key) =>
        IconButton(
          key: ValueKey('explorer.$key.$form'),
          tooltip: tooltip,
          isSelected: shown == file,
          color: shown == file ? scheme.primary : null,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          iconSize: 16,
          icon: Icon(icon),
          onPressed: _has(file) ? () => _show(file) : null,
        );
    return ListTile(
      key: ValueKey('explorer.form.$form'),
      dense: true,
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      title: Text(form, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          open(design, Icons.design_services_outlined, s.viewDesign, 'design'),
          open(code, Icons.code, s.viewCode, 'code'),
          ?_formMenu(design),
        ],
      ),
      selectedColor: scheme.primary,
      selectedTileColor: scheme.primaryContainer,
      selected: shown == design || shown == code,
      onTap: () {
        final second = _clickedForm == form;
        _clickTimer?.cancel();
        _clickedForm = second ? null : form;
        if (!second) {
          _clickTimer = Timer(kDoubleTapTimeout, () => _clickedForm = null);
        }
        if (second && _has(code)) {
          _show(code);
        } else if (_has(design)) {
          _show(design);
        } else if (_has(code)) {
          _show(code);
        }
      },
    );
  }

  /// Whether the project has [file]; a form's code file may be missing
  /// until its first handler.
  bool _has(String file) => _project.files.containsKey(file);

  /// The `Caption` of [form], as its file says; empty when it cannot be
  /// read.
  String _captionOf(String form) {
    final text = _project.files['$form.form.yaml'];
    if (text == null) return '';
    final value = readFormFile(text, name: form).form.valueOf('Caption');
    return value is String ? value : '';
  }

  /// The ⋮ menu of a form's file in the project list (D88); null for
  /// other files.
  Widget? _formMenu(String file) {
    final form = _formOf(file);
    if (form == null) return null;
    final s = widget.strings;
    return PopupMenuButton<String>(
      key: ValueKey('files.form.$form'),
      tooltip: s.formActions,
      enabled: !_running,
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (action) => _formAction(form, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'startup',
          enabled: form != widget.controller.startupForm,
          child: Text(s.makeStartupForm),
        ),
        PopupMenuItem(value: 'rename', child: Text(s.renameForm)),
        PopupMenuItem(
          value: 'delete',
          enabled: widget.controller.forms.length > 1,
          child: Text(s.deleteForm),
        ),
      ],
    );
  }

  /// The form [file] is the design of (`Form2.form.yaml` → `Form2`), when
  /// the project lists it; null for other files.
  String? _formOf(String file) {
    if (!file.endsWith('.form.yaml')) return null;
    final form = file.substring(0, file.length - '.form.yaml'.length);
    return widget.controller.forms.contains(form) ? form : null;
  }

  /// The last request to the code editor to go to a handler.
  GoTo? _goTo;

  /// A double-click on [control] (the form when null) in the designer of
  /// [formFile]: the code editor opens on the default event's handler,
  /// which is added first if there is none (D38). While a program runs,
  /// only a handler that is there opens.
  void _openHandler(String formFile, String? control) {
    final formName = formFile.substring(
      0,
      formFile.length - '.form.yaml'.length,
    );
    final codeFile = '$formName.gbas';
    final form = readFormFile(
      _project.files[formFile] ?? '',
      name: formName,
    ).form;
    final decl = control == null ? null : form.control(control);
    final name = decl?.name ?? 'Form';
    final component = decl?.component ?? formComponent;
    final event = component.events[component.defaultEvent.toLowerCase()]!;
    final code = _project.files[codeFile] ?? '';
    // The procedure that handles the event by Handles (D98), or the one
    // named for it.
    final handler =
        procedureHandling(code, name, event.name) ?? '${name}_${event.name}';
    if (_running && procedureNamed(code, handler) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.strings.noHandlerWhileRunning.replaceAll('{0}', handler),
          ),
        ),
      );
      return;
    }
    if (!_project.files.containsKey(codeFile)) {
      widget.controller.current.setFile(codeFile, '');
    }
    setState(() {
      _file = codeFile;
      _showRun = false;
      _codeFocusCount++;
      _goTo = GoTo((_goTo?.id ?? 0) + 1, handler, event.handlerSignature(name));
    });
  }

  Widget _main(BuildContext context) {
    final session = _session;
    final file = _file;
    final code = file.endsWith('.form.yaml')
        ? FormDesigner(
            key: ValueKey(file),
            project: widget.controller.current,
            file: file,
            history: _histories.putIfAbsent(file, FormHistory.new),
            grid: widget.grid,
            fit: widget.fitDesigner,
            locked: _running,
            strings: widget.strings,
            onOpenHandler: (control) => _openHandler(file, control),
            onAddPicture: () => widget.controller.addPicture(context),
          )
        : file.toLowerCase().endsWith('.gbas')
        ? CodeEditor(
            key: ValueKey(file),
            project: widget.controller.current,
            file: file,
            locked: _running,
            strings: widget.strings,
            focusCount: _codeFocusCount,
            goTo: _goTo,
            errorLine: _errorAt?.file == file ? _errorAt!.line : null,
            problemLines: _problemLinesIn(file),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText(_project.files[file]!, style: codeStyle),
          );
    final running = session != null && session.result == null;
    // The run window stays built while a file is shown, so that its
    // dialogs are still there, unanswered, when the user comes back. The
    // file's view keeps its place in the stack, run or no run, so that the
    // code editor and the designer keep their state (the caret, the undo
    // history) across a run.
    return IndexedStack(
      index: running && _showRun ? 1 : 0,
      sizing: StackFit.expand,
      children: [
        code,
        if (running)
          ColoredBox(
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.2),
            child: RunWindow(
              key: ObjectKey(session),
              session: session,
              fit: widget.fitRun,
            ),
          ),
      ],
    );
  }

  /// A click on an error in the output: its code file opens on its line
  /// (D40).
  void _goToLine(String file, int line) {
    setState(() {
      _file = file;
      _showRun = false;
      _codeFocusCount++;
      _goTo = GoTo.line((_goTo?.id ?? 0) + 1, line);
    });
  }

  /// How a run ended, in words.
  String _endMessage(RunResult result, String codeFile) {
    final s = widget.strings;
    return switch (result) {
      RunCompleted() => s.closed,
      RunEnded() => s.ended,
      RunStopped() => s.stopped,
      RunFailed(:final error) => s.problem(codeFile, error),
      RunNotStarted() => s.cannotStart,
    };
  }

  /// The code file a run ended in: the error's, or the startup form's.
  static String _endFile(RunResult result, RunSession session) =>
      switch (result) {
        RunFailed(:final file?) => file,
        _ => session.startup.codeFile,
      };

  Widget _output(BuildContext context) {
    final session = _session;
    final error = switch (session?.result) {
      RunFailed(:final error) => error,
      _ => null,
    };
    final lines = <_Output>[
      ..._problems,
      for (final l in session?.output ?? const <String>[])
        (text: l, file: null, line: null),
      if (session?.result case final result?)
        (
          // The file of the form whose code stopped (D88).
          text: _endMessage(result, _endFile(result, session!)),
          file: _endFile(result, session),
          line: error?.line,
        ),
    ];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Text(
            widget.strings.output,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              for (final l in lines)
                if ((l.file, l.line) case (final file?, final line?)
                    when _project.files.containsKey(file) &&
                        file.toLowerCase().endsWith('.gbas'))
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _goToLine(file, line),
                      child: Tooltip(
                        message: widget.strings.goToLine
                            .replaceAll('{0}', file)
                            .replaceAll('{1}', '$line'),
                        child: Text(
                          l.text,
                          style: codeStyle.copyWith(
                            color: theme.colorScheme.error,
                            decoration: TextDecoration.underline,
                            decorationColor: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SelectableText(l.text, style: codeStyle),
            ],
          ),
        ),
      ],
    );
  }
}

/// ⌘ and [key] on Apple systems, Ctrl and [key] elsewhere.
SingleActivator _shortcut(LogicalKeyboardKey key, {bool shift = false}) {
  final apple = switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.iOS => true,
    _ => false,
  };
  return SingleActivator(key, meta: apple, control: !apple, shift: shift);
}

/// A listenable that never changes, for when nothing runs.
class _Never implements Listenable {
  const _Never();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// A line of the output, and the code line it is about, if any.
typedef _Output = ({String text, String? file, int? line});
