/// HTTP layer over [MockDatabase]: REST + JSON under `/api`, CORS for the web
/// build, and per-request latency/failure injection for testing loading,
/// error and offline states.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show stderr;

import 'package:mock_data/mock_data.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Builds the request handler. [database] is a factory so `POST /api/admin/reset`
/// can restore the fixtures between test runs. [allowedOrigins]: web origins
/// besides this machine's (`localhost`, `127.0.0.1`, `[::1]`, any port) that
/// may call the API from a browser.
Handler buildHandler({
  MockDatabase Function()? database,
  Duration defaultDelay = const Duration(milliseconds: 300),
  Set<String> allowedOrigins = const {},
}) {
  final create = database ?? MockDatabase.new;
  var db = create();
  final api = Router();

  Response json(Object? body, {int status = 200}) =>
      Response(status, body: jsonEncode(body), headers: {'content-type': 'application/json; charset=utf-8'});

  Future<Map<String, Object?>> readBody(Request r) async {
    final text = await r.readAsString();
    if (text.isEmpty) return {};
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) throw MockError(400, 'badJson');
    return decoded;
  }

  String? bearer(Request r) {
    final h = r.headers['authorization'];
    return h != null && h.startsWith('Bearer ') ? h.substring(7) : null;
  }

  void requireAuth(Request r) => db.authenticate(bearer(r));

  /// An integer query parameter, [fallback] when absent; anything else is a 400.
  int intParam(Map<String, String> q, String name, int fallback) {
    final raw = q[name];
    if (raw == null || raw.isEmpty) return fallback;
    return int.tryParse(raw) ?? (throw MockError(400, 'badPage'));
  }

  DateTime? dateParam(Map<String, String> q, String name) {
    final raw = q[name];
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw) ?? (throw MockError(400, 'badDate'));
  }

  api
    ..get('/health', (Request r) => json({'ok': true}))
    ..post('/admin/reset', (Request r) {
      db = create();
      return json({'ok': true});
    })
    // ---- Auth ----
    ..post('/auth/sign-in', (Request r) async {
      final b = await readBody(r);
      return json(db.signIn('${b['email'] ?? ''}', '${b['password'] ?? ''}'));
    })
    ..post('/auth/sign-up', (Request r) async {
      final b = await readBody(r);
      return json(db.signUp(name: '${b['name'] ?? ''}', email: '${b['email'] ?? ''}', password: '${b['password'] ?? ''}'), status: 201);
    })
    ..get('/auth/email-available', (Request r) => json({'available': db.isEmailAvailable(r.url.queryParameters['email'] ?? '')}))
    // Always 202 so the response never reveals whether an account exists.
    ..post('/auth/forgot-password', (Request r) => json({'ok': true}, status: 202))
    ..get('/me', (Request r) => json(db.authenticate(bearer(r))))
    // ---- Inspections ----
    ..get('/inspections', (Request r) {
      requireAuth(r);
      final q = r.url.queryParameters;
      final status = q['status']?.split(',').where((s) => s.isNotEmpty).toSet();
      return json(
        db.listInspections(
          status: status,
          q: q['q'],
          sort: q['sort'] ?? 'dueAsc',
          due: q['due'] ?? 'any',
          from: dateParam(q, 'from'),
          to: dateParam(q, 'to'),
          page: intParam(q, 'page', 1),
          pageSize: intParam(q, 'pageSize', 20),
        ),
      );
    })
    ..post('/inspections', (Request r) async {
      requireAuth(r);
      final submit = r.url.queryParameters['submit'] == 'true';
      return json(db.createInspection(await readBody(r), submit: submit, requestKey: r.headers['idempotency-key']), status: 201);
    })
    ..get('/inspections/<id>', (Request r, String id) {
      requireAuth(r);
      return json(db.getInspection(id));
    })
    ..put('/inspections/<id>', (Request r, String id) async {
      requireAuth(r);
      final submit = r.url.queryParameters['submit'] == 'true';
      return json(db.updateInspection(id, await readBody(r), submit: submit));
    })
    ..post('/inspections/<id>/archive', (Request r, String id) {
      requireAuth(r);
      db.setArchived(id, true);
      return json({'ok': true});
    })
    ..post('/inspections/<id>/unarchive', (Request r, String id) {
      requireAuth(r);
      db.setArchived(id, false);
      return json({'ok': true});
    })
    // ---- Lookups ----
    ..get('/sites', (Request r) {
      requireAuth(r);
      return json(db.searchSites(r.url.queryParameters['q'] ?? ''));
    })
    ..get('/inspection-types', (Request r) => json(inspectionTypes))
    ..get('/checklist-templates/<id>', (Request r, String id) {
      requireAuth(r);
      return json(db.checklistTemplate(id));
    })
    ..get('/notifications', (Request r) {
      requireAuth(r);
      return json(db.notifications());
    })
    ..post('/notifications/read', (Request r) async {
      requireAuth(r);
      final id = switch ((await readBody(r))['id']) {
        null => null,
        final String s => s,
        _ => throw MockError(422, 'validation', fields: {'id': 'invalid'}),
      };
      db.markNotificationsRead(id: id);
      return json({'ok': true});
    })
    ..delete('/notifications/<id>', (Request r, String id) {
      requireAuth(r);
      db.deleteNotification(id);
      return json({'ok': true});
    });

  final root = Router()
    ..mount('/api/', api.call)
    ..get('/', (Request r) => Response.ok('Field Inspections mock API. See /api/health.'));

  // CORS outermost, so every response carries its headers, errors included
  // (a browser reports a response without them as a network failure).
  return const Pipeline()
      .addMiddleware(_cors(allowedOrigins))
      .addMiddleware(_errors())
      .addMiddleware(_faults(defaultDelay))
      .addHandler(root.call);
}

