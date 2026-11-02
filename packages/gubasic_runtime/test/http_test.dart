@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// Requests through package:http against a server of the test's own
/// (docs/DESIGN.md D125): the status, the headers, the body in and out, a
/// request that gets no answer in time, and an address nothing answers.
void main() {
  late HttpServer server;
  late String base;
  final seen = <HttpRequest>[];
  final bodies = <String>[];

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      seen.add(request);
      bodies.add(await utf8.decoder.bind(request).join());
      switch (request.uri.path) {
        case '/json':
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType(
              'application',
              'json',
              charset: 'utf-8',
            )
            ..headers.set('x-count', '2')
            ..write('{"name":"김하나","points":10}');
        case '/missing':
          request.response
            ..statusCode = 404
            ..headers.contentType = ContentType.text
            ..write('Not here');
        case '/slow':
          await Future<void>.delayed(const Duration(milliseconds: 400));
          request.response.write('late');
        case '/euckr':
          request.response
            ..headers.set('content-type', 'text/plain; charset=euc-kr')
            ..add([0xB0, 0xA1]); // 가 in code page 949
        default:
          request.response
            ..statusCode = 201
            ..write('echo ${request.method} ${request.headers.value('x-a')}');
      }
      await request.response.close();
    });
  });

  tearDownAll(() => server.close(force: true));

  GbHttpRequest get(String path) =>
      (method: 'GET', url: '$base$path', headers: {}, body: null);

  test('a GET: status, headers by lower-case name, bytes', () async {
    final reply = await GbHttp().send(get('/json'), const Duration(seconds: 5));
    expect(reply.status, 200);
    expect(reply.headers['x-count'], '2');
    expect(reply.headers['content-type'], 'application/json; charset=utf-8');
    expect(utf8.decode(reply.bytes), '{"name":"김하나","points":10}');
  });

  test(
    'a POST sends its headers and body; a status from 400 is given back',
    () async {
      final reply = await GbHttp().send((
        method: 'POST',
        url: '$base/echo',
        headers: {'X-A': 'b', 'Content-Type': 'text/plain; charset=utf-8'},
        body: utf8.encode('안녕'),
      ), const Duration(seconds: 5));
      expect(reply.status, 201);
      expect(utf8.decode(reply.bytes), 'echo POST b');
      expect(bodies.last, '안녕');
      final missing = await GbHttp().send(
        get('/missing'),
        const Duration(seconds: 5),
      );
      expect(missing.status, 404);
      expect(utf8.decode(missing.bytes), 'Not here');
    },
  );

  test('a charset other than UTF-8 comes through in the header', () async {
    final reply = await GbHttp().send(
      get('/euckr'),
      const Duration(seconds: 5),
    );
    expect(reply.headers['content-type'], 'text/plain; charset=euc-kr');
    expect(reply.bytes, [0xB0, 0xA1]);
  });

  test('no answer in time, and nothing at the address', () async {
    await expectLater(
      GbHttp().send(get('/slow'), const Duration(milliseconds: 100)),
      throwsA(
        isA<GbHttpError>().having(
          (e) => e.detail,
          'detail',
          'no answer in 0 seconds',
        ),
      ),
    );
    await expectLater(
      GbHttp().send((
        method: 'GET',
        url: 'http://127.0.0.1:1/x',
        headers: {},
        body: null,
      ), const Duration(seconds: 5)),
      throwsA(isA<GbHttpError>()),
    );
    await expectLater(
      GbHttp().send((
        method: 'GET',
        url: 'not a url',
        headers: {},
        body: null,
      ), const Duration(seconds: 5)),
      throwsA(
        isA<GbHttpError>().having(
          (e) => e.detail,
          'detail',
          'not a web address',
        ),
      ),
    );
  });
}
