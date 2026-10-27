import 'package:gubasic_player/gubasic_player.dart';

/// Two projects whose second form comes up by itself, for exported apps
/// checked without a mouse (D88, D89): Swap shows Form2 (360 x 220) as
/// soon as Form1 (320 x 140) is shown, so the window takes Form2's size;
/// Dialog shows Form2 (220 x 100) over Form1 (320 x 200) as a dialog.
/// Form_Resize runs once when a form is first shown (D58).
List<ProjectBundle> formDemos() => [
  _demo('Swap', 'cimultiformswap1', 'Show', (320, 140), (360, 220)),
  _demo('Dialog', 'cimultiformdlg01', 'ShowDialog', (320, 200), (220, 100)),
];

ProjectBundle _demo(
  String name,
  String id,
  String show,
  (int, int) first,
  (int, int) second,
) => ProjectBundle(
  id: id,
  name: name,
  files: {
    '$name.gbproj':
        'formatVersion: 1\nname: $name\nstartup: Form1\n'
        'forms:\n  - Form1\n  - Form2\n',
    'Form1.form.yaml':
        'formatVersion: 1\nproperties:\n  Caption: First\n'
        '  Width: ${first.$1}\n  Height: ${first.$2}\ncontrols:\n'
        '  - name: lblFirst\n    type: Label\n    properties:\n'
        '      Caption: This is Form1.\n      Left: 16\n      Top: 16\n'
        '      Width: 200\n',
    'Form1.gbas': 'Sub Form_Resize()\n    Form2.$show\nEnd Sub\n',
    'Form2.form.yaml':
        'formatVersion: 1\nproperties:\n  Caption: Second\n'
        '  Width: ${second.$1}\n  Height: ${second.$2}\ncontrols:\n'
        '  - name: lblSecond\n    type: Label\n    properties:\n'
        '      Caption: This is Form2.\n      Left: 16\n      Top: 16\n'
        '      Width: 180\n',
    'Form2.gbas': '',
  },
);
