import 'dart:typed_data';

/// A TrueType font (glyphs as quadratic outlines, in a `glyf` table), as
/// a PDF file needs it (docs/DESIGN.md D117): which glyph shows a
/// character, how wide it is, and a copy that holds only some glyphs.
class TrueTypeFont {
  TrueTypeFont._(this._data, this._tables);

  /// Reads [bytes]; throws a [FormatException] when they are not a
  /// TrueType font with the tables this needs.
  factory TrueTypeFont.parse(List<int> bytes) {
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    if (data.lengthInBytes < 12) throw const FormatException('not a font');
    final version = data.getUint32(0);
    if (version != 0x00010000 && version != 0x74727565) {
      throw const FormatException('not a TrueType font');
    }
    final count = data.getUint16(4);
    final tables = <String, (int, int)>{};
    for (var i = 0; i < count; i++) {
      final at = 12 + 16 * i;
      final tag = String.fromCharCodes(Uint8List.sublistView(data, at, at + 4));
      tables[tag] = (data.getUint32(at + 8), data.getUint32(at + 12));
    }
    for (final t in ['head', 'hhea', 'maxp', 'hmtx', 'loca', 'glyf']) {
      if (!tables.containsKey(t)) throw FormatException('no $t table');
    }
    return TrueTypeFont._(data, tables).._read();
  }

  final ByteData _data;
  final Map<String, (int, int)> _tables;

  late final int unitsPerEm;
  late final int ascent;
  late final int descent;

  /// xMin, yMin, xMax, yMax, in font units.
  late final List<int> bbox;
  late final int glyphCount;
  late final bool _longLoca;
  late final int _metrics;
  final _cmap = <int, int>{};

  int _at(String table) => _tables[table]!.$1;

  void _read() {
    final head = _at('head');
    unitsPerEm = _data.getUint16(head + 18);
    bbox = [
      for (var i = 0; i < 4; i++) _data.getInt16(head + 36 + 2 * i),
    ];
    _longLoca = _data.getInt16(head + 50) == 1;
    final hhea = _at('hhea');
    ascent = _data.getInt16(hhea + 4);
    descent = _data.getInt16(hhea + 6);
    _metrics = _data.getUint16(hhea + 34);
    glyphCount = _data.getUint16(_at('maxp') + 4);
    // A copy made by [subset] has none: a PDF file finds glyphs by number.
    if (_tables.containsKey('cmap')) _readCmap();
  }

  /// The Unicode subtable: format 12 (all planes) if there is one, else
  /// format 4.
  void _readCmap() {
    final cmap = _at('cmap');
    final n = _data.getUint16(cmap + 2);
    int? four, twelve;
    for (var i = 0; i < n; i++) {
      final platform = _data.getUint16(cmap + 4 + 8 * i);
      final encoding = _data.getUint16(cmap + 6 + 8 * i);
      final at = cmap + _data.getUint32(cmap + 8 + 8 * i);
      final format = _data.getUint16(at);
      final unicode = platform == 0 || (platform == 3 && encoding <= 10);
      if (!unicode) continue;
      if (format == 12) twelve ??= at;
      if (format == 4) four ??= at;
    }
    if (twelve != null) {
      final groups = _data.getUint32(twelve + 12);
      for (var g = 0; g < groups; g++) {
        final at = twelve + 16 + 12 * g;
        final start = _data.getUint32(at);
        final end = _data.getUint32(at + 4);
        final glyph = _data.getUint32(at + 8);
        for (var c = start; c <= end; c++) {
          _cmap[c] = glyph + c - start;
        }
      }
    } else if (four != null) {
      final segments = _data.getUint16(four + 6) ~/ 2;
      final ends = four + 14;
      final starts = ends + 2 * segments + 2;
      final deltas = starts + 2 * segments;
      final offsets = deltas + 2 * segments;
      for (var s = 0; s < segments; s++) {
        final start = _data.getUint16(starts + 2 * s);
        final end = _data.getUint16(ends + 2 * s);
        final delta = _data.getInt16(deltas + 2 * s);
        final offset = _data.getUint16(offsets + 2 * s);
        for (var c = start; c <= end && c != 0xFFFF; c++) {
          int glyph;
          if (offset == 0) {
            glyph = (c + delta) & 0xFFFF;
          } else {
            final at = offsets + 2 * s + offset + 2 * (c - start);
            glyph = _data.getUint16(at);
            if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
          }
          if (glyph != 0) _cmap[c] = glyph;
        }
      }
    } else {
      throw const FormatException('no Unicode cmap');
    }
  }

  /// The glyph that shows [codePoint]; 0 (the font's "missing" glyph) when
  /// it has none.
  int glyphOf(int codePoint) => _cmap[codePoint] ?? 0;

  /// How far [glyph] moves the pen, in font units.
  int advance(int glyph) {
    final hmtx = _at('hmtx');
    final i = glyph < _metrics ? glyph : _metrics - 1;
    return _data.getUint16(hmtx + 4 * i);
  }

  int _leftBearing(int glyph) {
    final hmtx = _at('hmtx');
    return glyph < _metrics
        ? _data.getInt16(hmtx + 4 * glyph + 2)
        : _data.getInt16(hmtx + 4 * _metrics + 2 * (glyph - _metrics));
  }

  /// The bytes of [glyph]'s outline in the `glyf` table.
  Uint8List _glyph(int glyph) {
    final loca = _at('loca');
    int offset(int i) => _longLoca
        ? _data.getUint32(loca + 4 * i)
        : _data.getUint16(loca + 2 * i) * 2;
    final glyf = _at('glyf');
    return Uint8List.sublistView(
        _data, glyf + offset(glyph), glyf + offset(glyph + 1));
  }

