import 'dart:async';

import 'dart:convert';

import '../analyzer/compile.dart';
import '../analyzer/conversions.dart';
import '../analyzer/forms.dart';
import '../components/database_component.dart';
import '../components/http_component.dart';
import '../components/room_component.dart';
import '../components/sound_component.dart';
import '../components/web_socket_component.dart';
import '../forms/anchor.dart';
import '../forms/component.dart';
import '../forms/form_file.dart';
import '../forms/keys.dart';
import '../forms/pictures.dart';
import '../forms/sounds.dart';
import '../interpreter/host.dart';
import '../interpreter/interpreter.dart';
import '../interpreter/run_result.dart';
import '../interpreter/values.dart';
import '../pdf/pdf_document.dart';
import '../text/text_codec.dart';
import 'room_script.dart';
import 'web_socket_script.dart';

/// One step of an event script (`NAME.events`, docs/DESIGN.md §9.1).
sealed class ScriptStep {
  const ScriptStep(this.text);

  /// The line as written, without its comment: echoed as `> text`.
  final String text;
}

/// `btnSave.Click`: the user causes an event. On a CheckBox, `Click` is
/// the user's click: it changes Checked, and Changed runs (D44).
class EventStep extends ScriptStep {
  const EventStep(super.text, this.control, this.event, {this.form});

  /// The control's name, or null for `Form`.
  final String? control;
  final String event;

  /// `Form2.btnOK.Click`: the form the user acts on, which must be in
  /// front (D88); null for the one in front.
  final String? form;
}

/// `txtName.Type "Kim"`: the user changes a TextBox's text to "Kim"; its
/// Changed event runs if the text changed.
class TypeStep extends ScriptStep {
  const TypeStep(super.text, this.control, this.value);

  final String control;
  final String value;
}

/// `lstCity.Select 2`: the user picks item 2 of a ListBox; its Changed
/// runs if ListIndex changed (D46).
class SelectStep extends ScriptStep {
  const SelectStep(super.text, this.control, this.index);

  final String control;
  final int index;
}

/// `Form.KeyDown Left`, `Form.KeyUp Shift+A`, `txtName.KeyDown A`: the
/// user presses or lets go a key (D101), with the form in front focused,
/// or while typing in TextBox [control].
class KeyStep extends ScriptStep {
  const KeyStep(super.text, this.event, this.key,
      {this.control, this.shift = false, this.ctrl = false, this.alt = false});

  /// `KeyDown` or `KeyUp`.
  final String event;

  /// The key's name in Keys (`Left`, `A`, `D1`).
  final String key;

  /// The TextBox typed in; null for the form.
  final String? control;
  final bool shift;
  final bool ctrl;
  final bool alt;
}

/// `lblName.MouseDown Right 10 5` or `Form.MouseUp Left 30 40`: the user
/// presses or lets go a mouse button on a control, or the form, at a
/// place from its top left corner (D111).
class MouseStep extends ScriptStep {
  const MouseStep(super.text, this.event, this.button, this.x, this.y,
      {this.control});

  final String? control;

  /// `MouseDown` or `MouseUp`.
  final String event;

  /// `Left`, `Right` or `Middle`.
  final String button;
  final int x;
  final int y;
}

/// `grdScores.Click 0 1`, or `grdScores.Edit 0 1 "95"`: the user chooses
/// a Grid's cell (row, column) and its Click runs; or changes the text of
/// the cell chosen, and its Changed runs (D116).
class GridStep extends ScriptStep {
  const GridStep(super.text, this.control, this.row, this.col, this.value);

  final String control;
  final int row;
  final int col;

  /// Null for a click.
  final String? value;
}

/// `OK`: closes the open MsgBox.
class OkStep extends ScriptStep {
  const OkStep(super.text);
}

/// `Answer "Kim"` or `Cancel`: closes the open InputBox.
class AnswerStep extends ScriptStep {
  const AnswerStep(super.text, this.value);

  /// Null for Cancel, which gives "".
  final String? value;
}

/// `Choose mnuEditCopy` or `Dismiss`: chooses an item of the menu
/// `PopupMenu` shows, or closes it with none (D106).
class ChooseStep extends ScriptStep {
  const ChooseStep(super.text, this.item);

  /// Null for Dismiss.
  final String? item;
}

/// `Pick "names.csv"`: chooses a file in the open or save dialog (D113).
/// `Cancel` cancels it.
class PickStep extends ScriptStep {
  const PickStep(super.text, this.name);

  final String name;
}

/// `Close`: the user closes the form.
class CloseStep extends ScriptStep {
  const CloseStep(super.text);
}

/// `Wait 16`: 16 milliseconds pass on the host's clock, the one
/// `Milliseconds()` reads (D138); nothing else happens.
class WaitStep extends ScriptStep {
  const WaitStep(super.text, this.milliseconds);

  final int milliseconds;
}

/// `Form.Resize 600 400`: the user makes the inside of the form 600 x 400;
/// the controls move as their Anchor says (D57), then Form_Resize runs
/// (D58). Nothing happens when it already is that size.
class ResizeStep extends ScriptStep {
  const ResizeStep(super.text, this.width, this.height);

  final int width;
  final int height;
}

/// `Server Send {"kind":"news"}`, `Server Close bye`, `Server Error
/// lost`: the test's WebSocket server sends a message on the connection
/// opened last, closes it, or reports a problem (D136).
class ServerStep extends ScriptStep {
  const ServerStep(super.text, this.action);

  final ServerAction action;
}

/// `Peer 민지 Join`, `Peer 민지 Send {"choice":2}`: someone else in the
/// test's relay server acts (D136, [PeerAction]).
class PeerStep extends ScriptStep {
  const PeerStep(super.text, this.action);

  final PeerAction action;
}

/// `Room Close idle`: the test's relay server closes every room with that
/// reason; `Room Drop`: the program's connection to it is lost (D136).
class RoomStep extends ScriptStep {
  const RoomStep(super.text, this.verb, this.argument);

  final String verb;
  final String argument;
}

final _peer =
    RegExp(r'^Peer\s+(\S+)\s+(Create|Join|Send|SendTo|Leave|Lock)(?:\s(.*))?$');
final _room = RegExp(r'^Room\s+(Close|Drop)(?:\s+(.*))?$');
final _server = RegExp(r'^Server\s+(Send|Close|Error)(?:\s(.*))?$');
final _event = RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\.([A-Za-z][A-Za-z0-9_]*)$');
final _formEvent = RegExp(
    r'^([A-Za-z][A-Za-z0-9_]*)\.([A-Za-z][A-Za-z0-9_]*)\.([A-Za-z][A-Za-z0-9_]*)$');
final _type = RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\.Type\s+"((?:[^"]|"")*)"$');
final _select = RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\.Select\s+(\d+)$');
final _answer = RegExp(r'^Answer\s+"((?:[^"]|"")*)"$');
final _choose = RegExp(r'^Choose\s+([A-Za-z][A-Za-z0-9_]*)$');
final _pick = RegExp(r'^Pick\s+"((?:[^"]|"")*)"$');
final _key = RegExp(
    r'^([A-Za-z][A-Za-z0-9_]*)\.(KeyDown|KeyUp)\s+((?:(?:Shift|Ctrl|Alt)\+)*)([A-Za-z0-9]+)$');
