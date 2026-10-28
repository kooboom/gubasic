import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// What opens [file] in the project explorer's forms view (D94): a form's
/// Design or Code button, or the line of any other file.
Finder explorerItem(String file) {
  for (final (end, key) in [('.form.yaml', 'design'), ('.gbas', 'code')]) {
    if (file.endsWith(end)) {
      final form = file.substring(0, file.length - end.length);
      return find.byKey(ValueKey('explorer.$key.$form'));
    }
  }
  return find.text(file);
}
