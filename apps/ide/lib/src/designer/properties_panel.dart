import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart'
    show ComposingTracker, committedText;

import '../project/project_pictures.dart';
import '../strings.dart';

/// The key of the list that chooses what the window shows.
const propertiesTargetKey = ValueKey('properties.target');

/// The key of the value field of [property].
ValueKey<String> propertyFieldKey(String property) =>
    ValueKey('properties.$property');

/// The key of the arm of the Anchor field's cross for [edge] (`Left`).
ValueKey<String> anchorArmKey(String edge) =>
    ValueKey('properties.anchor.$edge');

/// The Properties window (D35): a list to choose the form or a control,
/// then its name and properties, in its component.yaml's order. Values
/// apply as they are typed; values that are not valid are not applied
/// and say why.
class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({
    super.key,
    required this.form,
    required this.selected,
    this.chosen = 0,
    required this.editable,
    required this.strings,
    required this.onSelect,
    required this.onChange,
    required this.onDone,
    required this.onLeave,
    required this.code,
    required this.codeFile,
    required this.onRename,
    this.onPreview,
    this.pictures = const [],
    this.onAddPicture,
  });

  final FormFile form;

  /// The project's pictures, which a picture property chooses from (D51).
  final List<String> pictures;

  /// Adds a picture to the project: its name, or null when none was.
  final Future<String?> Function()? onAddPicture;

  /// The form's code, and the name of its file, to see whether a name is
  /// used there.
  final String code;
  final String codeFile;

  /// Renames the control named [name] to [newName].
  final void Function(String name, String newName) onRename;

  /// Shows [text] as [property] of [control] (null for the form) on the
  /// form while it is typed, the syllable being composed included; the
  /// file gets only what is committed ([onChange]).
  final void Function(String? control, String property, String text)? onPreview;

  /// The control shown; null for the form.
  final ControlDecl? selected;

  /// How many controls are chosen in the designer: when several, the
  /// window shows none of them, and says to choose one.
  final int chosen;
  final bool editable;
  final IdeStrings strings;

  /// Chooses the control named so, or the form (null).
  final void Function(String? name) onSelect;

  /// Sets [property] of [control] (null for the form) to [value]. Changes
  /// with the same [group] are one step of undo.
  final void Function(
    String? control,
    String property,
    Object value,
    Object group,
  )
  onChange;

  /// Ends the current step of undo.
  final VoidCallback onDone;

  /// Gives the focus back to the form.
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final control = selected;
    final component = control?.component ?? form.component;
    final target = control?.name;
    Object valueOf(PropertySpec p) =>
        control?.valueOf(p.name) ?? form.valueOf(p.name);
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(strings.properties, style: theme.textTheme.labelLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              key: propertiesTargetKey,
              isExpanded: true,
              value: chosen > 1 ? null : target ?? '',
              // Several controls chosen: none of them is shown.
              hint: chosen > 1
                  ? Text(strings.chosenControls.replaceAll('{0}', '$chosen'))
                  : null,
              underline: const SizedBox(),
              onChanged: (name) => onSelect(name!.isEmpty ? null : name),
              items: [
                _target(context, '', form.name, form.component.name),
                for (final c in form.controls)
                  _target(context, c.name, c.name, c.component.name),
              ],
            ),
          ),
          const Divider(height: 1),
          if (chosen > 1)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                strings.chooseOneControl,
                style: TextStyle(color: theme.hintColor),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _row(
                    context,
                    '(Name)',
                    control == null
                        ? Tooltip(
                            message: strings.formNameIsFile,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                form.name,
                                key: propertyFieldKey('(Name)'),
                                style: TextStyle(color: theme.disabledColor),
                              ),
                            ),
                          )
                        : NameField(
                            key: ValueKey('${control.name}.(Name)'),
                            form: form,
                            control: control,
                            code: code,
                            codeFile: codeFile,
                            editable: editable,
                            strings: strings,
                            onRename: onRename,
                            onLeave: onLeave,
                          ),
                  ),
                  for (final p in component.designProperties)
                    _row(
                      context,
                      p.name,
                      PropertyField(
                        key: ValueKey('${target ?? ''}.${p.name}'),
                        spec: p,
                        value: valueOf(p),
                        editable: editable,
                        strings: strings,
                        onChange: (v, group) =>
                            onChange(target, p.name, v, group),
                        onPreview: onPreview == null
                            ? null
                            : (text) => onPreview!(target, p.name, text),
                        onDone: onDone,
                        onLeave: onLeave,
                        pictures: pictures,
                        onAddPicture: onAddPicture,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  DropdownMenuItem<String> _target(
    BuildContext context,
    String value,
    String name,
    String type,
  ) => DropdownMenuItem(
    value: value,
    child: Row(
      children: [
        Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Text(type, style: TextStyle(color: Theme.of(context).hintColor)),
      ],
    ),
  );

  Widget _row(BuildContext context, String name, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(child: value),
      ],
    ),
  );
}