final _mouse = RegExp(
    r'^([A-Za-z][A-Za-z0-9_]*)\.(MouseDown|MouseUp)\s+(Left|Right|Middle)\s+(\d+)\s+(\d+)$');
final _gridStep = RegExp(
    r'^([A-Za-z][A-Za-z0-9_]*)\.(Click|Edit)\s+(\d+)\s+(\d+)(?:\s+"((?:[^"]|"")*)")?$');
final _resize = RegExp(r'^Form\.Resize\s+(\d+)\s+(\d+)$', caseSensitive: false);
final _wait = RegExp(r'^Wait\s+(\d+)$', caseSensitive: false);

/// Reads an event script. Each line is one step; `'` starts a comment.
/// Throws a [FormatException] for a line it cannot read.
List<ScriptStep> parseEventScript(String text) {
  final steps = <ScriptStep>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = _withoutComment(lines[i]).trim();
    if (line.isEmpty) continue;
    RegExpMatch? m;
    if ((m = _peer.firstMatch(line)) != null) {
      steps.add(PeerStep(line, PeerAction(m![1]!, m[2]!, m[3]?.trim() ?? '')));
    } else if ((m = _room.firstMatch(line)) != null) {
      steps.add(RoomStep(line, m![1]!, m[2]?.trim() ?? ''));
    } else if ((m = _server.firstMatch(line)) != null) {
      final text = m![2] ?? '';
      steps.add(ServerStep(
          line,
          switch (m[1]) {
            'Send' => ServerAction.send(text),
            'Close' => ServerAction.close(text),
            _ => ServerAction.error(text),
          }));
    } else if (line == 'OK') {
      steps.add(OkStep(line));
    } else if (line == 'Cancel') {
      steps.add(AnswerStep(line, null));
    } else if (line == 'Close') {
      steps.add(CloseStep(line));
    } else if ((m = _wait.firstMatch(line)) != null) {
      steps.add(WaitStep(line, int.parse(m![1]!)));
    } else if ((m = _pick.firstMatch(line)) != null) {
      steps.add(PickStep(line, m![1]!.replaceAll('""', '"')));
    } else if (line == 'Dismiss') {
      steps.add(ChooseStep(line, null));
    } else if ((m = _choose.firstMatch(line)) != null) {
      steps.add(ChooseStep(line, m![1]!));
    } else if ((m = _answer.firstMatch(line)) != null) {
      steps.add(AnswerStep(line, m![1]!.replaceAll('""', '"')));
    } else if ((m = _key.firstMatch(line)) != null) {
      final target = m![1]!;
      final modifiers = m[3]!.split('+');
      final key = keyCodesByLowerName[m[4]!.toLowerCase()];
      if (key == null) {
        throw FormatException('line ${i + 1}: no key named "${m[4]}"');
      }
      steps.add(KeyStep(line, m[2]!, key.$1,
          control: target.toLowerCase() == 'form' ? null : target,
          shift: modifiers.contains('Shift'),
          ctrl: modifiers.contains('Ctrl'),
          alt: modifiers.contains('Alt')));
    } else if ((m = _gridStep.firstMatch(line)) != null &&
        (m![2] == 'Click') == (m[5] == null)) {
      steps.add(GridStep(line, m[1]!, int.parse(m[3]!), int.parse(m[4]!),
          m[5]?.replaceAll('""', '"')));
    } else if ((m = _mouse.firstMatch(line)) != null) {
      final target = m![1]!;
      steps.add(MouseStep(
          line, m[2]!, m[3]!, int.parse(m[4]!), int.parse(m[5]!),
          control: target.toLowerCase() == 'form' ? null : target));
    } else if ((m = _resize.firstMatch(line)) != null) {
      steps.add(ResizeStep(line, int.parse(m![1]!), int.parse(m[2]!)));
    } else if ((m = _select.firstMatch(line)) != null) {
      steps.add(SelectStep(line, m![1]!, int.parse(m[2]!)));
    } else if ((m = _type.firstMatch(line)) != null) {
      steps.add(TypeStep(line, m![1]!, m[2]!.replaceAll('""', '"')));
    } else if ((m = _formEvent.firstMatch(line)) != null) {
      final control = m![2]!;
      steps.add(EventStep(
          line, control.toLowerCase() == 'form' ? null : control, m[3]!,
          form: m[1]));
    } else if ((m = _event.firstMatch(line)) != null) {
      final control = m![1]!;
      steps.add(EventStep(
          line, control.toLowerCase() == 'form' ? null : control, m[2]!));
    } else {
      throw FormatException('line ${i + 1}: cannot read "$line"');
    }
  }
  return steps;
}

/// [line] without a `'` comment outside a string.
String _withoutComment(String line) {
  var inString = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') inString = !inString;
    if (c == "'" && !inString) return line.substring(0, i);
  }
  return line;
}

class _Dialog {
  _Dialog(this.isInputBox, {this.isPopup = false, this.isFile = false});

  final bool isInputBox;

  /// An open or save dialog (D113).
  final bool isFile;

  /// A menu `PopupMenu` shows (D106).
  final bool isPopup;
  final answer = Completer<Object?>();
}

/// The transcript lines for what a program shows. [ScriptedHost] and the
/// IDE's run window both write them, so that one `.out` file checks both.
abstract final class TranscriptLine {
  static String debugPrint(String line) => 'Debug.Print: $line';

  static String msgBox(String prompt, String title) =>
      title.isEmpty ? 'MsgBox: $prompt' : 'MsgBox [$title]: $prompt';

  static String inputBox(String prompt, String title) =>
      title.isEmpty ? 'InputBox: $prompt' : 'InputBox [$title]: $prompt';

  /// `PopupMenu` shows [menu]'s items (D106).
  static String popupMenu(String menu) => 'PopupMenu: $menu';

  /// An OpenFileDialog or a SaveFileDialog is shown (D113).
  static String fileDialog(String component, String title) =>
      title.isEmpty ? component : '$component: $title';

  /// The program wrote [bytes] to the file [path] (D113): its text, with
  /// its line breaks as `\n`, after `(BOM)` when it starts with one.
  static String wroteFile(String path, List<int> bytes, {bool append = false}) {
    final bom = bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF;
    final text =
        decodeText(bytes).replaceAll('\r', '\\r').replaceAll('\n', '\\n');
    return '${append ? 'Appended' : 'Wrote'} $path: ${bom ? '(BOM) ' : ''}$text';
  }

  /// The program saved [document] as the PDF file [path] (D117).
  static String wrotePdf(String path, GbPdfDocument document) =>
      'Wrote $path: PDF ${document.describe()}';

  static String saveSettings(String text) => 'Settings: $text';

  /// The program played a sound, started music, stopped it or set the
  /// volume (D138).
  static String sound(String name) => 'Sound: $name';
  static String music(String name) => 'Music: $name';
  static const musicStopped = 'Music stopped';
  static String volume(int volume) => 'Volume: $volume';

