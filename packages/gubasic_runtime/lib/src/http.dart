import 'dart:async';

import 'package:http/http.dart' as http;

/// One request the `Http` object sends (docs/DESIGN.md D125): its method,
/// address, headers and body.
typedef GbHttpRequest = ({
  String method,
  String url,
  Map<String, String> headers,
  List<int>? body,
});

/// What came back: the status, the headers by lower-case name, the bytes.
class GbHttpReply {
  const GbHttpReply(this.status, this.headers, this.bytes);

  final int status;
  final Map<String, String> headers;
  final List<int> bytes;
}

/// Why no answer came: a bad address, no connection, no answer in time;
/// [detail] is what the system said, for R036.
class GbHttpError implements Exception {
  const GbHttpError(this.detail);

  final String detail;
}

/// Sends HTTP requests for a running program (D125): package:http, which
/// uses `dart:io` on the desktop and the browser's own requests on the
/// web, where the server must allow the page (CORS). Tests give a fake.
abstract class GbHttp {
  factory GbHttp() => _ClientHttp();

  /// Sends [request] and gives its reply within [timeout]; throws a
  /// [GbHttpError] when none comes.
  Future<GbHttpReply> send(GbHttpRequest request, Duration timeout);
}

class _ClientHttp implements GbHttp {
  http.Client? _client;

  @override
  Future<GbHttpReply> send(GbHttpRequest request, Duration timeout) async {
    final Uri url;
    try {
      url = Uri.parse(request.url);
      if (!url.hasScheme || url.host.isEmpty) {
        throw const FormatException('not a web address');
      }
    } on FormatException {
      throw const GbHttpError('not a web address');
    }
    final client = _client ??= http.Client();
    final sent = http.Request(request.method, url)
      ..headers.addAll(request.headers);
    if (request.body != null) sent.bodyBytes = request.body!;
    try {
      final streamed = await client.send(sent).timeout(timeout);
      final reply = await http.Response.fromStream(streamed).timeout(timeout);
      return GbHttpReply(reply.statusCode, {
        for (final MapEntry(:key, :value) in reply.headers.entries)
          key.toLowerCase(): value,
      }, reply.bodyBytes);
    } on TimeoutException {
      throw GbHttpError('no answer in ${timeout.inSeconds} seconds');
    } on http.ClientException catch (e) {
      throw GbHttpError(e.message);
    } catch (e) {
      // dart:io's SocketException and the like.
      throw GbHttpError('$e'.replaceFirst(RegExp(r'^\w+Exception: '), ''));
    }
  }
}