/// One property's value: a field for text and numbers, a check box for
/// Boolean. Text applies as it is typed, the letters typed while the
/// field has the focus being one step of undo. A number applies on Enter
/// or when the field is left: while it is typed it passes through values
/// nobody meant (erasing 120 gives 12, then 1), so those are only checked.
/// Leaving the field with a value that is not valid shows the property's
/// value again; Esc puts it back and gives the focus to the form.
///
/// As in a TextBox (LANGUAGE.md §11.1), only the characters the input
/// method has committed reach the form: 한 is not written while it is
/// still being composed. Leaving the field or Enter commits what is being
/// composed; Esc while composing drops only that, and a second Esc puts
/// the value back.
class PropertyField extends StatefulWidget {
  const PropertyField({
    super.key,
    required this.spec,
    required this.value,
    required this.editable,
    required this.strings,
    required this.onChange,
    required this.onDone,
    required this.onLeave,
    this.onPreview,
    this.pictures = const [],
    this.onAddPicture,
  });

  final PropertySpec spec;
  final Object value;
  final bool editable;
  final IdeStrings strings;
  final void Function(Object value, Object group) onChange;
  final VoidCallback onDone;
  final VoidCallback onLeave;

  /// Text as it shows in the field, being composed or not.
  final void Function(String text)? onPreview;

  /// For a picture property: the project's pictures, and how to add one.
  final List<String> pictures;
  final Future<String?> Function()? onAddPicture;

  @override
  State<PropertyField> createState() => _PropertyFieldState();
}

class _PropertyFieldState extends State<PropertyField> {
  late final _controller = TextEditingController(text: _show(widget.value));
  final _focus = FocusNode();

  /// The step of undo the letters typed now belong to.
  var _group = Object();

  /// The value when the field took the focus, for Esc.
  late Object _start = widget.value;
  String? _error;

  /// What is being composed, as the platform says or as guessed where it
  /// says nothing (the macOS app, D37).
  late final _tracker = ComposingTracker(_controller.value);

