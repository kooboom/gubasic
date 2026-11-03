import 'dart:convert';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// The Http object apart from the sending (docs/DESIGN.md D125): the
/// headers it adds, the status check, the charsets, Timeout and Header.
class _Http extends HttpComponent {
  final sent = <HttpRequest>[];
  HttpReply reply = HttpReply(200, {}, []);
  Duration? lastTimeout;
  HttpFailure? failure;

  @override
  Future<HttpReply> send(HttpRequest request, Duration timeout) async {
    sent.add(request);
    lastTimeout = timeout;
    if (failure != null) throw failure!;
    return reply;
  }
}

void main() {
  test('Timeout and Header are kept; "" takes a header away', () async {
    final h = _Http();
    expect(h.getProperty('Timeout'), GbInt.of(30));
    h.setProperty('Timeout', GbInt.of(7));
    h.assign('Header', ['Accept'], 'text/csv');
    h.assign('Header', ['X-Key'], 'k');
    expect(await h.call('Header', ['accept']), 'text/csv');
    expect(await h.call('Header', ['other']), '');
    h.assign('Header', ['ACCEPT'], '');
    expect(await h.call('Header', ['Accept']), '');
    h.reply = HttpReply(200, {}, utf8.encode('ok'));
    expect(await h.call('Get', ['http://x/']), 'ok');
    expect(h.lastTimeout, const Duration(seconds: 7));
    expect(h.sent.single.headers, {'X-Key': 'k'});
  });

  test('each method adds its headers unless the program set them', () async {
    final h = _Http()..reply = HttpReply(200, {}, utf8.encode('{"a":1}'));
    await h.call('GetJson', ['http://x/']);
    expect(h.sent.last.headers, {'Accept': 'application/json'});
    await h.call('Post', ['http://x/', 'body']);
    expect(h.sent.last.headers, {'Content-Type': 'text/plain; charset=utf-8'});
    expect(h.sent.last.bodyText, 'body');
    final j = await h.call('PostJson', [
      'http://x/',
      GbJson({'k': 'v'})
    ]);
    expect((j as GbJson).value, {'a': 1});
    expect(h.sent.last.headers, {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    });
    expect(h.sent.last.bodyText, '{"k":"v"}');
    h.assign('Header', ['content-type'], 'application/x-www-form-urlencoded');
    await h.call('Post', ['http://x/', 'a=1']);
    expect(h.sent.last.headers,
        {'content-type': 'application/x-www-form-urlencoded'});
    await h.call('Send', ['put', 'http://x/', '']);
    expect(h.sent.last.method, 'PUT');
    expect(h.sent.last.body, isNull);
  });

  test('Send takes headers for that request alone (D135)', () async {
    final h = _Http()..reply = HttpReply(200, {}, utf8.encode('ok'));
    h.assign('Header', ['Accept-Language'], 'ko');
    await h.call('Send', [
      'GET',
      'http://x/',
      '',
      'Authorization: Bearer abc',
      ' accept-language :en ',
    ]);
    expect(h.sent.last.headers,
        {'Authorization': 'Bearer abc', 'accept-language': 'en'});
    // The next request has only the kept header.
    await h.call('Send', ['GET', 'http://x/', '']);
    expect(h.sent.last.headers, {'Accept-Language': 'ko'});
    expect(await h.call('Header', ['Authorization']), '');
    // A header of the request's own sets the Content-Type that Send would
    // add.
    await h.call('Send', ['POST', 'http://x/', 'a=1', 'Content-Type: x/y']);
    expect(
        h.sent.last.headers, {'Accept-Language': 'ko', 'Content-Type': 'x/y'});
    for (final bad in ['Authorization', ': v', 'Two words: v', '']) {
      await expectLater(
          h.call('Send', ['GET', 'http://x/', '', bad]),
          throwsA(isA<ComponentProblem>()
              .having((p) => p.code, 'code', DiagnosticCode.httpHeaderForm)
              .having((p) => p.args, 'args', [bad])));
    }
  });

  test('names that look like those of secrets (A076)', () {
    for (final name in [
      'Authorization',
      'AUTHORIZATION',
      'Proxy-Authorization',
      'Cookie',
      'X-API-Key',
      'Api-Key',
      'X-Auth-Token',
      'X-Secret',
      'Password',
    ]) {
      expect(looksLikeSecretHeader(name), isTrue, reason: name);
    }
    for (final name in [
      'Accept',
      'Accept-Language',
      'Content-Type',
      'User-Agent',
      'X-Requested-With',
      'If-None-Match',
    ]) {
      expect(looksLikeSecretHeader(name), isFalse, reason: name);
    }
  });

  test('a status from 400 is R037 in all but Send; no answer is R036',
      () async {
    final h = _Http()
      ..reply = HttpReply(
          404, {'content-type': 'text/plain'}, utf8.encode('Not here\nmore'));
    await expectLater(
        h.call('Get', ['http://x/a']),
        throwsA(isA<ComponentProblem>()
            .having((p) => p.code, 'code', DiagnosticCode.httpStatus)
            .having((p) => p.args, 'args', ['404', 'http://x/a', 'Not here'])));
    final r = await h.call('Send', ['GET', 'http://x/a', '']) as GbHttpResponse;
    expect([r.status, r.ok, r.text, r.headers['content-type']],
        [404, false, 'Not here\nmore', 'text/plain']);
    h.failure = const HttpFailure('timed out');
    await expectLater(
        h.call('Send', ['GET', 'http://x/a', '']),
        throwsA(isA<ComponentProblem>()
            .having((p) => p.code, 'code', DiagnosticCode.httpFailed)
            .having((p) => p.args, 'args', ['http://x/a', 'timed out'])));
    h.failure = null;
    h.reply = HttpReply(200, {}, utf8.encode('not json'));
    await expectLater(
        h.call('GetJson', ['http://x/a']),
        throwsA(isA<ComponentProblem>()
            .having((p) => p.code, 'code', DiagnosticCode.jsonInvalid)));
  });

  test('the answer is read by its charset: UTF-8 unless named', () {
    expect(decodeHttpText(utf8.encode('가'), null), '가');
    expect(decodeHttpText([0xEF, 0xBB, 0xBF, ...utf8.encode('a')], null), 'a');
    expect(decodeHttpText(utf8.encode('가'), 'application/json'), '가');
    expect(decodeHttpText(utf8.encode('가'), 'text/plain; charset=UTF-8'), '가');
    expect(decodeHttpText([0xB0, 0xA1], 'text/html; charset=euc-kr'), '가');
    expect(decodeHttpText([0xB0, 0xA1], 'text/html; charset="ks_c_5601-1987"'),
        '가');
    expect(decodeHttpText([0xE9], 'text/plain; charset=iso-8859-1'), 'é');
    expect(decodeHttpText([0xE9], null), '�');
  });
}