  /// [form] is named when the program has several forms (D88).
  static String setProperty(String? control, String property, Object value,
          {String? form}) =>
      'Set ${form == null ? '' : '$form.'}${control ?? 'Form'}.$property: '
      '${switch (value) {
        bool b => b ? 'True' : 'False',
        double d => formatDouble(d),
        Unset() => '(not set)',
        _ => value,
      }}';

  /// The program put a control made with New on a form (D98).
  static String addControl(String control, String component, {String? form}) =>
      'Add ${form == null ? '' : '$form.'}$control ($component)';

  /// The program took a control off a form (D98).
  static String removeControl(String control, {String? form}) =>
      'Remove ${form == null ? '' : '$form.'}$control';

  /// The forms shown changed, in a program with several forms (D88): from
  /// the back to the front.
  static String forms(List<ShownForm> forms) =>
      forms.isEmpty ? 'Forms: (none)' : 'Forms: ${forms.join(' > ')}';

  /// The program sent an HTTP request (D125): its method and address, the
  /// headers it set and the ones the method adds, in brackets, then its
  /// body with line breaks as `\n`.
  static String http(HttpRequest request) {
    final headers =
        request.headers.entries.map((e) => '${e.key}: ${e.value}').join('; ');
    final body =
        request.bodyText.replaceAll('\r', '\\r').replaceAll('\n', '\\n');
    return 'Http: ${request.method} ${request.url}'
        '${headers.isEmpty ? '' : ' [$headers]'}'
        '${body.isEmpty ? '' : ' $body'}';
  }
}

/// What a test's server answers to one request (D125): a stanza of a
/// `NAME.http` file.
///
///     GET https://api.example.com/scores
///     200 application/json
///     X-Count: 2
///     [{"name":"Kim","points":10}]
///
///     GET https://api.example.com/down
///     fails connection refused
///
/// The first line is the method and the address; the second the status
/// and, after a space, the Content-Type, or `fails` and why no answer
/// comes; then header lines (`Name: value`); the rest is the body. Stanzas
/// are parted by an empty line.
class HttpStub {
  const HttpStub(this.method, this.url, this.status, this.headers, this.body,
      {this.failure});

  final String method;
  final String url;
  final int status;

  /// By lower-case name.
  final Map<String, String> headers;
  final String body;

  /// Why no answer comes, for a `fails` stanza; null otherwise.
  final String? failure;
}

/// Reads a `NAME.http` file ([HttpStub]).
List<HttpStub> parseHttpScript(String text) {
  final stubs = <HttpStub>[];
  final header = RegExp(r'^([A-Za-z][A-Za-z0-9-]*):\s*(.*)$');
  for (final stanza
      in text.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'))) {
    final lines = stanza.split('\n').where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) continue;
    if (lines.length < 2) {
      throw FormatException('a stub needs two lines: $stanza');
    }
    final request = lines[0].trim().split(RegExp(r'\s+'));
    if (request.length != 2) {
      throw FormatException('a stub starts with METHOD url: ${lines[0]}');
    }
    final second = lines[1].trim();
    if (second.startsWith('fails')) {
      stubs.add(HttpStub(request[0].toUpperCase(), request[1], 0, const {}, '',
          failure: second.substring(5).trim()));
      continue;
    }
    final space = second.indexOf(' ');
    final status =
        int.tryParse(space < 0 ? second : second.substring(0, space));
    if (status == null) throw FormatException('a stub needs a status: $second');
    final headers = <String, String>{
      if (space >= 0) 'content-type': second.substring(space + 1).trim(),
    };
    var i = 2;
    for (; i < lines.length; i++) {
      final m = header.firstMatch(lines[i]);
      if (m == null) break;
      headers[m[1]!.toLowerCase()] = m[2]!;
    }
    stubs.add(HttpStub(request[0].toUpperCase(), request[1], status, headers,
        lines.sublist(i).join('\n')));
  }
  return stubs;
}

/// The `Sound` object of a test (D138): records each play in
/// [transcript]; a name not in [sounds] is R053, as it would be.
class _ScriptedSound extends SoundComponent {
  _ScriptedSound(this.sounds, this.transcript);

  final List<String> sounds;
  final List<String> transcript;

  String _named(String name) =>
      soundNamed(sounds, name) ?? (throw SoundComponent.notFound(name));

  @override
  Future<void> play(String name) async =>
      transcript.add(TranscriptLine.sound(_named(name)));

  @override
  Future<void> playMusic(String name) async =>
      transcript.add(TranscriptLine.music(_named(name)));

  @override
  Future<void> stopMusic() async => transcript.add(TranscriptLine.musicStopped);

  @override
  void volumeChanged() => transcript.add(TranscriptLine.volume(volume));
}

/// The `Http` object of a test (D125): answers from [stubs], and records
/// each request in [transcript].
class _ScriptedHttp extends HttpComponent {
  _ScriptedHttp(this.stubs, this.transcript);

  final List<HttpStub> stubs;
  final List<String> transcript;

  @override
  Future<HttpReply> send(HttpRequest request, Duration timeout) async {
    transcript.add(TranscriptLine.http(request));
    final stub = stubs
        .where((s) => s.method == request.method && s.url == request.url)
        .firstOrNull;
    if (stub == null) {
      throw const HttpFailure('no server answers in this test');
    }
    if (stub.failure != null) throw HttpFailure(stub.failure!);
    return HttpReply(stub.status, stub.headers, utf8.encode(stub.body));
  }
}

/// The `WebSocket` control of a test (D136), on [sockets].
class ScriptedWebSocket extends WebSocketComponent {
  ScriptedWebSocket(super.name, this.sockets);

  final ScriptedWebSockets sockets;

  @override
  Future<WebSocketLink> open(String url, WebSocketListener listener) =>
      sockets.open(url, listener);
}

/// The `Room` control of a test (D136), on [rooms]; the IDE's own relay
/// server stands for an empty Server, and a lost connection is tried again
/// at once.
class ScriptedRoom extends RoomComponent {
  ScriptedRoom(super.name, this.rooms)
      : super(defaultServer: 'ws://127.0.0.1:7071/room');

  final ScriptedRooms rooms;

  @override
  Future<WebSocketLink> open(String url, WebSocketListener listener) =>
      rooms.open(url, listener);

  @override
  Future<void> pause(Duration d) async {}
}

/// A [FormHost] for tests: properties start as in the form files, dialogs
/// stay open until the script closes them, and everything the program
/// shows is recorded ([TranscriptLine]):
///
///     Debug.Print: <text>
///     MsgBox: <prompt>        (or "MsgBox [<title>]: <prompt>")
///     InputBox: <prompt>      (or "InputBox [<title>]: <prompt>")
///     Set <control>.<property>: <value>
///     Settings: <the settings as SaveSetting left them>
///
/// A program with several forms (D88) names the form in `Set` lines
/// (`Set Form2.txtName.Text: Kim`) and records each change of the forms
/// shown (`Forms: Form1 > Form2 (dialog)`).
///
/// The program's settings start as [settings] (a test's NAME.settings),
/// as if an earlier run had saved them.
class ScriptedHost implements FormHost, FileHost, ComponentHost, DatabaseFiles {
  /// A host for a program with one form.
  ScriptedHost(FormFile form,
      {String? settings,
      Map<String, List<int>> disk = const {},
      List<HttpStub> http = const [],
      List<WebSocketStub> webSockets = const [],
      Map<String, PictureMask> masks = const {},
      List<String> sounds = const [],
      DatabaseComponent? database})
      : this.forms([form],
            settings: settings,
            disk: disk,
            masks: masks,
            sounds: sounds,
            http: http,
            webSockets: webSockets,
            database: database);

