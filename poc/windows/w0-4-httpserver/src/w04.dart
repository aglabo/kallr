// PoC-W0-4 / W6 (run: dart run src/w04.dart [--api-port 8765] [--allow http://localhost:8081])
// - API server on 127.0.0.1: POST /schedules {at,title,batch,alarm} -> W0-3 `add` (Dart FFI), GET /schedules -> `list`.
// - Origin check: only origins given by --allow are accepted. Any other / missing Origin gets 403 (the body is the recorded rejection).
// - Two static servers for the test PWA: 8081 (allowed origin) and 8082 (not allowed), to compare from a browser.
// The WinRT calls reuse ../../w0-3-dartffi/src/w03.dart (`run`), whose stdout is captured per request.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../w0-3-dartffi/src/w03.dart' as w03;

String? opt(List<String> args, String name) {
  final i = args.indexOf('--$name');
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

/// Runs a W0-3 command and captures what it writes to stdout.
({int code, String out}) callW03(List<String> args) {
  final buf = StringBuffer();
  final code = IOOverrides.runZoned(() => w03.run(args), stdout: () => _Capture(buf));
  return (code: code, out: buf.toString());
}

class _Capture implements Stdout {
  _Capture(this.b);
  final StringBuffer b;
  @override
  void write(Object? o) => b.write(o);
  @override
  void writeln([Object? o = '']) => b.writeln(o);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

Future<void> json(HttpResponse r, int status, Object body, [Map<String, String> h = const {}]) async {
  r.statusCode = status;
  r.headers.contentType = ContentType.json;
  h.forEach(r.headers.set);
  r.write(jsonEncode(body));
  await r.close();
}

void main(List<String> args) async {
  final apiPort = int.parse(opt(args, 'api-port') ?? '8765');
  final allowed = {opt(args, 'allow') ?? 'http://localhost:8081'};
  final pwaDir = Directory.fromUri(Platform.script.resolve('../pwa'));

  final api = await HttpServer.bind(InternetAddress.loopbackIPv4, apiPort);
  stdout.writeln('api: http://127.0.0.1:$apiPort  allowed origins: $allowed');
  api.listen((req) async {
    final origin = req.headers.value('origin');
    final r = req.response;
    final ok = origin != null && allowed.contains(origin);
    stdout.writeln('${req.method} ${req.uri.path} origin=$origin -> ${ok ? 'allowed' : 'REJECT'}'
        ' [pna=${req.headers.value('access-control-request-private-network')}]');
    if (!ok) {
      // No CORS headers on purpose: a browser then blocks the response, the server log / curl shows the 403 body.
      return json(r, 403, {'error': 'origin_not_allowed', 'origin': origin});
    }
    final cors = {
      'Access-Control-Allow-Origin': origin,
      'Vary': 'Origin',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'content-type',
      'Access-Control-Allow-Private-Network': 'true',
    };
    if (req.method == 'OPTIONS') {
      r.statusCode = 204;
      cors.forEach(r.headers.set);
      return r.close();
    }
    try {
      if (req.uri.path == '/schedules' && req.method == 'POST') {
        final b = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
        final res = callW03([
          'add',
          '--at', b['at'] as String,
          '--title', (b['title'] ?? 'PoC W0-4') as String,
          '--batch', (b['batch'] ?? 'B') as String,
          '--alarm', (b['alarm'] ?? 'A') as String,
        ]);
        return await json(r, res.code == 0 ? 201 : 500, {'exit': res.code, 'out': res.out.trim()}, cors);
      }
      if (req.uri.path == '/schedules' && req.method == 'GET') {
        final res = callW03(['list']);
        return await json(r, 200, {'out': res.out.trim()}, cors);
      }
      return await json(r, 404, {'error': 'not_found'}, cors);
    } catch (e) {
      return json(r, 500, {'error': '$e'}, cors);
    }
  });

  // Static servers for the test PWA (allowed: 8081, not allowed: 8082).
  for (final port in [8081, 8082]) {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    stdout.writeln('pwa: http://localhost:$port');
    s.listen((req) async {
      var p = req.uri.path == '/' ? '/index.html' : req.uri.path;
      final f = File('${pwaDir.path}$p');
      if (p.contains('..') || !await f.exists()) {
        req.response.statusCode = 404;
        return req.response.close();
      }
      req.response.headers.contentType = p.endsWith('.json')
          ? ContentType('application', 'manifest+json')
          : p.endsWith('.js')
              ? ContentType('text', 'javascript')
              : ContentType.html;
      await req.response.addStream(f.openRead());
      await req.response.close();
    });
  }
}
