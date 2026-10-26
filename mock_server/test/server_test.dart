import 'dart:convert';

import 'package:mock_data/mock_data.dart';
import 'package:mock_server/mock_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Handler handler;

  setUp(() => handler = buildHandler(defaultDelay: Duration.zero));

  Future<Response> call(String method, String path, {Object? body, String? token, Map<String, String> headers = const {}}) async => handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {if (token != null) 'authorization': 'Bearer $token', ...headers},
    ),
  );

  Future<dynamic> decode(Response r) async => jsonDecode(await r.readAsString());

  Future<String> signIn() async {
    final r = await call('POST', '/api/auth/sign-in', body: {'email': demoEmail, 'password': demoPassword});
    return (await decode(r))['token'] as String;
  }

  test('health is public and carries CORS headers', () async {
    final r = await call('GET', '/api/health');
    expect(r.statusCode, 200);
    expect(r.headers['access-control-allow-origin'], '*');
  });

  test('CORS preflight answers 204 with allowed headers', () async {
    final r = await call('OPTIONS', '/api/inspections');
    expect(r.statusCode, 204);
    expect(r.headers['access-control-allow-headers'], contains('authorization'));
  });

  test('inspections need a bearer token', () async {
    expect((await call('GET', '/api/inspections')).statusCode, 401);
    final r = await call('GET', '/api/inspections?status=overdue', token: await signIn());
    expect(r.statusCode, 200);
    expect((await decode(r))['total'], 1);
  });

  test('sign-in validation returns 422 with field errors', () async {
    final r = await call('POST', '/api/auth/sign-in', body: {'email': 'x', 'password': '1'});
    expect(r.statusCode, 422);
    expect((await decode(r))['fields'], {'email': 'invalid', 'password': 'tooShort'});
  });

  test('unknown inspection is 404', () async {
    final r = await call('GET', '/api/inspections/INS-9999', token: await signIn());
    expect(r.statusCode, 404);
  });

  test('failure injection by query and header', () async {
    expect((await call('GET', '/api/health?fail=503')).statusCode, 503);
    expect((await call('GET', '/api/health', headers: {'x-mock-fail': '500'})).statusCode, 500);
  });

  test('malformed JSON is a 400', () async {
    final r = await handler(Request('POST', Uri.parse('http://localhost/api/auth/sign-in'), body: '{nope'));
    expect(r.statusCode, 400);
    expect(r.headers['access-control-allow-origin'], '*');
  });

  test('a body of the wrong shape is a 422 with field errors and CORS headers', () async {
    final token = await signIn();
    final r = await call('POST', '/api/inspections', token: token, body: {'site': 5, 'answers': [], 'photos': 'x'});
    expect(r.statusCode, 422);
    expect(r.headers['access-control-allow-origin'], '*');
    expect((await decode(r))['fields'], containsPair('photos', 'invalid'));

    final read = await call('POST', '/api/notifications/read', token: token, body: {'id': 5});
    expect(read.statusCode, 422);
  });

  test('an unexpected error is a JSON 500 that still carries CORS headers', () async {
    final broken = buildHandler(database: _BrokenDatabase.new, defaultDelay: Duration.zero);
    final token = _BrokenDatabase().signIn(demoEmail, demoPassword)['token']! as String;
    final r = await broken(Request('GET', Uri.parse('http://localhost/api/notifications'), headers: {'authorization': 'Bearer $token'}));
    expect(r.statusCode, 500);
    expect(r.headers['access-control-allow-origin'], '*');
    expect(r.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(await r.readAsString()), {'error': 'server'});
  });

  test('paging parameters that are not numbers, or could overflow, are a 400', () async {
    final token = await signIn();
    for (final query in ['page=abc', 'page=9223372036854775807', 'pageSize=0', 'from=yesterday', 'status=done']) {
      final r = await call('GET', '/api/inspections?$query', token: token);
      expect(r.statusCode, 400, reason: query);
      expect(r.headers['access-control-allow-origin'], '*', reason: query);
    }
  });

  test('injected failures outside 400–599 are ignored', () async {
    expect((await call('GET', '/api/health?fail=1000')).statusCode, 200);
    expect((await call('GET', '/api/health?fail=302')).statusCode, 200);
  });

  test('create, archive, and reset restore fixtures', () async {
    final token = await signIn();
    final created = await call(
      'POST',
      '/api/inspections',
      token: token,
      body: {
        'siteId': 's-riverside-office',
        'type': 'Fire safety, annual',
        'scheduledAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'durationMin': 60,
      },
    );
    expect(created.statusCode, 201);
    expect((await call('POST', '/api/inspections/INS-1043/archive', token: token)).statusCode, 200);
    await call('POST', '/api/admin/reset');
    // The old token is gone after reset, by design.
    final fresh = await signIn();
    final list = await decode(await call('GET', '/api/inspections?q=INS-1043', token: fresh));
    expect(list['total'], 1);
  });
}

/// A backend with a bug, to check what the HTTP layer does with it.
class _BrokenDatabase extends MockDatabase {
  @override
  List<Map<String, Object?>> notifications() => throw StateError('boom');
}
