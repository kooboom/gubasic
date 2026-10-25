import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/designer/properties_panel.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_ide/src/project/pictures_dialog.dart';
import 'package:gubasic_ide/src/project/project_controller.dart';
import 'package:gubasic_ide/src/project/project_pictures.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import 'support/memory_folders.dart';
import 'support/pictures.dart';

void main() {
  const s = IdeStrings.en;
  const formFile = 'Form1.form.yaml';
  late MemoryFolders fs;

  /// What the picture dialog gives, in turn; null is Cancel.
  late List<PickedPicture?> picks;
  late List<String?> saves;
  late List<String?> opens;

  setUp(() {
    fs = MemoryFolders()..folders.add('/home');
    picks = [];
    saves = [];
    opens = [];
  });

  Future<void> start(WidgetTester tester, {IdeStrings strings = s}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: exampleProjects,
        examplePictures: decodeExamplePictures(examplePictures),
        strings: strings,
        folders: fs,
        pickers: ProjectPickers(
          openProjectFile: (_) async => opens.removeAt(0),
          saveLocation: (_, _) async => saves.removeAt(0),
          openPicture: (_) async => picks.removeAt(0),
        ),
      ),
    );
  }

  OpenProject current(WidgetTester tester) =>
      tester.widget<IdeShell>(find.byType(IdeShell)).controller.current;
  FormFile form(WidgetTester tester) =>
      readFormFile(current(tester).files[formFile]!, name: 'Form1').form;

  Future<void> menu(WidgetTester tester, String item) async {
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  Future<void> addInDialog(WidgetTester tester, PickedPicture pick) async {
    picks.add(pick);
    await tester.tap(find.byKey(addPictureKey));
    await tester.pumpAndSettle();
  }

  /// Waits, with the engine's real time, until [until] is found: reading
  /// a picture's frames, or making it smaller, is not done in the test's
  /// fake time.
  Future<void> waitFor(WidgetTester tester, Finder until) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 500 && until.evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(until, findsWidgets);
  }

  /// A real PNG of [width] x [height] grey pixels.
  Future<Uint8List> greyPng(WidgetTester tester, int width, int height) async =>
      (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xFF808080), BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(width, height);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      }))!;

  Future<void> closeDialog(
    WidgetTester tester, {
    IdeStrings strings = s,
  }) async {
    await tester.tap(find.text(strings.runtime.ok).last);
    await tester.pumpAndSettle();
  }

  /// Puts an Image in the middle of the form with a double-click on its
  /// tool; it is selected then.
  Future<void> placeImage(WidgetTester tester) async {
    await tester.tap(find.text(formFile));
    await tester.pumpAndSettle();
    final tool = find.byKey(const ValueKey('toolbox.Image'));
    await tester.tap(tool);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(tool);
    await tester.pumpAndSettle();
  }

  Future<void> choosePicture(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(propertyFieldKey('Picture')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  /// The pictures the designer's form draws.
  Iterable<Image> drawn(WidgetTester tester) => tester.widgetList<Image>(
    find.descendant(
      of: find.byKey(designerFormKey),
      matching: find.byType(Image),
    ),
  );

  testWidgets('File → Pictures adds a picture; an Image placed from the '
      'toolbox chooses it and the designer draws it', (tester) async {
    await start(tester);
    await menu(tester, s.picturesMenu);
    expect(find.text(s.noPictures), findsOneWidget);
    // A Mac gives the syllables of Hangul file names split (NFD).
    await addInDialog(tester, (
      name: '\u1109\u1161\u1100\u116A.png',
      bytes: onePixelPng,
    ));
    expect(find.byKey(pictureRowKey('사과.png')), findsOneWidget);
    expect(current(tester).pictures.keys, ['사과.png']);
    expect(current(tester).isDirty, isTrue);
    await closeDialog(tester);

    await placeImage(tester);
    expect(form(tester).control('Image1'), isNotNull);
    expect(drawn(tester), isEmpty, reason: 'no picture chosen yet');
    await choosePicture(tester, '사과.png');
    expect(form(tester).control('Image1')!.valueOf('Picture'), '사과.png');
    expect(drawn(tester), hasLength(1));
    expect((drawn(tester).single.image as MemoryImage).bytes, onePixelPng);

    await choosePicture(tester, s.noPicture);
    expect(form(tester).control('Image1')!.valueOf('Picture'), '');
  });

  testWidgets('Add Picture… in the Picture list adds one and chooses it', (
    tester,
  ) async {
    await start(tester);
    await placeImage(tester);
    picks.add((name: 'pear.png', bytes: onePixelPng));
    await choosePicture(tester, s.addPicture);
    expect(current(tester).pictures.keys, ['pear.png']);
    expect(form(tester).control('Image1')!.valueOf('Picture'), 'pear.png');

    // Cancel in the system dialog changes nothing.
    picks.add(null);
    await choosePicture(tester, s.addPicture);
    expect(form(tester).control('Image1')!.valueOf('Picture'), 'pear.png');
  });

  testWidgets('a picture an Image shows cannot be removed; one no control '
      'shows can, after asking', (tester) async {
    await start(tester);
    await placeImage(tester);
    picks.add((name: 'pear.png', bytes: onePixelPng));
    await choosePicture(tester, s.addPicture);
    await menu(tester, s.picturesMenu);
    await tester.tap(find.byTooltip(s.removePicture));
    await tester.pumpAndSettle();
    expect(
      find.text(
        s.pictureInUse
            .replaceAll('{0}', 'pear.png')
            .replaceAll('{1}', 'Form1.Image1'),
      ),
      findsOneWidget,
    );
    await closeDialog(tester);
    expect(current(tester).pictures.keys, ['pear.png']);
    await closeDialog(tester);

    await choosePicture(tester, s.noPicture);
    await menu(tester, s.picturesMenu);
    await tester.tap(find.byTooltip(s.removePicture));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, s.removePicture));
    await tester.pumpAndSettle();
    expect(current(tester).pictures, isEmpty);
    expect(find.text(s.noPictures), findsOneWidget);
  });

  testWidgets('Save As writes the pictures; removing one deletes its file '
      'on Save', (tester) async {
    await start(tester);
    await menu(tester, s.picturesMenu);
    await addInDialog(tester, (name: 'a.png', bytes: onePixelPng));
    await addInDialog(tester, (name: 'b.png', bytes: onePixelPng));
    await closeDialog(tester);
    saves.add('/home/Fruit');
    await menu(tester, s.saveAs);
    await tester.tap(find.text(s.saveCopyButton));
    await tester.pumpAndSettle();
    expect(
      fs.bytes.keys,
      unorderedEquals([
        '/home/Fruit/pictures/a.png',
        '/home/Fruit/pictures/b.png',
      ]),
    );
    expect(
      readProjectFile(fs.files['/home/Fruit/Fruit.gbproj']!).project.pictures,
      ['a.png', 'b.png'],
    );
    expect(current(tester).isDirty, isFalse);
    await tester.tap(find.byType(SnackBar), warnIfMissed: false);

    await menu(tester, s.picturesMenu);
    await tester.tap(find.byTooltip(s.removePicture).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, s.removePicture));
    await tester.pumpAndSettle();
    await closeDialog(tester);
    expect(
      fs.bytes,
      contains('/home/Fruit/pictures/a.png'),
      reason: 'the file goes only when the project is saved',
    );
    await menu(tester, s.save);
    expect(fs.deleted, ['/home/Fruit/pictures/a.png']);
    expect(fs.bytes.keys, ['/home/Fruit/pictures/b.png']);
  });

  testWidgets('the quiz example has its pictures, and Save As writes them', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text('hello').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('quiz').last);
    await tester.pumpAndSettle();
    final pictures = current(tester).pictures;
    expect(pictures.keys, ['triangle.png', 'pentagon.png']);
    expect(current(tester).isDirty, isFalse);
    saves.add('/home/Quiz');
    await menu(tester, s.saveAs);
    await tester.tap(find.text(s.saveCopyButton));
    await tester.pumpAndSettle();
    expect(fs.bytes, {
      '/home/Quiz/pictures/triangle.png': pictures['triangle.png'],
      '/home/Quiz/pictures/pentagon.png': pictures['pentagon.png'],
    });
    expect(
      readProjectFile(fs.files['/home/Quiz/Quiz.gbproj']!).project.pictures,
      ['triangle.png', 'pentagon.png'],
    );
  });

  testWidgets('a picture of the same name asks before replacing it', (
    tester,
  ) async {
    await start(tester);
    final other = Uint8List.fromList(onePixelPng);
    await menu(tester, s.picturesMenu);
    await addInDialog(tester, (name: 'Apple.png', bytes: onePixelPng));
    await addInDialog(tester, (name: 'apple.PNG', bytes: other));
    expect(
      find.text(s.replacePicture.replaceAll('{0}', 'Apple.png')),
      findsOneWidget,
    );
    await tester.tap(find.text(s.replaceButton));
    await tester.pumpAndSettle();
    expect(current(tester).pictures.keys, ['Apple.png']);
    expect(identical(current(tester).pictures['Apple.png'], other), isTrue);
  });

  testWidgets('a picture that is not taken says why, in Korean too', (
    tester,
  ) async {
    const ko = IdeStrings.ko;
    await start(tester, strings: ko);
    await tester.tap(find.text(ko.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ko.picturesMenu).last);
    await tester.pumpAndSettle();
    final heic = Uint8List.fromList([0, 0, 0, 24, ...'ftypheic'.codeUnits]);
    await addInDialog(tester, (name: 'IMG_0001.jpg', bytes: heic));
    expect(
      find.text(ko.pictureIsHeic.replaceAll('{0}', 'IMG_0001.jpg')),
      findsOneWidget,
    );
    await closeDialog(tester, strings: ko);
    picks.add((name: 'wide.png', bytes: await greyPng(tester, 5000, 10)));
    await tester.tap(find.byKey(addPictureKey));
    await waitFor(tester, find.text(ko.reduceButton));
    expect(
      find.textContaining(
        ko.pictureTooWide
            .replaceAll('{0}', 'wide.png')
            .replaceAll('{1}', '5000')
            .replaceAll('{2}', '10'),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        ko.reduceOffer.replaceAll('{0}', '1024').replaceAll('{1}', 'wide.png'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(ko.runtime.cancel));
    await tester.pumpAndSettle();
    expect(current(tester).pictures, isEmpty);
  });

  testWidgets('a picture too wide is added smaller, as a PNG, only when '
      'the button is pressed', (tester) async {
    await start(tester);
    final wide = await greyPng(tester, 5000, 10);
    await menu(tester, s.picturesMenu);
    picks.add((name: '파노라마.jpg', bytes: wide));
    await tester.tap(find.byKey(addPictureKey));
    await waitFor(tester, find.text(s.reduceButton));
    expect(find.textContaining(s.reduceFirstFrameOnly), findsNothing);
    await tester.tap(find.text(s.runtime.cancel));
    await tester.pumpAndSettle();
    expect(current(tester).pictures, isEmpty, reason: 'not without asking');

    picks.add((name: '파노라마.jpg', bytes: wide));
    await tester.tap(find.byKey(addPictureKey));
    await waitFor(tester, find.text(s.reduceButton));
    await tester.tap(find.text(s.reduceButton));
    await tester.pump();
    expect(find.text(s.reducing), findsOneWidget);
    await waitFor(tester, find.byKey(pictureRowKey('파노라마.png')));
    expect(find.text(s.reducing), findsNothing);
    final added = current(tester).pictures['파노라마.png']!;
    expect(pictureFormat(added), PictureFormat.png);
    expect(pictureSize(added), (1024, 2));
    expect(
      find.text(
        s.pictureReduced
            .replaceAll('{0}', '파노라마.png')
            .replaceAll('{1}', '1024')
            .replaceAll('{2}', '2')
            .replaceAll('{3}', '0.0'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an animated GIF too much for the project says only its first '
      'frame stays; one that cannot be read is not offered it', (tester) async {
    await start(tester);
    await menu(tester, s.picturesMenu);
    // Pictures that fill the project but 100 bytes (their bytes are not
    // read but by size).
    for (var i = 0; i < 4; i++) {
      await addInDialog(tester, (
        name: 'full$i.png',
        bytes: pngHeader(10, 10, length: maxPictureBytes),
      ));
    }
    await addInDialog(tester, (
      name: 'last.png',
      bytes: pngHeader(10, 10, length: maxPictureBytes - 100),
    ));
    picks.add((name: 'moving.gif', bytes: animatedGif));
    await tester.tap(find.byKey(addPictureKey));
    await waitFor(tester, find.text(s.reduceButton));
    expect(find.textContaining(s.reduceFirstFrameOnly), findsOneWidget);
    expect(
      find.textContaining(s.picturesFull.replaceAll('{0}', 'moving.gif')),
      findsOneWidget,
    );
    await tester.tap(find.text(s.runtime.cancel));
    await tester.pumpAndSettle();

    final heic = Uint8List.fromList([0, 0, 0, 24, ...'ftypheic'.codeUnits]);
    await addInDialog(tester, (name: 'IMG_0001.jpg', bytes: heic));
    expect(find.text(s.reduceButton), findsNothing);
    await closeDialog(tester);

    // Looks like a PNG by its first bytes, but cannot be drawn.
    picks.add((name: 'broken.png', bytes: pngHeader(5000, 10)));
    await tester.tap(find.byKey(addPictureKey));
    await waitFor(
      tester,
      find.text(
        s.pictureTooWide
            .replaceAll('{0}', 'broken.png')
            .replaceAll('{1}', '5000')
            .replaceAll('{2}', '10'),
      ),
    );
    expect(find.text(s.reduceButton), findsNothing);
    await closeDialog(tester);
  });

  testWidgets('a project opened from disk brings its pictures; missing '
      'ones are named', (tester) async {
    final hello = exampleProjects['hello']!;
    fs.add('/home/Fruit', {
      for (final MapEntry(:key, :value) in hello.entries)
        if (key != 'Hello.gbproj') key: value,
      'Fruit.gbproj': helloWithPictures(['a.png', 'b.png']),
    });
    fs.folders.add('/home/Fruit/pictures');
    fs.bytes['/home/Fruit/pictures/a.png'] = onePixelPng;
    await start(tester);
    opens.add('/home/Fruit/Fruit.gbproj');
    await menu(tester, s.open);
    expect(
      find.text(s.missingPictures.replaceAll('{0}', 'b.png')),
      findsOneWidget,
    );
    await closeDialog(tester);
    expect(current(tester).pictures, {'a.png': onePixelPng});
    expect(current(tester).isDirty, isFalse);
  });

  testWidgets('the Picture list is boxed like the text fields', (tester) async {
    await start(tester);
    await placeImage(tester);
    final box = find.descendant(
      of: find.byKey(propertyFieldKey('Picture')),
      matching: find.byType(InputDecorator),
    );
    expect(box, findsOneWidget);
    expect(
      tester.widget<InputDecorator>(box).decoration.border,
      isA<OutlineInputBorder>(),
    );
    final left = find.descendant(
      of: find.byKey(propertyFieldKey('Left')),
      matching: find.byType(InputDecorator),
    );
    expect(
      tester.getSize(box).height,
      moreOrLessEquals(tester.getSize(left.first).height, epsilon: 2),
    );
    expect(tester.getSize(box).width, tester.getSize(left.first).width);
  });

  testWidgets('the run window shows the picture', (tester) async {
    await start(tester);
    await placeImage(tester);
    picks.add((name: 'pear.png', bytes: onePixelPng));
    await choosePicture(tester, s.addPicture);
    await tester.tap(find.text('${s.run} (F5)'));
    await tester.pumpAndSettle();
    final shown = find.descendant(
      of: find.byType(GbImage),
      matching: find.byType(Image),
    );
    expect(shown, findsWidgets);
    expect(
      tester
          .widgetList<Image>(shown)
          .map((i) => (i.image as MemoryImage).bytes),
      everyElement(onePixelPng),
    );
  });
}