  /// A host for a program with [forms] (D88). [disk] holds the files it
  /// can read (D113), by name: a test's NAME.files folder; [http] what
  /// servers answer it (D125): a test's NAME.http; [database] its
  /// `Database` (D126), on a real SQLite where the test runs, or none.
  ScriptedHost.forms(List<FormFile> forms,
      {this.settings,
      Map<String, List<int>> disk = const {},
      this.http = const [],
      List<WebSocketStub> webSockets = const [],
      this.masks = const {},
      this.sounds = const [],
      this.database})
      : _webSocketStubs = webSockets,
        _files = {for (final f in forms) f.name.toLowerCase(): f},
        disk = Map.of(disk),
        _several = forms.length > 1 {
    for (final f in forms) {
      _start(f);
    }
    // Database.Export and Import use the same files (D130).
    database?.files = this;
  }

  @override
  Future<List<int>> read(String path) => readFile(path);

  @override
  Future<void> write(String path, List<int> bytes) async =>
      disk[path] = List.of(bytes);

  final Map<String, FormFile> _files;
  final bool _several;

  /// What servers answer the program's requests (D125).
  final List<HttpStub> http;

  /// The program's `Database` (D126), or null where the test has none.
  final DatabaseComponent? database;

  final List<WebSocketStub> _webSocketStubs;

  /// The WebSocket servers the program talks to (D136): a test's NAME.ws.
  late final webSockets = ScriptedWebSockets(_webSocketStubs, transcript);

  /// The relay server the program's Rooms talk to (D136), in memory.
  late final rooms = ScriptedRooms(transcript);

  @override
  ComponentInstance? createComponent(String component, {String name = ''}) =>
      switch (component) {
        'Http' => _ScriptedHttp(http, transcript),
        'Sound' => _ScriptedSound(sounds, transcript),
        'Database' => database,
        'WebSocket' => ScriptedWebSocket(name, webSockets),
        'Room' => ScriptedRoom(name, rooms),
        _ => null,
      };

  /// The files the program reads and writes, by path (D113).
  final Map<String, List<int>> disk;

  @override
  Future<String?> chooseOpenFile(
          String title, List<FileFilter> filters, String fileName) =>
      _fileDialog('OpenFileDialog', title);

  @override
  Future<String?> chooseSaveFile(
          String title, List<FileFilter> filters, String fileName) =>
      _fileDialog('SaveFileDialog', title);

  Future<String?> _fileDialog(String component, String title) async {
    transcript.add(TranscriptLine.fileDialog(component, title));
    final d = _Dialog(false, isFile: true);
    _dialogs.add(d);
    return (await d.answer.future) as String?;
  }

  /// Chooses the file [name] in the open file dialog, or cancels it when
  /// null; false when none is open.
  bool pick(String? name) {
    if (_dialogs.isEmpty || !_dialogs.last.isFile) return false;
    _dialogs.removeLast().answer.complete(name);
    return true;
  }

  @override
  Future<List<int>> readFile(String path) async =>
      disk[path] ?? (throw const FileProblem(FileProblemKind.notFound));

  @override
  Future<void> writeFile(String path, List<int> bytes,
      {bool append = false}) async {
    disk[path] = [if (append) ...?disk[path], ...bytes];
    transcript.add(TranscriptLine.wroteFile(path, bytes, append: append));
  }

  @override
  Future<bool> fileExists(String path) async => disk.containsKey(path);

  /// The PDF file is told by what is in it; no font is laid out here.
  @override
  Future<void> writePdf(String path, GbPdfDocument document) async {
    disk[path] = const [0x25, 0x50, 0x44, 0x46]; // %PDF
    transcript.add(TranscriptLine.wrotePdf(path, document));
  }

  /// Gives [form]'s properties the values of its form file.
  void _start(FormFile form) {
    final name = form.name;
    for (final p in form.component.properties.values) {
      _properties[_key(name, null, p.name)] = form.valueOf(p.name);
    }
    for (final c in form.controls) {
      _components[_key(name, c.name, '')] = c.component.name;
      if (c.container case final frame?) {
        _containers[_key(name, c.name, '')] = frame;
      }
      for (final p in c.component.properties.values.where((p) => p.isStored)) {
        _properties[_key(name, c.name, p.name)] = c.valueOf(p.name);
      }
      if (c.component.properties.values.any((p) => p.anchor)) {
        _rebase(name, c.name);
      }
    }
  }

  /// For each control with an Anchor: where it was, and the form's size
  /// then, last set in the form file or by the program (D57).
  final _bases = <String, (AnchorRect, int, int)>{};

  static const _placing = {'left', 'top', 'width', 'height', 'anchor'};

  int _int(String form, String? control, String property) =>
      _properties[_key(form, control, property)] as int;

  void _rebase(String form, String control) {
    _bases[_key(form, control, '')] = (
      (
        left: _int(form, control, 'Left'),
        top: _int(form, control, 'Top'),
        width: _int(form, control, 'Width'),
        height: _int(form, control, 'Height'),
      ),
      _int(form, _containers[_key(form, control, '')], 'Width'),
      _int(form, _containers[_key(form, control, '')], 'Height'),
    );
  }

  /// Moves [form]'s controls as their Anchor says, for its size now.
  void _place(String form) {
    final prefix = '${form.toLowerCase()}.';
    for (final MapEntry(key: key, value: (base, width, height))
        in _bases.entries) {
      if (!key.startsWith(prefix)) continue;
      final control = key.substring(prefix.length, key.length - 1);
      // Anchored to the edges of its Frame, if it is in one (D105).
      final outer = _containers[key];
      final r = anchoredRect(
        base,
        _properties[_key(form, control, 'Anchor')] as String,
        baseWidth: width,
        baseHeight: height,
        width: _int(form, outer, 'Width'),
        height: _int(form, outer, 'Height'),
      );
      _properties[_key(form, control, 'Left')] = r.left;
      _properties[_key(form, control, 'Top')] = r.top;
      _properties[_key(form, control, 'Width')] = r.width;
      _properties[_key(form, control, 'Height')] = r.height;
    }
  }

  /// The user makes the inside of the form in front [width] x [height].
  /// False when it already was that size, so that nothing happens.
  bool resize(int width, int height) {
    final form = front;
    if (_int(form, null, 'Width') == width &&
        _int(form, null, 'Height') == height) {
      return false;
    }
    _properties[_key(form, null, 'Width')] = width;
    _properties[_key(form, null, 'Height')] = height;
    _place(form);
    return true;
  }

  final _components = <String, String>{};

  /// The Frame each control in one is in, by the control's key (D105).
  final _containers = <String, String>{};

  /// The component of [control] of [form], or of the form in front
  /// (`CheckBox`); null if there is none.
  String? componentOf(String control, {String? form}) =>
      _components[_key(form ?? front, control, '')];

  final transcript = <String>[];

  /// The program's saved settings: what [saveSettings] was given last.
  String? settings;
  final _properties = <String, Object>{};
  final _dialogs = <_Dialog>[];