/// Longest latency `?delay` / `X-Mock-Delay` may ask for.
const maxDelay = Duration(seconds: 30);

Response _jsonError(int status, Map<String, Object?> body) =>
    Response(status, body: jsonEncode(body), headers: {'content-type': 'application/json; charset=utf-8'});

const _corsHeaders = {
  'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'access-control-allow-headers': 'authorization, content-type, idempotency-key, x-mock-delay, x-mock-fail',
  'access-control-max-age': '600',
};

/// A web page on this machine (the web app, Playwright), on any port.
bool _isLocalOrigin(String origin) {
  final host = Uri.tryParse(origin)?.host;
  return host == 'localhost' || host == '127.0.0.1' || host == '::1' || (host?.endsWith('.localhost') ?? false);
}

/// Browsers send `Origin` with cross-origin calls. Only this machine's pages
/// (and [allowed]) may use the API; any other site's call is refused before
/// it runs, so a page open in the developer's browser can't read the data or
/// reset the server. Apps and tools send no `Origin` and aren't affected.
Middleware _cors(Set<String> allowed) =>
    (inner) => (request) async {
      final origin = request.headers['origin'];
      if (origin != null && !_isLocalOrigin(origin) && !allowed.contains(origin)) {
        return _jsonError(403, {'error': 'originNotAllowed'});
      }
      final headers = {..._corsHeaders, 'access-control-allow-origin': origin ?? '*', if (origin != null) 'vary': 'origin'};
      if (request.method == 'OPTIONS') return Response(204, headers: headers);
      final response = await inner(request);
      return response.change(headers: headers);
    };

/// `?delay=<ms>` or `X-Mock-Delay` overrides latency (0 to [maxDelay]);
/// `?fail=<status>` or `X-Mock-Fail` forces an error response (400–599, e.g.
/// 500, 503).
Middleware _faults(Duration defaultDelay) =>
    (inner) => (request) async {
      final q = request.url.queryParameters;
      final delayMs = int.tryParse(q['delay'] ?? request.headers['x-mock-delay'] ?? '');
      final delay = delayMs != null ? Duration(milliseconds: delayMs.clamp(0, maxDelay.inMilliseconds)) : defaultDelay;
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      final fail = int.tryParse(q['fail'] ?? request.headers['x-mock-fail'] ?? '');
      if (fail != null && fail >= 400 && fail <= 599) return _jsonError(fail, {'error': 'injected'});
      return inner(request);
    };

/// Maps every failure to a JSON error: [MockError] to its status, bad JSON to
/// 400, anything else (a bug, or a body the backend didn't expect) to 500.
Middleware _errors() =>
    (inner) => (request) async {
      try {
        return await inner(request);
      } on HijackException {
        rethrow;
      } on MockError catch (e) {
        return _jsonError(e.status, e.toJson());
      } on FormatException {
        return _jsonError(400, {'error': 'badJson'});
      } catch (e, stack) {
        stderr.writeln('[mock] ${request.method} ${request.requestedUri}: $e\n$stack');
        return _jsonError(500, {'error': 'server'});
      }
    };
