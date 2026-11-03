/// The colours of controls (docs/DESIGN.md D137): Visual Basic .NET's
/// `Color` ([Microsoft](https://learn.microsoft.com/en-us/dotnet/api/system.drawing.color)),
/// a named colour (`Color.Red`) or one made with `Color.FromArgb(r, g, b)`;
/// `Color.Empty` is no colour of its own: the control follows its Frame,
/// its form or the theme.
library;

/// The named colours, as Visual Basic .NET's `Color` has them, with their
/// values (0xAARRGGBB).
const namedColors = <String, int>{
  'Black': 0xFF000000,
  'White': 0xFFFFFFFF,
  'Red': 0xFFFF0000,
  'Green': 0xFF008000,
  'Blue': 0xFF0000FF,
  'Yellow': 0xFFFFFF00,
  'Orange': 0xFFFFA500,
  'Purple': 0xFF800080,
  'Pink': 0xFFFFC0CB,
  'Brown': 0xFFA52A2A,
  'Gray': 0xFF808080,
  'DarkGray': 0xFFA9A9A9,
  'LightGray': 0xFFD3D3D3,
  'Silver': 0xFFC0C0C0,
  'WhiteSmoke': 0xFFF5F5F5,
  'Navy': 0xFF000080,
  'DarkBlue': 0xFF00008B,
  'RoyalBlue': 0xFF4169E1,
  'SkyBlue': 0xFF87CEEB,
  'LightBlue': 0xFFADD8E6,
  'Teal': 0xFF008080,
  'Cyan': 0xFF00FFFF,
  'Aqua': 0xFF00FFFF,
  'Turquoise': 0xFF40E0D0,
  'Lime': 0xFF00FF00,
  'LightGreen': 0xFF90EE90,
  'DarkGreen': 0xFF006400,
  'Olive': 0xFF808000,
  'Maroon': 0xFF800000,
  'DarkRed': 0xFF8B0000,
  'Crimson': 0xFFDC143C,
  'Tomato': 0xFFFF6347,
  'Coral': 0xFFFF7F50,
  'Salmon': 0xFFFA8072,
  'Gold': 0xFFFFD700,
  'LightYellow': 0xFFFFFFE0,
  'Khaki': 0xFFF0E68C,
  'Beige': 0xFFF5F5DC,
  'Ivory': 0xFFFFFFF0,
  'Tan': 0xFFD2B48C,
  'Chocolate': 0xFFD2691E,
  'Magenta': 0xFFFF00FF,
  'Fuchsia': 0xFFFF00FF,
  'Violet': 0xFFEE82EE,
  'Lavender': 0xFFE6E6FA,
  'Indigo': 0xFF4B0082,
  'Transparent': 0x00FFFFFF,
};

/// Visual Basic 6's colour constants and the `Color` each is (A079).
const vb6Colors = <String, String>{
  'vbblack': 'Black',
  'vbwhite': 'White',
  'vbred': 'Red',
  'vbgreen': 'Lime',
  'vbblue': 'Blue',
  'vbyellow': 'Yellow',
  'vbmagenta': 'Magenta',
  'vbcyan': 'Cyan',
};

/// [argb] as a form file and a host keep a colour: its name when it has
/// one, else `#RRGGBB`, or `#AARRGGBB` when it is not opaque.
String colorText(int argb) {
  for (final MapEntry(:key, :value) in namedColors.entries) {
    if (value == argb) return key;
  }
  String hex(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  final a = (argb >> 24) & 0xFF;
  final rgb = '${hex((argb >> 16) & 0xFF)}${hex((argb >> 8) & 0xFF)}'
      '${hex(argb & 0xFF)}';
  return a == 0xFF ? '#$rgb' : '#${hex(a)}$rgb';
}

/// The colour [text] names: a name of [namedColors] in any case,
/// `#RRGGBB` or `#AARRGGBB`; null for anything else.
int? parseColor(String text) {
  final t = text.trim();
  for (final MapEntry(:key, :value) in namedColors.entries) {
    if (key.toLowerCase() == t.toLowerCase()) return value;
  }
  final m = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(t);
  if (m == null) return null;
  final v = int.parse(m[1]!, radix: 16);
  return m[1]!.length == 6 ? 0xFF000000 | v : v;
}
