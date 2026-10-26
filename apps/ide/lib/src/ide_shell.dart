import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import 'code/code_editor.dart';
import 'code/code_font.dart';
import 'code/handlers.dart';
import 'designer/form_designer.dart';
import 'designer/form_edit.dart';
import 'project/open_project.dart';
import 'project/pictures_dialog.dart';

import 'package:gubasic_player/gubasic_player.dart';

import 'project/project_controller.dart';
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
    if (session?.result case RunFailed(:final error)) {
      final file = session!.startup.codeFile;
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
                SizedBox(width: 200, child: _fileList(context)),
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
        message: changed ? s.changedSinceDownloadHint : '',
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
        if (widget.controller.canExportWebApp) ...[
          const Divider(),
          MenuItemButton(
            key: const ValueKey('menu.exportWebApp'),
            onPressed: _running
                ? null
                : () => widget.controller.exportWebApp(context),
            child: Text(s.exportWebApp),
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

  Widget _fileList(BuildContext context) => ListView(
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
      ListTile(dense: true, title: Text(widget.strings.files)),
      for (final f in _project.files.keys)
        ListTile(
          dense: true,
          title: Text(f),
          // The open file in the accent colour, not a grey (D68).
          selectedColor: Theme.of(context).colorScheme.primary,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          selected: f == _file && !(_running && _showRun),
          onTap: () {
            setState(() {
              _file = f;
              _showRun = false;
              _codeFocusCount++;
            });
            // The IDE takes the focus, so that F5 and ⌘S work: the view that
            // had it may be hidden now. A designer or code editor that
            // opens takes it next.
            _focus.requestFocus();
          },
        ),
      // The project's pictures, a group of their own (D68): a click opens
      // File → Pictures.
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
    ],
  );

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
    final handler = '${name}_${event.name}';
    final code = _project.files[codeFile] ?? '';
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
          text: _endMessage(result, session!.startup.codeFile),
          file: session.startup.codeFile,
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
