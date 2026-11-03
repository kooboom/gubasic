import 'dart:convert';

import '../diagnostics/diagnostic.dart';
import '../interpreter/checked_math.dart';
import '../interpreter/host.dart';
import '../interpreter/values.dart';
import '../text/json.dart';
import '../text/text_codec.dart';

/// One HTTP request as the `Http` object sends it (docs/DESIGN.md D125):
/// what the program asked for, with the headers it set and the ones the
/// method adds.
class HttpRequest {
  const HttpRequest(this.method, this.url, this.headers, this.body);

  /// `GET`, `POST`, … in capitals.
  final String method;
  final String url;

  /// By name as the program wrote it, in the order set.
  final Map<String, String> headers;

  /// The body as UTF-8, or null for none.
  final List<int>? body;

  /// The body as text, for transcripts.
  String get bodyText => body == null ? '' : utf8.decode(body!);
}

/// What came back.
class HttpReply {
  const HttpReply(this.status, this.headers, this.bytes);

  final int status;

  /// By lower-case name.
  final Map<String, String> headers;
  final List<int> bytes;
}

/// Why a request got no answer: the detail goes into R036.
class HttpFailure implements Exception {
  const HttpFailure(this.detail);

  final String detail;
}

/// The `Http` object (D124, D125), a component through the component
/// channel: everything but the sending, which [send] does where the
/// program runs (the player with package:http, the tests from a script).
///
/// `Get`, `Post`, `GetJson` and `PostJson` give the answer's text or JSON
/// and stop the program for a status from 400 (R037); `Send` gives the
/// whole answer whatever its status, and takes headers for that one
/// request after the body, each `Name: value` (D135). No answer is R036;
/// an answer that is not JSON R039; a header not written `Name: value`
/// R046. The answer's text is read as its `Content-Type`
/// charset says: UTF-8 when it names none, code page 949 for `euc-kr`
/// and its other names, Latin-1 for `iso-8859-1`.
abstract class HttpComponent implements ComponentInstance {
  /// Seconds to wait for an answer: `Timeout`, 30 at first.
  int timeout = 30;

  /// The headers sent with every request, by name as written.
  final headers = <String, String>{};

  /// Sends [request] and gives its reply, within [timeout] seconds; throws
  /// an [HttpFailure] when none comes.
  Future<HttpReply> send(HttpRequest request, Duration timeout);

  @override
  Object? getProperty(String name) => GbInt.of(timeout);

  @override
  void setProperty(String name, Object? value) {
    timeout = (value as GbInt).toSmallInt()!;
  }

  @override
  void assign(String name, List<Object?> args, Object? value) {
    final header = args[0] as String;
    headers.removeWhere((k, _) => k.toLowerCase() == header.toLowerCase());
    if ((value as String).isNotEmpty) headers[header] = value;
  }

  @override
  Future<Object?> call(String name, List<Object?> args) async {
    switch (name) {
      case 'Get':
        return _text(await _request('GET', args[0] as String));
      case 'Post':
        return _text(await _request('POST', args[0] as String,
            body: args[1] as String, type: 'text/plain; charset=utf-8'));
      case 'GetJson':
        return GbJson(
            _json(await _request('GET', args[0] as String, accept: _jsonType)));
      case 'PostJson':
        return GbJson(_json(await _request('POST', args[0] as String,
            body: (args[1] as GbJson?)?.json ?? 'null',
            type: '$_jsonType; charset=utf-8',
            accept: _jsonType)));
      case 'Send':
        final body = args[2] as String;
        final (reply, text) = await _send(
            (args[0] as String).toUpperCase(), args[1] as String,
            body: body.isEmpty ? null : body,
            type: body.isEmpty ? null : 'text/plain; charset=utf-8',
            once: [for (final h in args.skip(3)) _requestHeader(h as String)]);
        return GbHttpResponse(reply.status, reply.headers, text);
      case 'Header':
        final header = (args[0] as String).toLowerCase();
        return headers.entries
                .where((e) => e.key.toLowerCase() == header)
                .map((e) => e.value)
                .firstOrNull ??
            '';
    }
    throw StateError('no code for Http.$name');
  }

  static const _jsonType = 'application/json';

