import 'package:flutter/foundation.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// The `Http` object of a running program (docs/DESIGN.md D125): the
/// interpreter's [HttpComponent], sending through the runtime's [GbHttp].
/// [busy] counts the requests under way, so that the run window can show
/// the pointer as waiting meanwhile (D124 A).
class PlayerHttp extends HttpComponent {
  PlayerHttp(this._http, this.busy);

  final GbHttp _http;
  final ValueNotifier<int> busy;

  @override
  Future<HttpReply> send(HttpRequest request, Duration timeout) async {
    busy.value++;
    try {
      final reply = await _http.send((
        method: request.method,
        url: request.url,
        headers: request.headers,
        body: request.body,
      ), timeout);
      return HttpReply(reply.status, reply.headers, reply.bytes);
    } on GbHttpError catch (e) {
      throw HttpFailure(e.detail);
    } finally {
      busy.value--;
    }
  }
}