  /// The glyphs a composite [glyph] is made of, with where each glyph
  /// number is in its bytes.
  List<(int, int)> _components(Uint8List outline) {
    if (outline.length < 10) return const [];
    final d = ByteData.sublistView(outline);
    if (d.getInt16(0) >= 0) return const [];
    final out = <(int, int)>[];
    var at = 10;
    while (true) {
      final flags = d.getUint16(at);
      out.add((d.getUint16(at + 2), at + 2));
      at += 4 + ((flags & 0x0001) != 0 ? 4 : 2);
      if ((flags & 0x0008) != 0) {
        at += 2;
      } else if ((flags & 0x0040) != 0) {
        at += 4;
      } else if ((flags & 0x0080) != 0) {
        at += 8;
      }
      if ((flags & 0x0020) == 0) break;
    }
    return out;
  }

  /// A font of only [glyphs] (glyph 0 always first), numbered from 0 in
  /// the order given, with the glyphs composite ones are made of added at
  /// the end; and the old number of each new one. Its tables: those a PDF
  /// viewer needs to draw it (head, hhea, maxp, hmtx, loca, glyf, and the
  /// hinting ones when the font has them).
  (Uint8List, List<int>) subset(List<int> glyphs) {
    final order = <int>[0];
    final number = <int, int>{0: 0};
    void add(int g) {
      if (number.containsKey(g) || g >= glyphCount) return;
      number[g] = order.length;
      order.add(g);
    }

    glyphs.forEach(add);
    for (var i = 0; i < order.length; i++) {
      for (final (g, _) in _components(_glyph(order[i]))) {
        add(g);
      }
    }
    final glyf = BytesBuilder();
    final offsets = <int>[0];
    for (final g in order) {
      final outline = Uint8List.fromList(_glyph(g));
      final d = ByteData.sublistView(outline);
      for (final (old, at) in _components(outline)) {
        d.setUint16(at, number[old] ?? 0);
      }
      glyf.add(outline);
      if (outline.length.isOdd) glyf.addByte(0);
      offsets.add(glyf.length);
    }
    final loca = ByteData(4 * offsets.length);
    for (var i = 0; i < offsets.length; i++) {
      loca.setUint32(4 * i, offsets[i]);
    }
    final hmtx = ByteData(4 * order.length);
    for (var i = 0; i < order.length; i++) {
      hmtx
        ..setUint16(4 * i, advance(order[i]))
        ..setInt16(4 * i + 2, _leftBearing(order[i]));
    }
    Uint8List copy(String t) {
      final (at, length) = _tables[t]!;
      return Uint8List.fromList(Uint8List.sublistView(_data, at, at + length));
    }

    final head = copy('head');
    ByteData.sublistView(head)
      ..setUint32(8, 0) // checksumAdjustment, set below
      ..setInt16(50, 1); // long loca
    final hhea = copy('hhea');
    ByteData.sublistView(hhea).setUint16(34, order.length);
    final maxp = copy('maxp');
    ByteData.sublistView(maxp).setUint16(4, order.length);
    final unsorted = <String, Uint8List>{
      for (final t in ['cvt ', 'fpgm', 'prep'])
        if (_tables.containsKey(t)) t: copy(t),
      'glyf': glyf.toBytes(),
      'head': head,
      'hhea': hhea,
      'hmtx': Uint8List.sublistView(hmtx),
      'loca': Uint8List.sublistView(loca),
      'maxp': maxp,
    };
    final tables = {
      for (final k in unsorted.keys.toList()..sort()) k: unsorted[k]!,
    };
    final font = _write(tables);
    final adjust = (0xB1B0AFBA - _checksum(font)) & 0xFFFFFFFF;
    final headAt = ByteData.sublistView(font)
        .getUint32(12 + 16 * tables.keys.toList().indexOf('head') + 8);
    ByteData.sublistView(font).setUint32(headAt + 8, adjust);
    return (font, order);
  }

  static int _checksum(Uint8List bytes) {
    final padded = Uint8List((bytes.length + 3) & ~3)..setAll(0, bytes);
    final d = ByteData.sublistView(padded);
    var sum = 0;
    for (var i = 0; i < padded.length; i += 4) {
      sum = (sum + d.getUint32(i)) & 0xFFFFFFFF;
    }
    return sum;
  }

  /// [tables], in the order given (the tags' sorted order), as a font
  /// file.
  static Uint8List _write(Map<String, Uint8List> tables) {
    final n = tables.length;
    var power = 1, log = 0;
    while (power * 2 <= n) {
      power *= 2;
      log++;
    }
    final header = ByteData(12 + 16 * n)
      ..setUint32(0, 0x00010000)
      ..setUint16(4, n)
      ..setUint16(6, power * 16)
      ..setUint16(8, log)
      ..setUint16(10, n * 16 - power * 16);
    final out = BytesBuilder()..add(Uint8List(12 + 16 * n));
    var i = 0;
    for (final MapEntry(:key, :value) in tables.entries) {
      final at = 12 + 16 * i++;
      for (var c = 0; c < 4; c++) {
        header.setUint8(at + c, key.codeUnitAt(c));
      }
      header
        ..setUint32(at + 4, _checksum(value))
        ..setUint32(at + 8, out.length)
        ..setUint32(at + 12, value.length);
      out.add(value);
      while (out.length % 4 != 0) {
        out.addByte(0);
      }
    }
    final bytes = out.toBytes();
    bytes.setAll(0, Uint8List.sublistView(header));
    return bytes;
  }
}
