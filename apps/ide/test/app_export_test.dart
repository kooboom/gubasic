import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/browser.dart';
import 'package:gubasic_ide/src/project/project_controller.dart';
import 'package:gubasic_ide/src/project/app_export.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';

import 'support/fake_browser.dart';
import 'support/memory_folders.dart';

/// File → Export as Web App (D84) and Export as Windows App (D86): a
/// player's template with the project's bundle in it, under an app ID kept
/// in the `.gbproj` file.
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

  Uint8List windowsTemplate({String? program = 'gubasic_player_app.exe'}) {
    final archive = Archive();
    void add(String path, String text) =>
        archive.add(ArchiveFile.bytes(path, utf8.encode(text)));
    add('gubasic_player_app.exe', 'MZ the player');
    add('flutter_windows.dll', 'the engine');
    add('data/app.so', 'the code');
    add(
      'template.json',
      jsonEncode({
        'gubasic': '0.1.0',
        'bundleFormat': bundleFormatVersion,
        'program': ?program,
      }),
    );
    return ZipEncoder().encodeBytes(archive);
  }

  group('windowsAppZip', () {
    test('puts the template, the program renamed after the project, the '
        'bundle and the guide in a folder', () {
      const bundle = ProjectBundle(
        id: 'abcdefgh12345678',
        name: '퀴즈',
        files: demo,
      );
      final files = unzip(windowsAppZip(windowsTemplate(), bundle, 'open it'));
      expect(
        files.keys,
        unorderedEquals([
          '퀴즈-windows/퀴즈.exe',
          '퀴즈-windows/flutter_windows.dll',
          '퀴즈-windows/data/app.so',
          '퀴즈-windows/project.gbz',
          '퀴즈-windows/README.txt',
        ]),
      );
      expect(utf8.decode(files['퀴즈-windows/퀴즈.exe']!), 'MZ the player');
      final read = ProjectBundle.decode(files['퀴즈-windows/project.gbz']!);
      expect(read.id, 'abcdefgh12345678');
      expect(read.files, demo);
      expect(utf8.decode(files['퀴즈-windows/README.txt']!), 'open it');
    });

    test('refuses a template that does not name its program, a web '
        'template, or another bundle layout', () {
      const bundle = ProjectBundle(id: 'abcdefgh', name: 'Demo', files: demo);
      expect(
        () => windowsAppZip(windowsTemplate(program: null), bundle, ''),
        throwsA(isA<TemplateNotUsable>()),
      );
      expect(
        () => windowsAppZip(windowsTemplate(program: 'other.exe'), bundle, ''),
        throwsA(isA<TemplateNotUsable>()),
      );
      expect(
        () => windowsAppZip(template(), bundle, ''),
        throwsA(isA<TemplateNotUsable>()),
      );
      expect(
        () => windowsAppZip(template(bundleFormat: 2), bundle, ''),
        throwsA(isA<TemplateNotUsable>()),
      );
      // Nor does a web app come from the Windows template.
      expect(
        () => webAppZip(windowsTemplate(), bundle, ''),
        throwsA(isA<TemplateNotUsable>()),
      );
    });
  });

  test('a project name becomes a name Windows takes for a file', () {
    expect(appFileName('Quiz'), 'Quiz');
    expect(appFileName('퀴즈 게임'), '퀴즈 게임');
    expect(appFileName('a/b:c*d?'), 'a_b_c_d_');
    expect(appFileName('  dots.. '), 'dots');
    expect(appFileName('CON'), 'App');
    expect(appFileName('com1'), 'App');
    expect(appFileName('...'), 'App');
  });

  Future<void> export(
    WidgetTester tester,
    IdeStrings strings, {
    bool windows = false,
  }) async {
    await tester.tap(find.text(strings.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(windows ? strings.exportWindowsApp : strings.exportWebApp),
    );
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
        fetchTemplate: (_) async => template(),
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
        fetchTemplate: (_) async => template(),
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
        fetchTemplate: (_) async => template(),
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
        fetchTemplate: (_) async => throw const TemplateUnavailable(),
      ),
    );
    await export(tester, s);
    expect(find.text(s.webAppTemplateUnavailable), findsOneWidget);
  });

  testWidgets('the web IDE downloads a Windows app, its guide naming the '
      'program, from the Windows template', (tester) async {
    bigView(tester);
    final browser = FakeBrowser();
    final asked = <AppTemplate>[];
    await tester.pumpWidget(
      IdeApp(
        projects: const {'demo': demo},
        open: 'demo',
        strings: IdeStrings.ko,
        browser: browser,
        kept: await BrowserProjects.open(browser.projects, browser.storage),
        pickZip: () async => null,
        fetchTemplate: (which) async {
          asked.add(which);
          return windowsTemplate();
        },
      ),
    );
    await export(tester, IdeStrings.ko, windows: true);
    expect(asked, [AppTemplate.windows]);
    expect(browser.downloads.single.$1, 'Demo-windows.zip');
    final files = unzip(browser.downloads.single.$2);
    expect(files.keys, contains('Demo-windows/Demo.exe'));
    expect(
      ProjectBundle.decode(files['Demo-windows/project.gbz']!).id,
      'exampledemo',
    );
    expect(
      utf8.decode(files['Demo-windows/README.txt']!),
      IdeStrings.ko.windowsAppGuide.replaceAll('{0}', 'Demo.exe'),
    );
    expect(find.textContaining('폴더 안의 Demo.exe 파일을 엽니다'), findsOneWidget);
  });

  testWidgets('a desktop IDE saves a Windows app where the user chooses, and '
      'says when the Windows player cannot be downloaded', (tester) async {
    bigView(tester);
    final folders = MemoryFolders()..folders.add('/out');
    var reachable = true;
    await tester.pumpWidget(
      IdeApp(
        projects: const {'demo': demo},
        open: 'demo',
        strings: s,
        folders: folders,
        fetchTemplate: (which) async {
          if (!reachable) throw const TemplateUnavailable();
          return which == AppTemplate.windows ? windowsTemplate() : template();
        },
        pickers: ProjectPickers(
          openProjectFile: (_) async => null,
          saveLocation: (_, _) async => null,
          saveZipLocation: (name, _) async => '/out/$name',
        ),
      ),
    );
    await export(tester, s, windows: true);
    expect(folders.written, ['/out/Demo-windows.zip']);
    expect(
      unzip(folders.bytes['/out/Demo-windows.zip']!).keys,
      contains('Demo-windows/Demo.exe'),
    );
    expect(
      find.textContaining('unzip it and open Demo.exe in the folder'),
      findsOneWidget,
    );
    await tester.tap(find.text(s.runtime.ok));
    await tester.pumpAndSettle();

    reachable = false;
    await export(tester, s, windows: true);
    expect(find.text(s.windowsAppTemplateUnavailable), findsOneWidget);
  });

  testWidgets('the macOS IDE exports a macOS app with the maker it is given, '
      'from the macOS template', (tester) async {
    bigView(tester);
    final folders = MemoryFolders()..folders.add('/out');
    final made = <(int, ProjectBundle, String)>[];
    await tester.pumpWidget(
      IdeApp(
        projects: const {'demo': demo},
        open: 'demo',
        strings: s,
        folders: folders,
        fetchTemplate: (which) async =>
            which == AppTemplate.macos ? utf8.encode('mac') : template(),
        macAppMaker: (template, bundle, guide) async {
          made.add((template.length, bundle, guide));
          return Uint8List.fromList(utf8.encode('the app'));
        },
        pickers: ProjectPickers(
          openProjectFile: (_) async => null,
          saveLocation: (_, _) async => null,
          saveZipLocation: (name, _) async => '/out/$name',
        ),
      ),
    );
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.exportMacApp));
    await tester.pumpAndSettle();
    final (length, bundle, guide) = made.single;
    expect(length, 3);
    expect(bundle.id, 'exampledemo');
    expect(guide, s.macAppGuide.replaceAll('{0}', 'Demo.app'));
    expect(folders.written, ['/out/Demo-macos.zip']);
    expect(
      find.textContaining('Unzip it and open Demo.app in the folder'),
      findsOneWidget,
    );
  });

  testWidgets('elsewhere the macOS item is greyed out and says why (D87)', (
    tester,
  ) async {
    bigView(tester);
    final browser = FakeBrowser();
    var fetched = 0;
    await tester.pumpWidget(
      IdeApp(
        projects: const {'demo': demo},
        open: 'demo',
        strings: IdeStrings.ko,
        browser: browser,
        kept: await BrowserProjects.open(browser.projects, browser.storage),
        pickZip: () async => null,
        fetchTemplate: (_) async {
          fetched++;
          return template();
        },
      ),
    );
    await tester.tap(find.text(IdeStrings.ko.fileMenu));
    await tester.pumpAndSettle();
    const ko = IdeStrings.ko;
    final item = find.text('${ko.exportMacApp} (${ko.macAppOnlyOnMac})');
    expect(item, findsOneWidget);
    expect(
      tester
          .widget<MenuItemButton>(
            find.byKey(const ValueKey('menu.exportMacApp')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byTooltip(ko.macAppOnlyOnMacWhy), findsOneWidget);
    await tester.tap(item, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(fetched, 0);
    expect(browser.downloads, isEmpty);
  });
}
