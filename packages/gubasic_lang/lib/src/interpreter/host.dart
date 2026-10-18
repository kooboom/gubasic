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

/// What a program with a form needs besides [Host]: the form and its
/// controls (docs/LANGUAGE.md §8, §11). The IDE's run window implements it
/// with gubasic_runtime; tests use a recording fake (testing.dart).
///
/// Controls are named as in the form file; null is the form itself.
/// Properties are named as in their component.yaml, and their values are
/// `int`, `double`, `bool` or `String`.
abstract interface class FormHost implements Host {
  /// The current value of a property: as the program last set it, or as
  /// the user changed it (the text typed in a TextBox).
  Object getProperty(String? control, String property);

  /// The program sets a property. The interpreter runs the property's
  /// change event itself (TextBox.Changed); the host runs it only for
  /// changes the user makes.
  void setProperty(String? control, String property, Object value);

  /// Form_Load has finished: show the form.
  void showForm();

  /// The program has ended: close the form, and close any open dialog as
  /// if it was cancelled.
  void endProgram();
}