  /// A header for one request, written `Name: value` (D135); anything
  /// else is R046.
  static MapEntry<String, String> _requestHeader(String text) {
    final colon = text.indexOf(':');
    final name = colon < 0 ? '' : text.substring(0, colon).trim();
    if (name.isEmpty || name.contains(RegExp(r'\s'))) {
      throw ComponentProblem(DiagnosticCode.httpHeaderForm, [text]);
    }
    return MapEntry(name, text.substring(colon + 1).trim());
  }

  /// Sends and checks the status: from 400, R037 with the start of the
  /// answer.
  Future<(HttpReply, String)> _request(String method, String url,
      {String? body, String? type, String? accept}) async {
    final result =
        await _send(method, url, body: body, type: type, accept: accept);
    final (reply, text) = result;
    if (reply.status >= 400) {
      final line = text.trim().split(RegExp(r'\r?\n')).first;
      throw ComponentProblem(DiagnosticCode.httpStatus, [
        '${reply.status}',
        url,
        line.length > 80 ? '${line.substring(0, 80)}…' : line,
      ]);
    }
    return result;
  }

  /// Sends [method] [url] with the program's headers, [once] the headers
  /// for this request alone, each in place of a kept one of its name
  /// (D135), [type] as the Content-Type and [accept] as Accept unless the
  /// program set them, and gives the reply with its text; no answer is
  /// R036.
  Future<(HttpReply, String)> _send(String method, String url,
      {String? body,
      String? type,
      String? accept,
      List<MapEntry<String, String>> once = const []}) async {
    final sent = <String, String>{...headers};
    for (final MapEntry(:key, :value) in once) {
      sent.removeWhere((k, _) => k.toLowerCase() == key.toLowerCase());
      sent[key] = value;
    }
    bool has(String name) =>
        sent.keys.any((k) => k.toLowerCase() == name.toLowerCase());
    if (type != null && !has('Content-Type')) sent['Content-Type'] = type;
    if (accept != null && !has('Accept')) sent['Accept'] = accept;
    final request =
        HttpRequest(method, url, sent, body == null ? null : utf8.encode(body));
    final HttpReply reply;
    try {
      reply = await send(request, Duration(seconds: timeout));
    } on HttpFailure catch (f) {
      throw ComponentProblem(DiagnosticCode.httpFailed, [url, f.detail]);
    }
    return (reply, decodeHttpText(reply.bytes, reply.headers['content-type']));
  }

  static String _text((HttpReply, String) result) => result.$2;

  static Object? _json((HttpReply, String) result) {
    try {
      return parseJson(result.$2);
    } on FormatException catch (e) {
      throw ComponentProblem(DiagnosticCode.jsonInvalid, [e.message]);
    }
  }
}

/// Whether a header named [name] looks like one that carries a secret
/// (D135, A076): `Authorization`, `Proxy-Authorization`, `Cookie`, or a
/// name with key, token, secret, password or auth in it, whatever the
/// case.
bool looksLikeSecretHeader(String name) {
  final lower = name.trim().toLowerCase();
  return const {'authorization', 'proxy-authorization', 'cookie'}
          .contains(lower) ||
      const ['key', 'token', 'secret', 'password', 'passwd', 'auth']
          .any(lower.contains);
}

/// An answer's [bytes] as text, by the charset its [contentType] names:
/// UTF-8 when it names none (a byte order mark dropped), code page 949
/// for `euc-kr`, `ks_c_5601-1987`, `cp949` and `windows-949`, Latin-1 for
/// `iso-8859-1` and `us-ascii`; anything else is read as UTF-8.
String decodeHttpText(List<int> bytes, String? contentType) {
  final charset = RegExp(r'charset\s*=\s*"?([^";\s]+)', caseSensitive: false)
          .firstMatch(contentType ?? '')
          ?.group(1)
          ?.toLowerCase() ??
      'utf-8';
  switch (charset) {
    case 'euc-kr' ||
          'ks_c_5601-1987' ||
          'cp949' ||
          'windows-949' ||
          'x-windows-949' ||
          'ms949':
      return decodeCp949(bytes);
    case 'iso-8859-1' || 'latin1' || 'latin-1' || 'us-ascii' || 'ascii':
      return latin1.decode(bytes);
    default:
      var start = 0;
      if (bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF) {
        start = 3;
      }
      return utf8.decode(bytes.sublist(start), allowMalformed: true);
  }
}
