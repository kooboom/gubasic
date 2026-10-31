import 'package:flutter/services.dart';
import 'package:gubasic_player/gubasic_player.dart'
    show pdfFontFile, pdfFontLicense;

/// The font PDF files are written in, and its licence (docs/DESIGN.md
/// D117): the IDE carries them, for the run window and for the apps it
/// exports whose project uses PdfDocument.
Future<Map<String, Uint8List>> loadPdfFont() async => {
  pdfFontFile: await _load('fonts/nanumgothic/NanumGothic-Regular.ttf'),
  pdfFontLicense: await _load('fonts/nanumgothic/OFL.txt'),
};

Future<Uint8List> _load(String asset) async =>
    (await rootBundle.load(asset)).buffer.asUint8List();
