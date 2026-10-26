import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/browser.dart';
import 'package:gubasic_ide/src/project/project_controller.dart';
import 'package:gubasic_ide/src/project/web_export.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';

import 'support/fake_browser.dart';
import 'support/memory_folders.dart';

/// File → Export as Web App (D84): the web player's template with the
/// project's bundle in it, under an app ID kept in the `.gbproj` file.
void main() {
  const s = IdeStrings.en;
  const demo = {
    'Demo.gbproj':
        'formatVersion: 1\nname: Demo\nstartup: Form1\nforms:\n'
        '  - Form1\n',
    'Form1.form.yaml': 'formatVersion: 1\nproperties:\n  Caption: Demo\n',
    'Form1.gbas': 'Sub Form_Load()\n    Debug.Print("hi")\nEnd Sub\n',
  };

  Uint8List template({int bundleFormat = bundleFormatVersion}) {
    final archive = Archive();
    void add(String path, String text) =>
        archive.add(ArchiveFile.bytes(path, utf8.encode(text)));
    add(
      'index.html',
      '<html><head><base href="./">'
          '<meta name="apple-mobile-web-app-title" content="GuBASIC">'
          '<title>GuBASIC Player</title></head></html>',
    );
    add('manifest.json', '{"name": "GuBASIC Player", "short_name": "GuBASIC"}');
    add('main.dart.js', '// the player');
    add('template.json', '{"gubasic":"0.1.0","bundleFormat":$bundleFormat}');
    return ZipEncoder().encodeBytes(archive);
  }

  Map<String, List<int>> unzip(List<int> bytes) => {
    for (final f in ZipDecoder().decodeBytes(bytes).files)
      if (f.isFile) f.name: f.content,
  };

  group('webAppZip', () {
    const bundle = ProjectBundle(
      id: 'abcdefgh12345678',
      name: 'Demo',
      files: demo,
    );

    test('puts the bundle and the guide into the template, with the '
        "project's name", () {
      final files = unzip(webAppZip(template(), bundle, 'how to host'));
      expect(
        files.keys,
        unorderedEquals([
          'Demo-web/index.html',
          'Demo-web/manifest.json',
          'Demo-web/main.dart.js',
          'Demo-web/project.gbz',
          'Demo-web/HOSTING.txt',
        ]),
      );
      final html = utf8.decode(files['Demo-web/index.html']!);
      expect(html, contains('<title>Demo</title>'));
      expect(html, contains('app-title" content="Demo"'));
      expect(html, contains('<base href="./">'));
      expect(jsonDecode(utf8.decode(files['Demo-web/manifest.json']!)), {
        'name': 'Demo',
        'short_name': 'Demo',
      });
      final read = ProjectBundle.decode(files['Demo-web/project.gbz']!);
      expect(read.id, 'abcdefgh12345678');
      expect(read.files, demo);
      expect(utf8.decode(files['Demo-web/HOSTING.txt']!), 'how to host');
    });

    test('refuses a template for another bundle layout, or none', () {
      expect(
        () => webAppZip(template(bundleFormat: 2), bundle, ''),
        throwsA(
          isA<TemplateNotUsable>().having((p) => p.bundleFormat, 'format', 2),
        ),
      );
      expect(
        () => webAppZip(utf8.encode('<html>'), bundle, ''),
        throwsA(isA<TemplateNotUsable>()),
      );
    });
  });

  test("an example's app ID comes from its name", () {
    expect(exampleAppId('hello'), 'examplehello');
    expect(exampleAppId('A'), 'examplea');
    expect(isProjectId(exampleAppId('a' * 40)), isTrue);
    expect(isProjectId(exampleAppId('hello')), isTrue);
  });

  test('withProjectId writes the ID and keeps the rest', () {
    final files = withProjectId(demo, 'abcdefgh12345678')!;
    expect(projectIdOf(demo), isNull);
    expect(projectIdOf(files), 'abcdefgh12345678');
    expect(readProjectFile(files['Demo.gbproj']!).project.forms, ['Form1']);
    expect(withProjectId({'Demo.gbproj': 'name: [\n'}, 'abcdefgh'), isNull);
  });

  Future<void> export(WidgetTester tester, IdeStrings strings) async {
    await tester.tap(find.text(strings.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.exportWebApp));
    await tester.pumpAndSettle();
  }

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a project on disk gets an app ID written into its .gbproj '
      'file alone, and keeps it', (tester) async {
    bigView(tester);
    final folders = MemoryFolders()
      ..add('/p/Demo', demo)
      ..folders.add('/out');
    await tester.pumpWidget(
      IdeApp(
        projects: const {'demo': demo},
        open: 'demo',
        strings: s,
        folders: folders,
        fetchTemplate: () async => template(),
        pickers: ProjectPickers(
          openProjectFile: (_) async => '/p/Demo/Demo.gbproj',
          saveLocation: (_, _) async => null,
          saveZipLocation: (name, _) async => '/out/$name',
        ),
      ),
    );
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.open));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<IdeShell>(find.byType(IdeShell))
        .controller;
    const changed = 'Sub Form_Load()\n    Debug.Print("changed")\nEnd Sub\n';
    controller.current.setFile('Form1.gbas', changed);

    await export(tester, s);
    expect(
      find.textContaining('Saved the web app as /out/Demo-web.zip'),
      findsOneWidget,
    );
    expect(folders.written, ['/p/Demo/Demo.gbproj', '/out/Demo-web.zip']);
    final id = projectIdOf({
      'Demo.gbproj': folders.files['/p/Demo/Demo.gbproj']!,
    })!;
    expect(isProjectId(id), isTrue);
    // The other change is exported, but stays unsaved.
    expect(folders.files['/p/Demo/Form1.gbas'], demo['Form1.gbas']);
    expect(controller.current.isDirty, isTrue);
    final bundle = ProjectBundle.decode(
      unzip(folders.bytes['/out/Demo-web.zip']!)['Demo-web/project.gbz']!,
    );
    expect(bundle.id, id);
    expect(bundle.files['Form1.gbas'], changed);
    await tester.tap(find.text(s.runtime.ok));
    await tester.pumpAndSettle();

    // Exporting again keeps the ID, and writes nothing to the project.
    await export(tester, s);
    expect(folders.written, [
      '/p/Demo/Demo.gbproj',
      '/out/Demo-web.zip',
      '/out/Demo-web.zip',
    ]);
    expect(
      ProjectBundle.decode(
        unzip(folders.bytes['/out/Demo-web.zip']!)['Demo-web/project.gbz']!,
      ).id,
      id,
    );
  });

  testWidgets('the web IDE downloads an example as a web app, under an ID '
      'from its name', (tester) async {
    bigView(tester);
    final browser = FakeBrowser();
    await tester.pumpWidget(
      IdeApp(
        projects: const {'demo': demo},
        open: 'demo',
        strings: IdeStrings.ko,
        browser: browser,
        kept: await BrowserProjects.open(browser.projects, browser.storage),
        pickZip: () async => null,
        fetchTemplate: () async => template(),
      ),
    );
    await export(tester, IdeStrings.ko);
    expect(browser.downloads.single.$1, 'Demo-web.zip');
    final files = unzip(browser.downloads.single.$2);
    expect(
      ProjectBundle.decode(files['Demo-web/project.gbz']!).id,
      'exampledemo',
    );
    expect(
      utf8.decode(files['Demo-web/HOSTING.txt']!),
      IdeStrings.ko.webAppGuide,
    );
    expect(find.textContaining('Demo-web.zip 파일로 저장했습니다'), findsOneWidget);
  });

  testWidgets('a project with errors is not exported', (tester) async {
    bigView(tester);
    final browser = FakeBrowser();
    await tester.pumpWidget(
      IdeApp(
        projects: {
          'demo': {...demo, 'Form1.gbas': 'Sub Form_Load(\n'},
        },
        open: 'demo',
        strings: s,
        browser: browser,
        kept: await BrowserProjects.open(browser.projects, browser.storage),
        pickZip: () async => null,
        fetchTemplate: () async => template(),
      ),
    );
    await export(tester, s);
    expect(find.text(s.webAppCannotRun), findsOneWidget);
    expect(browser.downloads, isEmpty);
  });

  testWidgets('says when the template cannot be downloaded', (tester) async {
    bigView(tester);
    final browser = FakeBrowser();
    await tester.pumpWidget(
      IdeApp(
        projects: const {'demo': demo},
        open: 'demo',
        strings: s,
        browser: browser,
        kept: await BrowserProjects.open(browser.projects, browser.storage),
        pickZip: () async => null,
        fetchTemplate: () async => throw const TemplateUnavailable(),
      ),
    );
    await export(tester, s);
    expect(find.text(s.webAppTemplateUnavailable), findsOneWidget);
  });
}