  /// The text last written to the form from this field.
  late String _written = _show(widget.value);

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
    _controller.addListener(_valueChanged);
  }

  @override
  void didUpdateWidget(PropertyField old) {
    super.didUpdateWidget(old);
    // Undo, the mouse or another window changed it: show it, unless the
    // user is typing here.
    if (!_focus.hasFocus && _controller.text != _show(widget.value)) {
      _controller.text = _show(widget.value);
      _error = null;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  static String _show(Object value) => '$value';

  bool get _isText => widget.spec.type == GbType.string;

  void _focusChanged() {
    if (_focus.hasFocus) {
      _group = Object();
      _start = widget.value;
      _written = _show(widget.value);
      return;
    }
    if (_isText) {
      // The click that moved the focus comes before the input method's
      // commit: commit here, or the syllable being composed is lost.
      _commitComposing();
      widget.onDone();
      return;
    }
    _commit();
    if (_error != null || _controller.text != _show(widget.value)) {
      setState(() {
        _controller.text = _show(widget.value);
        _error = null;
      });
    }
    widget.onDone();
  }

  /// [text] as a value of the property, or null with [_error] set.
  Object? _parse(String text) {
    final spec = widget.spec;
    final s = widget.strings;
    switch (spec.type) {
      case GbType.integer:
        final v = int.tryParse(text.trim());
        if (v == null || !spec.accepts(v)) {
          _error = s.integerRange
              .replaceAll('{0}', spec.name)
              .replaceAll('{1}', '${spec.min}')
              .replaceAll('{2}', '${spec.max}');
          return null;
        }
        return v;
      case GbType.double_:
        final v = double.tryParse(text.trim());
        if (v == null) {
          _error = s.numberNeeded.replaceAll('{0}', spec.name);
          return null;
        }
        return v;
      default:
        return text;
    }
  }

  /// A number being typed is only checked.
  void _changed(String text) {
    if (_isText) return;
    final value = _parse(text);
    setState(() {
      if (value != null) _error = null;
    });
  }

  /// Text: writes what the input method has committed, when it changes.
  /// Every value counts, also one where only the composing part ended.
  void _valueChanged() {
    final value = _tracker.track(_controller.value);
    if (!_isText || !widget.editable || !_focus.hasFocus) return;
    final committed = committedText(value);
    if (committed != _written) {
      _written = committed;
      widget.onChange(committed, _group);
    }
    widget.onPreview?.call(value.text);
  }

  bool get _composing => _tracker.composing;

  /// Takes what is being composed as committed, and writes it.
  void _commitComposing() {
    if (!_composing || !widget.editable) return;
    final raw = _controller.value;
    _tracker.commit();
    if (raw.composing.isValid && !raw.composing.isCollapsed) {
      _controller.value = raw.copyWith(composing: TextRange.empty);
    }
    final committed = committedText(_tracker.value);
    if (committed != _written) {
      _written = committed;
      widget.onChange(committed, _group);
    }
  }

  /// Applies a number typed in the field, if it is valid and new.
  void _commit() {
    if (_isText || !widget.editable) return;
    final value = _parse(_controller.text);
    if (value != null && value != widget.value) {
      widget.onChange(value, _group);
    }
  }

  void _submitted() {
    _commitComposing();
    _commit();
    widget.onDone();
    _group = Object();
  }

  void _escape() {
    if (_composing) {
      // Only what is being composed goes; the field keeps the focus.
      final v = _tracker.value;
      final c = v.composing;
      _controller.value = TextEditingValue(
        text: v.text.replaceRange(c.start, c.end, ''),
        selection: TextSelection.collapsed(offset: c.start),
      );
      return;
    }
    final back = _isText ? _start : widget.value;
    setState(() {
      _controller.text = _show(back);
      _error = null;
    });
    if (_isText) {
      _written = _show(_start);
      widget.onChange(_start, _group);
    }
    widget.onDone();
    widget.onLeave();
  }

  /// The picture list's choice that adds a picture; no picture's name can
  /// have a control character.
  static const _addPicture = '\u0000add';

  Future<void> _choosePicture(String? choice) async {
    if (choice == null) return;
    var name = choice;
    if (choice == _addPicture) {
      final added = await widget.onAddPicture?.call();
      if (added == null || !mounted) return;
      name = added;
    }
    if (name != widget.value) widget.onChange(name, Object());
    widget.onDone();
  }

  /// A picture property (D51): a box like the text fields' showing the
  /// picture, which opens a menu of the project's pictures, with no
  /// picture first and a way to add one last. A name the project does not
  /// have is shown as it is, marked.
  Widget _pictureList(BuildContext context) {
    final s = widget.strings;
    final theme = Theme.of(context);
    final value = '${widget.value}';
    final current = value.isEmpty
        ? ''
        : pictureNamed(widget.pictures, value) ?? value;
    final missing = current.isNotEmpty && !widget.pictures.contains(current);
    final broken = Icon(
      Icons.broken_image_outlined,
      size: 16,
      color: theme.colorScheme.error,
    );
    final style = theme.textTheme.bodyMedium;
    MenuItemButton item(String choice, String label, {Widget? icon}) =>
        MenuItemButton(
          leadingIcon: icon,
          onPressed: () => _choosePicture(choice),
          child: Text(label),
        );
    return MenuAnchor(
      menuChildren: [
        item('', s.noPicture),
        for (final p in widget.pictures) item(p, p),
        if (missing) item(current, current, icon: broken),
        if (widget.onAddPicture != null) item(_addPicture, s.addPicture),
      ],
      builder: (context, menu, _) => GestureDetector(
        key: propertyFieldKey(widget.spec.name),
        behavior: HitTestBehavior.opaque,
        onTap: widget.editable
            ? () => menu.isOpen ? menu.close() : menu.open()
            : null,
        child: InputDecorator(
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              if (missing) ...[broken, const SizedBox(width: 4)],
              Expanded(
                child: Text(
                  current.isEmpty ? s.noPicture : current,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: widget.editable ? null : theme.disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// An Anchor property (D59): a box like the text fields' showing the
  /// edges, which opens a cross whose arms turn each edge on and off.
  Widget _anchorBox(BuildContext context) {
    final theme = Theme.of(context);
    final value = '${widget.value}';
    return MenuAnchor(
      menuChildren: [
        AnchorEditor(
          value: value,
          tips: widget.strings.anchorTips,
          onChanged: (anchor) {
            widget.onChange(anchor, Object());
            widget.onDone();
          },
        ),
      ],
      builder: (context, menu, _) => GestureDetector(
        key: propertyFieldKey(widget.spec.name),
        behavior: HitTestBehavior.opaque,
        onTap: widget.editable
            ? () => menu.isOpen ? menu.close() : menu.open()
            : null,
        child: InputDecorator(
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value.isEmpty ? widget.strings.noAnchor : value,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: widget.editable ? null : theme.disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.spec.picture) return _pictureList(context);
    if (widget.spec.anchor) return _anchorBox(context);
    if (widget.spec.type == GbType.boolean) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Checkbox(
          key: propertyFieldKey(widget.spec.name),
          value: widget.value as bool,
          onChanged: widget.editable
              ? (v) {
                  widget.onChange(v!, Object());
                  widget.onDone();
                }
              : null,
        ),
      );
    }
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _escape},
      child: TextField(
        key: propertyFieldKey(widget.spec.name),
        controller: _controller,
        focusNode: _focus,
        readOnly: !widget.editable,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          errorText: _error,
          errorMaxLines: 4,
        ),
        onChanged: widget.editable ? _changed : null,
        // Enter applies and stays in the field.
        onEditingComplete: _submitted,
        // A click on the form gives the form the focus itself; letting
        // the field drop the focus too left it with nothing focused.
        onTapOutside: (_) {},
      ),
    );
  }
}

/// A control's (Name). It can change only while the form's code does not
/// use the name (D35): the code would refer to a control that is gone, or
/// a handler would stop running. A new name applies on Enter or when the
/// field is left, and only a usable name that no other control and no
/// code uses; otherwise the field says why.
class NameField extends StatefulWidget {
  const NameField({
    super.key,
    required this.form,
    required this.control,
    required this.code,
    required this.codeFile,
    required this.editable,
    required this.strings,
    required this.onRename,
    required this.onLeave,
  });

  final FormFile form;
  final ControlDecl control;
  final String code;
  final String codeFile;
  final bool editable;
  final IdeStrings strings;
  final void Function(String name, String newName) onRename;
  final VoidCallback onLeave;

  @override
  State<NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<NameField> {
  late final _controller = TextEditingController(text: widget.control.name);
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _apply();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  String get _name => widget.control.name;

  /// Why [name] cannot be the control's new name, or null.
  String? _problem(String name) {
    final s = widget.strings;
    if (!isUsableName(name)) return s.badName.replaceAll('{0}', name);
    final lower = name.toLowerCase();
    if (lower == _name.toLowerCase()) return null;
    if (widget.form.controls.any((c) => c.name.toLowerCase() == lower)) {
      return s.nameTaken.replaceAll('{0}', name);
    }
    final lines = linesUsingName(widget.code, name);
    if (lines.isNotEmpty) {
      return s.nameInCode
          .replaceAll('{0}', name)
          .replaceAll('{1}', widget.codeFile)
          .replaceAll('{2}', lines.join(', '));
    }
    return null;
  }

  void _apply() {
    final name = _controller.text;
    if (_problem(name) == null && name != _name) {
      widget.onRename(_name, name);
      // This field goes with the old name; the form takes the focus.
      widget.onLeave();
      return;
    }
    setState(() {
      _controller.text = _name;
      _error = null;
    });
  }

  void _escape() {
    setState(() {
      _controller.text = _name;
      _error = null;
    });
    widget.onLeave();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.editable) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          _name,
          key: propertyFieldKey('(Name)'),
          style: TextStyle(color: theme.disabledColor),
        ),
      );
    }
    final uses = linesUsingName(widget.code, _name);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _escape},
      child: TextField(
        key: propertyFieldKey('(Name)'),
        controller: _controller,
        focusNode: _focus,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          errorText: _error,
          errorMaxLines: 6,
          helperText: uses.isEmpty
              ? null
              : widget.strings.nameUsedInCode
                    .replaceAll('{0}', _name)
                    .replaceAll('{1}', widget.codeFile)
                    .replaceAll('{2}', uses.join(', ')),
          helperMaxLines: 6,
        ),
        onChanged: (name) => setState(() => _error = _problem(name)),
        onEditingComplete: _apply,
        onTapOutside: (_) {},
      ),
    );
  }
}