  /// The forms shown, from the back to the front.
  var forms = const <ShownForm>[];

  /// Whether a form has been shown.
  bool get shown => forms.isNotEmpty;

  /// The form in front, which takes what the user does.
  String get front =>
      forms.isEmpty ? _files.values.first.name : forms.last.name;

  static String _key(String form, String? control, String property) =>
      '${form.toLowerCase()}.${(control ?? 'form').toLowerCase()}.'
      '${property.toLowerCase()}';

  bool get hasOpenDialog => _dialogs.isNotEmpty;

  @override
  void debugPrint(String line) =>
      transcript.add(TranscriptLine.debugPrint(line));

  @override
  Future<void> msgBox(String prompt, String title) {
    transcript.add(TranscriptLine.msgBox(prompt, title));
    final d = _Dialog(false);
    _dialogs.add(d);
    return d.answer.future;
  }

  @override
  Future<String> inputBox(
      String prompt, String title, String defaultValue) async {
    transcript.add(TranscriptLine.inputBox(prompt, title));
    final d = _Dialog(true);
    _dialogs.add(d);
    return (await d.answer.future) as String;
  }

  @override
  Future<String?> popupMenu(String form, String menu) async {
    transcript.add(TranscriptLine.popupMenu(menu));
    final d = _Dialog(false, isPopup: true);
    _dialogs.add(d);
    return (await d.answer.future) as String?;
  }

  /// Chooses [item] in the open popup menu, or none when it is null; false
  /// when no popup menu is open. An item that cannot be chosen there (not
  /// in that menu, a line, or one that is not Enabled or not Visible) is
  /// a mistake in the script.
  bool choose(String? item) {
    if (_dialogs.isEmpty || !_dialogs.last.isPopup) return false;
    if (item != null) {
      final form = front;
      if (_properties[_key(form, item, 'Enabled')] != true ||
          _properties[_key(form, item, 'Visible')] != true ||
          _properties[_key(form, item, 'Caption')] == '-') {
        throw StateError('$item cannot be chosen');
      }
    }
    _dialogs.removeLast().answer.complete(item);
    return true;
  }

  /// The masks of the project's pictures for pixel collisions (D138), by
  /// picture key: a test's NAME.masks.
  final Map<String, PictureMask> masks;

  /// The names of the project's sounds (D138): a test's NAME.sounds.
  final List<String> sounds;

  @override
  PictureMask? pictureMask(String name) => masks[pictureKey(name)];

  @override
  Future<void> loadPictureMask(String name) async {}

  /// The host's clock, which the script's `Wait` moves (D138).
  var clock = 0;

  @override
  int get milliseconds => clock;

  @override
  Future<void> yieldNow() => Future<void>.delayed(Duration.zero);

  @override
  Object getProperty(String form, String? control, String property) =>
      _properties[_key(form, control, property)]!;

  /// A property of the form in front.
  Object frontProperty(String? control, String property) =>
      getProperty(front, control, property);

  @override
  void setProperty(
      String form, String? control, String property, Object value) {
    _properties[_key(form, control, property)] = value;
    transcript.add(TranscriptLine.setProperty(control, property, value,
        form: _several ? form : null));
    final lower = property.toLowerCase();
    if (control == null && (lower == 'width' || lower == 'height')) {
      _place(form);
    } else if (control != null &&
        _placing.contains(lower) &&
        _bases.containsKey(_key(form, control, ''))) {
      _rebase(form, control);
      // A Frame's new size moves the controls in it (D105).
      if (lower == 'width' || lower == 'height') _place(form);
    }
  }

  @override
  Future<String?> loadSettings() async => settings;

  @override
  Future<void> saveSettings(String text) async {
    settings = text;
    transcript.add(TranscriptLine.saveSettings(text));
  }

  @override
  void showForms(List<ShownForm> forms) {
    this.forms = List.unmodifiable(forms);
    if (_several) transcript.add(TranscriptLine.forms(forms));
  }

  @override
  void resetForm(String form) {
    final prefix = '${form.toLowerCase()}.';
    for (final map in [_properties, _components, _bases, _containers]) {
      map.removeWhere((key, _) => key.startsWith(prefix));
    }
    _start(_files[form.toLowerCase()]!);
  }

  @override
  void addControl(String form, String control, String component,
      Map<String, Object> properties) {
    _components[_key(form, control, '')] = component;
    for (final MapEntry(:key, :value) in properties.entries) {
      _properties[_key(form, control, key)] = value;
    }
    if (properties.containsKey('Anchor')) _rebase(form, control);
    transcript.add(TranscriptLine.addControl(control, component,
        form: _several ? form : null));
  }

  @override
  void removeControl(String form, String control) {
    final prefix = '${form.toLowerCase()}.${control.toLowerCase()}.';
    for (final map in [_properties, _components, _bases, _containers]) {
      map.removeWhere((key, _) => key.startsWith(prefix));
    }
    transcript.add(
        TranscriptLine.removeControl(control, form: _several ? form : null));
  }

  @override
  void endProgram() {
    for (final d in _dialogs.reversed) {
      d.answer.complete(d.isInputBox ? '' : null);
    }
    _dialogs.clear();
  }

  /// The control of the form in front drawn on top at ([x], [y]) on the
  /// form, as the run window's pointer finds it (D41, D111, D139); null for
  /// the form itself. Each control seen and Enabled takes the pointer over
  /// its whole box, one in a Frame only inside the Frame; the others let
  /// it through to what is under them.
  String? controlAt(num x, num y) => _controlAt(front, null, x, y);

  String? _controlAt(String form, String? frame, num x, num y) {
    final prefix = '${form.toLowerCase()}.';
    final layers = ComponentLayer.values;
    final here = <(String, int, int, int)>[];
    for (final MapEntry(:key, :value) in _components.entries) {
      final spec = builtinComponents[value.toLowerCase()];
      if (!key.startsWith(prefix) ||
          spec == null ||
          !spec.visual ||
          _containers[key]?.toLowerCase() != frame?.toLowerCase()) {
        continue;
      }
      final name = key.substring(prefix.length, key.length - 1);
      final order = _properties[_key(form, name, 'DrawOrder')] as int? ?? 0;
      here.add((name, layers.indexOf(spec.layer), order, here.length));
    }
    // From the top down: the last layer, the highest DrawOrder, the last.
    here.sort((a, b) => a.$2 != b.$2
        ? b.$2.compareTo(a.$2)
        : a.$3 != b.$3
            ? b.$3.compareTo(a.$3)
            : b.$4.compareTo(a.$4));
    for (final (name, _, _, _) in here) {
      if (_properties[_key(form, name, 'Visible')] != true ||
          _properties[_key(form, name, 'Enabled')] != true) {
        continue;
      }
      final left = _int(form, name, 'Left'), top = _int(form, name, 'Top');
      if (x < left ||
          y < top ||
          x >= left + _int(form, name, 'Width') ||
          y >= top + _int(form, name, 'Height')) {
        continue;
      }
      final spec =
          builtinComponents[_components[_key(form, name, '')]!.toLowerCase()]!;
      return (spec.container
              ? _controlAt(form, name, x - left, y - top)
              : null) ??
          name;
    }
    return null;
  }

