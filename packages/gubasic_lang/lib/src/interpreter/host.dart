/// What a running program needs from the screen. The playground shows
/// these in its Run tab; tests use a fake that records them.
abstract interface class Host {
  /// `Debug.Print`: one line of output.
  void debugPrint(String line);

  /// `MsgBox`: waits until the user closes the message.
  Future<void> msgBox(String prompt, String title);

  /// `InputBox`: the text typed, or "" if the user cancels.
  Future<String> inputBox(String prompt, String title, String defaultValue);

  /// Lets the screen update and the Stop button work. Called by `DoEvents`
  /// and regularly while the program runs; it never changes what the
  /// program computes.
  Future<void> yieldNow();

  /// The saved settings of the program (`GetSetting`), as the text the
  /// interpreter last gave [saveSettings], or null if there are none. The
  /// IDE keeps them for each project, by its name (docs/DESIGN.md D48).
  Future<String?> loadSettings();

  /// `SaveSetting`: keeps [text], all of the program's settings. Throws if
  /// they cannot be kept; the program then stops with R012.
  Future<void> saveSettings(String text);
}

/// A form the program shows (docs/DESIGN.md D88).
class ShownForm {
  const ShownForm(this.name, {this.dialog = false});

  final String name;

  /// Shown by ShowDialog: over the form behind it, which is dimmed.
  final bool dialog;

  @override
  bool operator ==(Object other) =>
      other is ShownForm && other.name == name && other.dialog == dialog;

  @override
  int get hashCode => Object.hash(name, dialog);

  @override
  String toString() => dialog ? '$name (dialog)' : name;
}

/// What a program with forms needs besides [Host]: its forms and their
/// controls (docs/LANGUAGE.md §8, §11). The IDE's run window implements it
/// with gubasic_runtime; tests use a recording fake (testing.dart).
///
/// Forms are named as their files; controls as in the form file, null
/// being the form itself. Properties are named as in their
/// component.yaml, and their values are `int`, `double`, `bool` or
/// `String`. Every form of the project has its properties from the start,
/// shown or not.
abstract interface class FormHost implements Host {
  /// The current value of a property: as the program last set it, or as
  /// the user changed it (the text typed in a TextBox).
  Object getProperty(String form, String? control, String property);

  /// The program sets a property. The interpreter runs the property's
  /// change event itself (TextBox.Changed); the host runs it only for
  /// changes the user makes.
  void setProperty(String form, String? control, String property, Object value);

  /// The forms shown changed (D88): [forms] from the back to the front.
  /// Only the front one takes what the user does; a dialog is shown over
  /// the forms behind it. Called first when the startup form's Form_Load
  /// has finished.
  void showForms(List<ShownForm> forms);

  /// [form] starts again, shown after it was closed (D88): its properties
  /// are as in its form file again, and only its controls are on it.
  void resetForm(String form);

  /// The program puts a control made with New on [form] (D98): [control],
  /// a [component] (`Button`), with [properties] (every stored one). It is
  /// drawn on top of the others of its layer.
  void addControl(String form, String control, String component,
      Map<String, Object> properties);

  /// The program takes [control] off [form] (D98).
  void removeControl(String form, String control);

  /// The program has ended: close the forms, and close any open dialog as
  /// if it was cancelled.
  void endProgram();
}
