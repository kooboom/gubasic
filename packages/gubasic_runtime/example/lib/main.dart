import 'package:flutter/material.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A form drawn by hand with gubasic_runtime, without the interpreter: CI
/// builds it for the web, Windows and macOS. The event handling below
/// stands in for a GuBASIC program:
///
///     Sub btnHello_Click()
///         MsgBox("Hello, " & txtName.Text & "!")
///     End Sub
///     Sub txtName_Changed()
///         lblEcho.Caption = Len(txtName.Text) & " characters"
///     End Sub
void main() => runApp(const MaterialApp(home: ExampleForm()));

class ExampleForm extends StatefulWidget {
  const ExampleForm({super.key});

  @override
  State<ExampleForm> createState() => _ExampleFormState();
}

class _ExampleFormState extends State<ExampleForm> {
  final _dialogs = GbDialogs();
  late final GbFormModel _model = GbFormModel(
    form: {'Caption': 'Hello', 'Width': 320, 'Height': 160},
    controls: [
      GbControlState('txtName', GbControlKind.textBox, {
        'Text': '', 'Left': 16, 'Top': 16, 'Width': 288, 'Height': 40, //
      }),
      GbControlState('lblEcho', GbControlKind.label, {
        'Caption': '0 characters', 'Left': 16, 'Top': 64, //
        'Width': 288, 'Height': 24,
      }),
      GbControlState('btnHello', GbControlKind.button, {
        'Caption': 'Say hello', 'Left': 16, 'Top': 104, //
        'Width': 120, 'Height': 36,
      }),
    ],
    onEvent: _onEvent,
  );

  void _onEvent(String? control, String event) {
    final name = _model.control('txtName')!.text('Text');
    switch ('$control.$event') {
      case 'txtName.Changed':
        _model
            .control('lblEcho')!
            .set('Caption', '${name.runes.length} characters');
      case 'btnHello.Click':
        _dialogs.msgBox(context, 'Hello, $name!', '');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_model.form.text('Caption'))),
    body: Align(
      alignment: Alignment.topLeft,
      child: GbFormView(model: _model),
    ),
  );
}
