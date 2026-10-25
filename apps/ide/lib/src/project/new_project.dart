import 'package:flutter/material.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import '../designer/form_edit.dart';
import '../strings.dart';
import 'folders.dart';

/// What File → New Project asks for (D63).
typedef NewProject = ({String name, String caption, FormSizePreset size});

/// The files of a new project [name]: its `.gbproj`, and an empty Form1
/// with [caption], at [size], and no code yet.
Map<String, String> newProjectFiles(
  String name,
  String caption,
  FormSizePreset size,
) {
  final preset = formSizePresets.firstWhere((p) => p.name == size);
  return renameProject({
    'Project.gbproj': writeProjectFile(
      ProjectFile(name: name, forms: const ['Form1'], startup: 'Form1'),
    ),
    'Form1.form.yaml': writeFormFile(
      FormFile(
        name: 'Form1',
        properties: {
          'Caption': caption,
          'Width': preset.width,
          'Height': preset.height,
        },
        controls: const [],
      ),
    ),
    'Form1.gbas': '',
  }, name);
}

/// File → New Project (D63): the project's name, its form's Caption
/// (the name, until it is changed) and its size, Desktop first.
class NewProjectDialog extends StatefulWidget {
  const NewProjectDialog({super.key, required this.strings, this.notice});

  final IdeStrings strings;

  /// What to say first: on the web, the first time, that a project kept
  /// in the browser can be lost (D67).
  final String? notice;

  @override
  State<NewProjectDialog> createState() => _NewProjectDialogState();
}

/// The keys of the New Project dialog's fields, for tests.
const newProjectNameKey = ValueKey('newProject.name');
const newProjectCaptionKey = ValueKey('newProject.caption');

class _NewProjectDialogState extends State<NewProjectDialog> {
  final _name = TextEditingController();
  final _caption = TextEditingController();

  /// Whether the Caption was typed, not taken from the name.
  var _captionTyped = false;
  var _size = FormSizePreset.desktop;

  @override
  void dispose() {
    _name.dispose();
    _caption.dispose();
    super.dispose();
  }

  bool get _usable => isUsableProjectName(_name.text);

  void _ok() {
    if (!_usable) return;
    Navigator.pop<NewProject>(context, (
      name: _name.text,
      caption: _caption.text,
      size: _size,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    String sizeName(FormSizePreset p) => switch (p) {
      FormSizePreset.phone => s.phonePreset,
      FormSizePreset.tablet => s.tabletPreset,
      FormSizePreset.desktop => s.desktopPreset,
    };
    return AlertDialog(
      title: Text(s.newProjectTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.notice case final notice?) ...[
              Text(notice),
              const SizedBox(height: 12),
            ],
            TextField(
              key: newProjectNameKey,
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: s.projectName,
                errorText: _name.text.isEmpty || _usable
                    ? null
                    : s.badProjectName,
                errorMaxLines: 3,
              ),
              onChanged: (name) => setState(() {
                if (!_captionTyped) _caption.text = name;
              }),
              onSubmitted: (_) => _ok(),
            ),
            const SizedBox(height: 12),
            TextField(
              key: newProjectCaptionKey,
              controller: _caption,
              decoration: InputDecoration(labelText: s.formCaption),
              onChanged: (_) => _captionTyped = true,
              onSubmitted: (_) => _ok(),
            ),
            const SizedBox(height: 16),
            Text(
              s.formSizeLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<FormSizePreset>(
              segments: [
                for (final p in formSizePresets)
                  ButtonSegment(
                    value: p.name,
                    label: Text('${sizeName(p.name)} ${p.width}×${p.height}'),
                  ),
              ],
              selected: {_size},
              showSelectedIcon: false,
              onSelectionChanged: (chosen) =>
                  setState(() => _size = chosen.single),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.runtime.cancel),
        ),
        FilledButton(
          onPressed: _usable ? _ok : null,
          child: Text(s.createButton),
        ),
      ],
    );
  }
}
