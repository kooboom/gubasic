import 'package:yaml/yaml.dart';

import '../analyzer/types.dart';
import '../diagnostics/diagnostic.dart';
import 'component.dart';
import 'yaml_reader.dart';

/// The newest form file layout this GuBASIC reads (docs/LANGUAGE.md §11.2).
const formFileVersion = 1;

/// A control placed on a form.
class ControlDecl {
  ControlDecl({
    required this.name,
    required this.component,
    required this.properties,
    required this.line,
  });

  final String name;
  final ComponentSpec component;

  /// The values written in the file, by the property's own spelling.
  final Map<String, Object> properties;

  /// The line of the control's entry in the form file.
  final int line;

  /// The value of [property] (any case): as written, or the default.
  Object valueOf(String property) {
    final spec = component.properties[property.toLowerCase()]!;
    return properties[spec.name] ?? spec.defaultValue;
  }
}

/// A form: its own properties and its controls (`Form1.form.yaml`).
class FormFile {
  FormFile({
    required this.name,
    required this.properties,
    required this.controls,
  });

  /// The form's name, taken from the file name (`Form1`).
  final String name;

  /// The form's own properties written in the file.
  final Map<String, Object> properties;
  final List<ControlDecl> controls;

  ComponentSpec get component => formComponent;

  /// The control named [name] (any case), or null.
  ControlDecl? control(String name) {
    final lower = name.toLowerCase();
    for (final c in controls) {
      if (c.name.toLowerCase() == lower) return c;
    }
    return null;
  }

  /// The value of the form's own [property]: as written, or the default.
  Object valueOf(String property) {
    final spec = component.properties[property.toLowerCase()]!;
    return properties[spec.name] ?? spec.defaultValue;
  }
}

class FormFileResult {
  FormFileResult(this.form, this.diagnostics);

  /// What could be read. Controls and properties with errors are left out.
  final FormFile form;
  final List<Diagnostic> diagnostics;

  bool get hasErrors => diagnostics.any((d) => d.isError);
}

/// Reads a form file. [name] is the form's name, from the file name.
/// Never throws: problems are F diagnostics, and everything else is read.
FormFileResult readFormFile(String text, {required String name}) {
  final r = YamlReader();
  final properties = <String, Object>{};
  final controls = <ControlDecl>[];
  final result = FormFileResult(
      FormFile(name: name, properties: properties, controls: controls),
      r.diagnostics);

  final doc = r.load(text);
  if (doc == null) return result;
  final top = r.entries(doc, {'formatversion', 'properties', 'controls'});
  if (!r.checkVersion(doc, top, formFileVersion)) return result;

  final formProps = top['properties'];
  if (formProps != null) {
    _properties(r, formProps, formComponent, properties);
  }

  final list = top['controls'] == null
      ? null
      : r.list(top['controls']!, 'controls', '- name: btnOk');
  final seen = <String, int>{};
  for (final item in list?.nodes ?? const <YamlNode>[]) {
    final entry = r.map(item, 'controls');
    if (entry == null) continue;
    final keys = r.entries(entry, {'name', 'type', 'properties'});
    final line = entry.span.start.line + 1;

    final nameNode = keys['name'];
    String? controlName;
    if (nameNode == null) {
      r.report(entry.span, DiagnosticCode.invalidControlName, ['']);
    } else {
      controlName = r.name(nameNode);
    }
    if (controlName != null) {
      final first = seen[controlName.toLowerCase()];
      if (first != null) {
        r.report(nameNode!.span, DiagnosticCode.duplicateControlName,
            [controlName, '$first']);
        controlName = null;
      } else {
        seen[controlName.toLowerCase()] = line;
      }
    }

    final typeNode = keys['type'];
    ComponentSpec? component;
    if (typeNode == null) {
      r.report(
          entry.span, DiagnosticCode.wrongValueForm, ['type', 'type: Button']);
    } else {
      final typeName = r.text(typeNode, 'type', 'type: Button');
      if (typeName != null) {
        component = builtinComponents[typeName.toLowerCase()];
        if (component == null || component == formComponent) {
          component = null;
          r.report(typeNode.span, DiagnosticCode.unknownControlType,
              [typeName, _controlTypeNames()]);
        }
      }
    }

    final values = <String, Object>{};
    if (component != null && keys['properties'] != null) {
      _properties(r, keys['properties']!, component, values);
    }
    if (controlName != null && component != null) {
      controls.add(ControlDecl(
          name: controlName,
          component: component,
          properties: values,
          line: line));
    }
  }
  return result;
}

String _controlTypeNames() => [
      for (final c in builtinComponents.values)
        if (c != formComponent) c.name
    ].join(', ');

/// Reads a `properties:` map for [component] into [into].
void _properties(YamlReader r, YamlNode node, ComponentSpec component,
    Map<String, Object> into) {
  final map = r.map(node, 'properties');
  if (map == null) return;
  for (final MapEntry(:key, :value) in map.nodes.entries) {
    final keyNode = key as YamlNode;
    final name = '${keyNode.value}';
    final spec = component.properties[name.toLowerCase()];
    if (spec == null) {
      r.report(keyNode.span, DiagnosticCode.unknownProperty, [
        name,
        component.name,
        component.properties.values.map((p) => p.name).join(', ')
      ]);
      continue;
    }
    final v = _value(value, spec.type);
    if (v == null) {
      r.report(value.span, DiagnosticCode.wrongPropertyType,
          [spec.name, spec.type.displayName]);
      continue;
    }
    into[spec.name] = v;
  }
}

/// [node]'s value as [type], or null if it is not one.
///
/// A String property takes any single value as it is written, so that
/// `Caption: 2026` is the text "2026"; an empty value is "".
Object? _value(YamlNode node, GbType type) {
  if (node is! YamlScalar) return null;
  final value = node.value;
  return switch (type) {
    GbType.integer => value is int ? value : null,
    GbType.double_ => value is num ? value.toDouble() : null,
    GbType.boolean => value is bool ? value : null,
    _ => value == null
        ? ''
        : value is String
            ? value
            : node.span.text.trim(),
  };
}