  /// Where [control] of the form in front is on the form: its top left
  /// corner, through the Frames it is in (D105); (0, 0) for the form.
  (int, int) originOf(String? control) {
    var (x, y) = (0, 0);
    for (var c = control; c != null; c = _containers[_key(front, c, '')]) {
      x += _int(front, c, 'Left');
      y += _int(front, c, 'Top');
    }
    return (x, y);
  }

  /// Whether [control] of the form in front, or a control in it, is on top
  /// at its middle, so that a click there reaches it (D139).
  bool reachable(String control) {
    final (x, y) = originOf(control);
    var at = controlAt(x + _int(front, control, 'Width') / 2,
        y + _int(front, control, 'Height') / 2);
    while (at != null && at.toLowerCase() != control.toLowerCase()) {
      at = _containers[_key(front, at, '')];
    }
    return at != null;
  }

  /// Whether [control] of the form in front is seen and Enabled, and the
  /// Frames it is in too (D137).
  bool usable(String control) {
    for (String? c = control; c != null; c = _containers[_key(front, c, '')]) {
      if (_properties[_key(front, c, 'Enabled')] != true ||
          _properties[_key(front, c, 'Visible')] != true) {
        return false;
      }
    }
    return true;
  }

  /// Whether menu item [control] of the form in front can be chosen in the
  /// menu bar: it and the menus it is in are Enabled and Visible (D106). A menu with items, or a
  /// line, is never chosen itself: a script that does is wrong.
  bool menuEnabled(String control) {
    final form = front;
    final lower = control.toLowerCase();
    final prefix = '${form.toLowerCase()}.';
    if (_containers.entries.any(
        (e) => e.key.startsWith(prefix) && e.value.toLowerCase() == lower)) {
      throw StateError('$control opens a menu: choose one of its items');
    }
    if (_properties[_key(form, control, 'Caption')] == '-') {
      throw StateError('$control is a line between menu items');
    }
    for (String? c = control; c != null;) {
      if (_properties[_key(form, c, 'Enabled')] != true ||
          _properties[_key(form, c, 'Visible')] != true) {
        return false;
      }
      c = _containers[_key(form, c, '')];
    }
    return true;
  }

  /// The user checks OptionButton [control] of the form in front: the
  /// others of its form, or of its Frame, are unchecked (D104, D105).
  void checkOption(String control) {
    final prefix = '${front.toLowerCase()}.';
    final frame = _containers[_key(front, control, '')]?.toLowerCase();
    for (final MapEntry(:key, :value) in _components.entries) {
      if (value != 'OptionButton' ||
          !key.startsWith(prefix) ||
          _containers[key]?.toLowerCase() != frame) {
        continue;
      }
      _properties['${key}checked'] = false;
    }
    userSets(control, 'Checked', true);
  }

  /// The user changes a property of the form in front (the text of a
  /// TextBox, a CheckBox's Checked).
  void userSets(String control, String property, Object value) =>
      _properties[_key(front, control, property)] = value;

  /// Closes the topmost dialog; false if it is not of that kind.
  bool answer({required bool inputBox, Object? value}) {
    if (_dialogs.isEmpty ||
        _dialogs.last.isPopup ||
        _dialogs.last.isFile ||
        _dialogs.last.isInputBox != inputBox) {
      return false;
    }
    _dialogs.removeLast().answer.complete(value);
    return true;
  }
}

/// What an event script needs from whatever runs the program: [ScriptedHost]
/// here, or the IDE's run window with its real widgets. [driveEventScript]
/// takes the steps and writes the transcript the same way for both.
abstract interface class ScriptDriver {
  /// What the program showed so far ([TranscriptLine]).
  List<String> get transcript;

  /// How the run ended; null while it runs.
  RunResult? get result;

  /// Whether the program waits for the user: a dialog is open, or the form
  /// is shown and no handler runs (see [Interpreter.isWaitingForUser]).
  bool get waitsForUser;

  /// Lets the program go on a little: a timer tick, or a frame.
  Future<void> tick();

  /// The user causes [event] of [control] (null: the form) of [form], or
  /// of the form in front when it is null (D88). `Click` on a CheckBox
  /// changes its Checked first, unless the program would ignore the
  /// Changed that follows.
  Future<EventOutcome> raise(String? control, String event, {String? form});

  /// The user changes the text of TextBox [control] to [value]. Null when
  /// it already was [value], so that nothing happens.
  Future<EventOutcome?> type(String control, String value);

  /// The user picks item [index] of ListBox [control]. Null when it was
  /// already chosen, so that nothing happens.
  Future<EventOutcome?> select(String control, int index);

  /// The user presses or lets go a key (D101), as [step] says.
  Future<EventOutcome> key(KeyStep step);

  /// The user presses or lets go a mouse button (D111), as [step] says.
  Future<EventOutcome> mouse(MouseStep step);

  /// The user chooses a Grid's cell, or changes it (D116), as [step]
  /// says. Null when the text was already that, so that nothing happens.
  Future<EventOutcome?> grid(GridStep step);

  /// Closes the open MsgBox; false if there is none.
  Future<bool> ok();

  /// Closes the open InputBox with [value], or cancels it when [value] is
  /// null; false if there is none.
  Future<bool> answer(String? value);

  /// Chooses [item] in the open popup menu, or none when it is null
  /// (D106); false when no popup menu is open.
  Future<bool> choose(String? item);

  /// Chooses the file [name] in the open file dialog, or cancels it when
  /// null (D113); false when none is open.
  Future<bool> pick(String? name);

  /// The user closes the form; false when an open dialog blocks it.
  Future<bool> close();

  /// The user makes the inside of the form [width] x [height]: the
  /// controls move as their Anchor says, then Form_Resize runs. Null when
  /// it already was that size, so that nothing happens.
  Future<EventOutcome?> resize(int width, int height);

  /// [milliseconds] pass on the host's clock (D138).
  Future<void> wait(int milliseconds);

  /// The test's WebSocket server does [action] (D136); false when no
  /// connection is open.
  Future<bool> server(ServerAction action);

  /// Someone else on the test's relay server does [action] (D136); false
  /// when it cannot.
  Future<bool> peer(PeerAction action);

  /// The test's relay server does [verb] (`Close`, `Drop`); false when
  /// there is nothing to do it to.
  Future<bool> relay(String verb, String argument);

  /// Closes the form if it is still open, and waits for the run to end.
  Future<RunResult> finish();
}

