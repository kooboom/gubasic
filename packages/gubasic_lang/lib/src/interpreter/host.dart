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
}
