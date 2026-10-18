{{flutter_js}}
{{flutter_build_config}}

// "Loading… 37%" while the first visit fetches the engine, the app and its
// fonts (D43). The files are counted as Flutter itself fetches them, so
// each is fetched once: fetch() is wrapped to count the bytes as they
// arrive, and main.dart.js, a <script>, counts when it has arrived. Their
// sizes come from load_sizes.json (tool/web_load_sizes.dart); without it
// the text stays as it is.
(function () {
  var loading = document.getElementById('loading');
  if (!loading) return;
  var label = loading.textContent;
  var base = document.baseURI;
  var fetchFirst = window.fetch;
  var sizes = null;
  var got = {};
  // The CanvasKit build the loader chooses is known once it asks.
  var wasm = typeof Intl.v8BreakIterator !== 'undefined'
    ? 'canvaskit/chromium/canvaskit.wasm' : 'canvaskit/canvaskit.wasm';
  function path(url) {
    var href = new URL(url, base).href;
    return href.indexOf(base) === 0 ? href.slice(base.length) : null;
  }
  function show() {
    if (!sizes || !loading.isConnected) return;
    var sum = 0, total = 0;
    for (var p in sizes) {
      if (p.slice(-5) === '.wasm' && p !== wasm) continue;
      total += sizes[p];
      sum += Math.min(got[p] || 0, sizes[p]);
    }
    var percent = Math.min(99, Math.floor(100 * sum / total));
    loading.textContent = label + ' ' + percent + '%';
  }
  // Wrapped at once, before the loader starts: the engine is asked for
  // before load_sizes.json has come.
  window.fetch = function (input, init) {
    var p = path(typeof input === 'string' || input instanceof URL ? input : input.url);
    return fetchFirst.call(this, input, init).then(function (response) {
      if (p === null || !/\.(wasm|otf|ttf)$/.test(p) || !response.body) return response;
      if (p.slice(-5) === '.wasm') wasm = p;
      got[p] = 0;
      // Read as the bytes arrive, not when Flutter asks for them: it may
      // read a font only after the others have come.
      var reader = response.body.getReader();
      var counted = new ReadableStream({
        start: function (controller) {
          function next() {
            return reader.read().then(function (part) {
              if (part.done) { controller.close(); return; }
              got[p] += part.value.byteLength;
              show();
              controller.enqueue(part.value);
              return next();
            }, function (why) { controller.error(why); });
          }
          next();
        },
        cancel: function (why) { return reader.cancel(why); },
      });
      return new Response(counted, {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers,
      });
    });
  };
  new PerformanceObserver(function (list) {
    list.getEntries().forEach(function (entry) {
      if (path(entry.name) === 'main.dart.js') { got['main.dart.js'] = Infinity; show(); }
    });
  }).observe({ type: 'resource', buffered: true });
  window.addEventListener('flutter-first-frame', function () {
    window.fetch = fetchFirst;
  });
  fetchFirst(new URL('load_sizes.json', base))
    .then(function (r) { return r.ok ? r.json() : null; })
    .catch(function () { return null; })
    .then(function (s) { sizes = s; show(); });
})();

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