/// Runs a project's [forms] and [modules], the first form or [startup]
/// first, or `Sub Main` when [startsWithMain] (D88, D102), and drives them
/// with [script] on a [ScriptedHost]. See [driveEventScript] for the
/// transcript.
Future<List<String>> runProjectScript(List<FormSource> forms, String script,
    {String? startup,
    String? settings,
    List<String> pictures = const [],
    Map<String, PictureMask> masks = const {},
    List<String> sounds = const [],
    List<ModuleSource> modules = const [],
    bool startsWithMain = false,
    Map<String, List<int>> disk = const {},
    List<HttpStub> http = const [],
    List<WebSocketStub> webSockets = const [],
    DatabaseComponent? database}) async {
  final steps = parseEventScript(script);
  final project = compileProject(forms,
      startup: startup,
      pictures: pictures,
      sounds: sounds,
      modules: modules,
      startsWithMain: startsWithMain);
  if (project.hasErrors) {
    return [
      for (final (file, program) in [
        for (final f in project.forms) (f.codeFile, f.program),
        for (final m in project.modules) (m.codeFile, m.program),
      ])
        for (final d in program.diagnostics)
          if (d.isError) 'Not started: ${d.code.code} @ $file:${d.line}',
      if (startsWithMain && project.main == null) 'Not started: F019',
    ];
  }
  final host = ScriptedHost.forms([for (final f in forms) f.file],
      settings: settings,
      disk: disk,
      masks: masks,
      sounds: sounds,
      http: http,
      webSockets: webSockets,
      database: database);
  return driveEventScript(
      steps, _HostDriver(Interpreter.project(project, host), host),
      namesFile: forms.length > 1 || modules.isNotEmpty);
}

/// Runs [source] with [form] and drives it with [script] (an event
/// script) on a [ScriptedHost]. See [driveEventScript] for the transcript.
///
/// [pictures] are the project's pictures (a test's NAME.pictures).
Future<List<String>> runEventScript(String source, FormFile form, String script,
    {String? settings,
    List<String> pictures = const [],
    Map<String, PictureMask> masks = const {},
    List<String> sounds = const [],
    Map<String, List<int>> disk = const {},
    List<HttpStub> http = const [],
    List<WebSocketStub> webSockets = const [],
    DatabaseComponent? database}) async {
  final steps = parseEventScript(script);
  final program =
      compile(source, form: form, pictures: pictures, sounds: sounds);
  if (program.hasErrors) {
    return [
      for (final d in program.diagnostics)
        if (d.isError) 'Not started: ${d.code.code} @ ${d.line}'
    ];
  }
  final host = ScriptedHost(form,
      settings: settings,
      disk: disk,
      masks: masks,
      sounds: sounds,
      http: http,
      webSockets: webSockets,
      database: database);
  return driveEventScript(steps, _HostDriver(Interpreter(program, host), host));
}

/// Drives a running program with [steps]. Returns the transcript: each step
/// echoed as `> step`, what the program showed, and a last line saying how
/// it ended:
///
///     Closed | Ended | Stopped | Error <code> @ <line>
///
/// A step runs only when the program waits for the user, so the transcript
/// is the same on every platform.
///
/// [namesFile]: a program with several forms names the file an error is
/// in, `Error R0xx @ Form2.gbas:3` (D88).
Future<List<String>> driveEventScript(
    List<ScriptStep> steps, ScriptDriver driver,
    {bool namesFile = false}) async {
  // Waits until the program waits for the user. Each check comes after a
  // tick, so that everything the last step started (a closed dialog lets
  // its handler go on) has run as far as it can.
  Future<void> settle() async {
    for (var i = 0; i < 1000000; i++) {
      await driver.tick();
      if (driver.result != null || driver.waitsForUser) return;
    }
    throw StateError('the program never waits for the user');
  }

  final out = driver.transcript;
  for (final step in steps) {
    await settle();
    if (driver.result != null) {
      out.add('Script not finished: ${step.text} was not run');
      break;
    }
    out.add('> ${step.text}');
    switch (step) {
      case EventStep(:final control, :final event, :final form):
        _record(out, step.text, await driver.raise(control, event, form: form));
      case TypeStep(:final control, :final value):
        final outcome = await driver.type(control, value);
        if (outcome != null) _record(out, step.text, outcome);
      case SelectStep(:final control, :final index):
        final outcome = await driver.select(control, index);
        if (outcome != null) _record(out, step.text, outcome);
      case OkStep():
        if (!await driver.ok()) {
          throw StateError('"OK" but no MsgBox is open');
        }
      case AnswerStep(:final value):
        if (!await driver.answer(value) &&
            !(value == null && await driver.pick(null))) {
          throw StateError('"${step.text}" but no InputBox is open');
        }
      case PickStep(:final name):
        if (!await driver.pick(name)) {
          throw StateError('"${step.text}" but no file dialog is open');
        }
      case ChooseStep(:final item):
        if (!await driver.choose(item)) {
          throw StateError('"${step.text}" but no popup menu is open');
        }
      case CloseStep():
        if (!await driver.close()) out.add('Blocked: ${step.text}');
      case ResizeStep(:final width, :final height):
        final outcome = await driver.resize(width, height);
        if (outcome != null) _record(out, step.text, outcome);
      case WaitStep(:final milliseconds):
        await driver.wait(milliseconds);
      case KeyStep():
        _record(out, step.text, await driver.key(step));
      case MouseStep():
        _record(out, step.text, await driver.mouse(step));
      case GridStep():
        final outcome = await driver.grid(step);
        if (outcome != null) _record(out, step.text, outcome);
      case ServerStep(:final action):
        if (!await driver.server(action)) {
          throw StateError('"${step.text}" but no WebSocket is open');
        }
      case PeerStep(:final action):
        if (!await driver.peer(action)) {
          throw StateError('"${step.text}" cannot be done now');
        }
      case RoomStep(:final verb, :final argument):
        if (!await driver.relay(verb, argument)) {
          throw StateError('"${step.text}" but there is no room');
        }
    }
  }
  await settle();
  if (driver.result == null) out.add('Still open');
  out.add(switch (await driver.finish()) {
    RunCompleted() => 'Closed',
    RunEnded() => 'Ended',
    RunStopped() => 'Stopped',
    RunFailed(:final error, :final file) => file == null || !namesFile
        ? 'Error ${error.code.code} @ ${error.line}'
        : 'Error ${error.code.code} @ $file:${error.line}',
    RunNotStarted(:final reason) => 'Not started: ${reason.name}',
  });
  return out;
}

/// Drives a [ScriptedHost]: the user's actions go straight to the
/// interpreter.
class _HostDriver implements ScriptDriver {
  _HostDriver(this.interpreter, this.host) {
    _run = interpreter.run().then((r) => result = r);
  }

  final Interpreter interpreter;
  final ScriptedHost host;
  late final Future<RunResult> _run;

  @override
  RunResult? result;

  @override
  List<String> get transcript => host.transcript;

  @override
  bool get waitsForUser =>
      host.hasOpenDialog || (host.shown && interpreter.isWaitingForUser);

