/// HTTP layer over [MockDatabase]: REST + JSON under `/api`, CORS for the web
/// build, and per-request latency/failure injection for testing loading,
/// error and offline states.
library;

import 'dart:async';
import 'dart:convert';

import 'package:mock_data/mock_data.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Builds the request handler. [database] is a factory so `POST /api/admin/reset`
/// can restore the fixtures between test runs.
Handler buildHandler({MockDatabase Function()? database, Duration defaultDelay = const Duration(milliseconds: 300)}) {
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
          from: DateTime.tryParse(q['from'] ?? ''),
          to: DateTime.tryParse(q['to'] ?? ''),
          page: int.tryParse(q['page'] ?? '') ?? 1,
          pageSize: int.tryParse(q['pageSize'] ?? '') ?? 20,
        ),
      );
    })
    ..post('/inspections', (Request r) async {
      requireAuth(r);
      final submit = r.url.queryParameters['submit'] == 'true';
      return json(db.createInspection(await readBody(r), submit: submit), status: 201);
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
      db.markNotificationsRead(id: (await readBody(r))['id'] as String?);
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

  return const Pipeline().addMiddleware(_cors()).addMiddleware(_faults(defaultDelay)).addMiddleware(_errors()).addHandler(root.call);
}

const _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'access-control-allow-headers': 'authorization, content-type, x-mock-delay, x-mock-fail',
  'access-control-max-age': '600',
};

Middleware _cors() =>
    (inner) => (request) async {
      if (request.method == 'OPTIONS') return Response(204, headers: _corsHeaders);
      final response = await inner(request);
      return response.change(headers: _corsHeaders);
    };

/// `?delay=<ms>` or `X-Mock-Delay` overrides latency; `?fail=<status>` or
/// `X-Mock-Fail` forces an error response (e.g. 500, 503).
Middleware _faults(Duration defaultDelay) =>
    (inner) => (request) async {
      final q = request.url.queryParameters;
      final delayMs = int.tryParse(q['delay'] ?? request.headers['x-mock-delay'] ?? '');
      final delay = delayMs != null ? Duration(milliseconds: delayMs) : defaultDelay;
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      final fail = int.tryParse(q['fail'] ?? request.headers['x-mock-fail'] ?? '');
      if (fail != null && fail >= 400) {
        return Response(fail, body: jsonEncode({'error': 'injected'}), headers: {'content-type': 'application/json'});
      }
      return inner(request);
    };

Middleware _errors() =>
    (inner) => (request) async {
      try {
        return await inner(request);
      } on MockError catch (e) {
        return Response(e.status, body: jsonEncode(e.toJson()), headers: {'content-type': 'application/json'});
      } on FormatException {
        return Response(400, body: jsonEncode({'error': 'badJson'}), headers: {'content-type': 'application/json'});
      }
    };
