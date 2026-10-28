import 'dart:ui' show AppExitType;

import 'package:flutter/services.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

const _window = MethodChannel('gubasic/window');

/// Fits an exported app's window to its project before the window is
/// first shown (D86): the project's name as its title, the startup form's
/// size inside its frame (no larger than the screen), with its menu bar
/// above it where the window draws one (D106), centred. Does
/// nothing where the app's runner has no such channel: on the web, where
/// the page is the frame. The Windows and macOS runners have it (D86,
/// D87).
Future<void> fitAppWindow(Project project) {
  final form = project.startup?.form;
  final bar =
      !gbUsesSystemMenus &&
          (form?.controls.any((c) => c.component.menu) ?? false)
      ? gbMenuBarHeight.toInt()
      : 0;
  return fitWindow(
    project.name,
    width: form?.valueOf('Width') as int?,
    height: switch (form?.valueOf('Height')) {
      final int height => height + bar,
      _ => null,
    },
  );
}

/// Gives the app's window [title] and, when given, makes the area inside
/// its frame [width] by [height]: also when another form comes to the
/// front (D88).
Future<void> fitWindow(String title, {int? width, int? height}) async {
  try {
    await _window.invokeMethod<void>('fit', {
      'title': title,
      if (width != null && height != null) ...{
        'width': width.toDouble(),
        'height': height.toDouble(),
      },
    });
  } on MissingPluginException {
    // No such window to fit.
  }
}

/// Closes the app when its program has ended (D81): its window is closed
/// as the user would close it, by the runner after this call returns.
/// Where the runner has no such channel, the app is told to exit.
Future<void> closeAppWindow() async {
  try {
    await _window.invokeMethod<void>('close');
  } on MissingPluginException {
    await ServicesBinding.instance.exitApplication(AppExitType.required);
  }
}