/// The Anchor field's cross (D59), as Visual Basic .NET's designer shows
/// it: a box for the control in a frame for the form, and an arm from the
/// box to each edge of the frame. A filled arm is an edge the control
/// keeps its distance to; clicking an arm turns it on or off.
class AnchorEditor extends StatelessWidget {
  const AnchorEditor({
    super.key,
    required this.value,
    required this.tips,
    required this.onChanged,
  });

  /// The Anchor, as `normalAnchor` keeps it.
  final String value;

  /// What each arm does, by edge.
  final Map<String, String> tips;
  final ValueChanged<String> onChanged;

  static const _size = 112.0;
  static const _box = 36.0;
  static const _reach = 14.0;

  void _toggle(String edge) {
    final words = value.split(' ').where((w) => w.isNotEmpty).toSet();
    if (!words.remove(edge)) words.add(edge);
    onChanged(normalAnchor(words.join(' '))!);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = value.split(' ').toSet();
    const middle = (_size - _box) / 2;
    const arm = (_size - _box) / 2;
    Widget armAt(String edge, Rect area, {required bool across}) {
      final chosen = on.contains(edge);
      return Positioned.fromRect(
        rect: area,
        child: Tooltip(
          message: tips[edge] ?? edge,
          child: InkWell(
            key: anchorArmKey(edge),
            onTap: () => _toggle(edge),
            child: Center(
              child: Container(
                width: across ? null : (chosen ? 6 : 2),
                height: across ? (chosen ? 6 : 2) : null,
                color: chosen ? scheme.primary : scheme.outline,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox.square(
        dimension: _size,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: const Rect.fromLTWH(middle, middle, _box, _box),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  border: Border.all(color: scheme.outline),
                ),
              ),
            ),
            armAt(
              'Left',
              const Rect.fromLTWH(
                0,
                middle + _box / 2 - _reach / 2,
                arm,
                _reach,
              ),
              across: true,
            ),
            armAt(
              'Right',
              const Rect.fromLTWH(
                middle + _box,
                middle + _box / 2 - _reach / 2,
                arm,
                _reach,
              ),
              across: true,
            ),
            armAt(
              'Top',
              const Rect.fromLTWH(
                middle + _box / 2 - _reach / 2,
                0,
                _reach,
                arm,
              ),
              across: false,
            ),
            armAt(
              'Bottom',
              const Rect.fromLTWH(
                middle + _box / 2 - _reach / 2,
                middle + _box,
                _reach,
                arm,
              ),
              across: false,
            ),
          ],
        ),
      ),
    );
  }
}