  @override
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  @override
  Future<EventOutcome> raise(String? control, String event,
      {String? form}) async {
    if (control != null &&
        event == 'Tick' &&
        host.componentOf(control, form: form) == 'Timer') {
      // A Timer's tick, as its clock would make it (D100).
      return interpreter.raiseTick(control, form: form ?? host.front);
    }
    if (form != null && form.toLowerCase() != host.front.toLowerCase()) {
      return EventOutcome.blocked;
    }
    if (control != null &&
        event == 'Click' &&
        builtinComponents[host.componentOf(control)?.toLowerCase()]?.visual ==
            true &&
        !host.hasOpenDialog &&
        host.usable(control) &&
        !host.reachable(control)) {
      // Another control is drawn over its middle, where the run window's
      // click goes (D139).
      return EventOutcome.blocked;
    }
    if (control != null &&
        event == 'Click' &&
        host.componentOf(control) != 'Menu' &&
        !host.hasOpenDialog) {
      // A click is a left button pressed and let go in its middle, as the
      // run window's widgets make it (D111).
      final mouse = GbMouseEvent(
          mouseButtons['Left']!,
          (host.frontProperty(control, 'Width') as int) ~/ 2,
          (host.frontProperty(control, 'Height') as int) ~/ 2);
      interpreter
        ..raiseMouse(control, 'MouseDown', mouse)
        ..raiseMouse(control, 'MouseUp', mouse);
    }
    if (control != null &&
        event == 'Click' &&
        host.componentOf(control) == 'OptionButton') {
      // Checks it and unchecks the others; Changed only when it was not
      // checked (D104).
      if (host.frontProperty(control, 'Checked') == true) {
        return EventOutcome.noHandler;
      }
      if (interpreter.refusal(control, 'Changed') case final refused?) {
        return refused;
      }
      host.checkOption(control);
      return interpreter.raiseEvent(control, 'Changed');
    }
    if (control != null &&
        event == 'Click' &&
        host.componentOf(control) == 'Menu') {
      // A menu item chosen (D106): not one that is greyed, nor one in a
      // greyed menu.
      if (!host.menuEnabled(control)) return EventOutcome.disabled;
    }
    if (control != null &&
        event == 'Click' &&
        host.componentOf(control) == 'CheckBox') {
      // A click the program would ignore leaves the box as it was (D44).
      if (interpreter.refusal(control, 'Changed') case final refused?) {
        return refused;
      }
      final checked = host.frontProperty(control, 'Checked') as bool;
      host.userSets(control, 'Checked', !checked);
      return interpreter.raiseEvent(control, 'Changed');
    }
    return interpreter.raiseEvent(control, event);
  }

  @override
  Future<EventOutcome?> type(String control, String value) async {
    if (host.hasOpenDialog) return EventOutcome.blocked;
    if (host.frontProperty(control, 'Text') == value) return null;
    host.userSets(control, 'Text', value);
    return interpreter.raiseEvent(control, 'Changed');
  }

  @override
  Future<EventOutcome?> select(String control, int index) async {
    final items = host.frontProperty(control, 'Items') as List<String>;
    if (index >= items.length) {
      throw StateError('$control has no item $index');
    }
    if (host.hasOpenDialog) return EventOutcome.blocked;
    if (host.frontProperty(control, 'ListIndex') == index) return null;
    // A pick the program would ignore leaves the choice as it was.
    if (interpreter.refusal(control, 'Changed') case final refused?) {
      return refused;
    }
    host.userSets(control, 'ListIndex', index);
    return interpreter.raiseEvent(control, 'Changed');
  }

  @override
  Future<EventOutcome> key(KeyStep step) async => interpreter.raiseKey(
      step.event,
      GbKeyEvent(keyCodes[step.key]!,
          shift: step.shift, control: step.ctrl, alt: step.alt),
      inTextBox: step.control != null);

  @override
  Future<bool> ok() async => host.answer(inputBox: false);

  @override
  Future<bool> answer(String? value) async =>
      host.answer(inputBox: true, value: value ?? '');

  /// The control each MouseDown step landed on, by the step's control:
  /// its MouseUp goes there, as the run window's pointer does (D111).
  final _pressed = <String?, String?>{};

  /// A mouse button pressed at a place on a control, or the form: the
  /// control drawn on top there takes it (D139), and its MouseUp.
  @override
  Future<EventOutcome> mouse(MouseStep step) async {
    if (host.hasOpenDialog) return EventOutcome.blocked;
    final (x, y) = host.originOf(step.control);
    final (px, py) = (x + step.x, y + step.y);
    final String? target;
    if (step.event == 'MouseDown') {
      target = _pressed[step.control?.toLowerCase()] = host.controlAt(px, py);
    } else {
      final key = step.control?.toLowerCase();
      target = _pressed.containsKey(key) ? _pressed.remove(key) : step.control;
    }
    final (tx, ty) = host.originOf(target);
    return interpreter.raiseMouse(target, step.event,
        GbMouseEvent(mouseButtons[step.button]!, px - tx, py - ty));
  }

  @override
  Future<EventOutcome?> grid(GridStep step) async {
    if (host.hasOpenDialog) return EventOutcome.blocked;
    final c = step.control;
    final headers = host.frontProperty(c, 'Headers') as List;
    final cells = List<String>.of(
        (host.frontProperty(c, 'Cells') as List).cast<String>());
    final i = step.row * headers.length + step.col;
    if (step.col >= headers.length || i >= cells.length) {
      throw StateError('$c has no cell ${step.row} ${step.col}');
    }
    final chosen = host.frontProperty(c, 'Row') == step.row &&
        host.frontProperty(c, 'Col') == step.col;
    if (step.value == null) {
      // A second click on the chosen cell edits it, and runs nothing.
      if (chosen) return null;
      if (interpreter.refusal(c, 'Click') case final refused?) return refused;
      host
        ..userSets(c, 'Row', step.row)
        ..userSets(c, 'Col', step.col);
      return interpreter.raiseEvent(c, 'Click');
    }
    // The user edits the cell chosen, as a second click on it does.
    if (!chosen) {
      throw StateError('choose $c\'s cell ${step.row} ${step.col} before '
          'editing it');
    }
    if (host.frontProperty(c, 'ReadOnly') == true) {
      return EventOutcome.disabled;
    }
    if (cells[i] == step.value) return null;
    if (interpreter.refusal(c, 'Changed') case final refused?) return refused;
    cells[i] = step.value!;
    host
      ..userSets(c, 'Row', step.row)
      ..userSets(c, 'Col', step.col)
      ..userSets(c, 'Cells', List<String>.unmodifiable(cells));
    return interpreter.raiseEvent(c, 'Changed');
  }

  @override
  Future<bool> choose(String? item) async => host.choose(item);

  @override
  Future<bool> pick(String? name) async => host.pick(name);

  @override
  Future<bool> close() async {
    if (host.hasOpenDialog) return false;
    interpreter.closeForm();
    return true;
  }

  @override
  Future<EventOutcome?> resize(int width, int height) async {
    if (host.hasOpenDialog) return EventOutcome.blocked;
    if (!host.resize(width, height)) return null;
    return interpreter.raiseEvent(null, 'Resize');
  }

  @override
  Future<void> wait(int milliseconds) async => host.clock += milliseconds;

  @override
  Future<bool> server(ServerAction action) async =>
      host.webSockets.serverDoes(action);

  @override
  Future<bool> peer(PeerAction action) async => host.rooms.peerDoes(action);

  @override
  Future<bool> relay(String verb, String argument) async =>
      host.rooms.serverDoes(verb, argument);

  @override
  Future<RunResult> finish() {
    if (result == null) interpreter.closeForm();
    return _run;
  }
}

void _record(List<String> out, String step, EventOutcome outcome) {
  switch (outcome) {
    case EventOutcome.ignored:
      out.add('Ignored: $step');
    case EventOutcome.blocked:
      out.add('Blocked: $step');
    case EventOutcome.disabled:
      out.add('Disabled: $step');
    case EventOutcome.started ||
          EventOutcome.noHandler ||
          EventOutcome.notRunning:
      break;
  }
}
