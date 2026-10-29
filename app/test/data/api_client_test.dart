import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:field_inspections/data/api/api_client.dart';
import 'package:field_inspections/data/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with a canned status/body, or fails like a dead network.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, [this.body, this.offline = false]);

  final int status;
  final Object? body;
  final bool offline;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    if (offline) throw DioException.connectionError(requestOptions: options, reason: 'offline');
    return ResponseBody.fromString(
      jsonEncode(body ?? {}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Adapter adapter;
  var unauthorized = 0;

  ApiClient client(_Adapter a, {String? token}) {
    adapter = a;
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = a;
    return ApiClient(baseUrl: 'http://api.test', token: () => token, onUnauthorized: () => unauthorized++, dio: dio);
  }

  setUp(() => unauthorized = 0);

  test('returns JSON and sends the bearer token', () async {
    final api = client(_Adapter(200, {'ok': true}), token: 'abc');
    expect(await api.get('/health'), {'ok': true});
    expect(adapter.last!.headers['Authorization'], 'Bearer abc');
  });

  test('an explicit bearer overrides the session token', () async {
    final api = client(_Adapter(200, {}), token: 'session');
    await api.get('/me', bearer: 'stored');
    expect(adapter.last!.headers['Authorization'], 'Bearer stored');
  });

  Future<ApiException> fail(_Adapter a) async {
    try {
      await client(a).post('/x');
    } on ApiException catch (e) {
      return e;
    }
    throw StateError('expected ApiException');
  }

  test('no response is a network error', () async {
    expect((await fail(_Adapter(0, null, true))).code, 'network');
  });

  test('422 carries field errors', () async {
    final e = await fail(
      _Adapter(422, {
        'error': 'validation',
        'fields': {'email': 'taken'},
      }),
    );
    expect(e.code, 'validation');
    expect(e.status, 422);
    expect(e.fields, {'email': 'taken'});
  });

  test('401 ends the session, but wrong credentials do not', () async {
    expect((await fail(_Adapter(401, {'error': 'unauthorized'}))).code, 'unauthorized');
    expect(unauthorized, 1);
    expect((await fail(_Adapter(401, {'error': 'invalidCredentials'}))).code, 'invalidCredentials');
    expect(unauthorized, 1);
  });

  test('a late 401 for an older token leaves the newer session alone', () async {
    var current = 'old';
    final a = _Adapter(401, {'error': 'unauthorized'});
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = a;
    final api = ApiClient(baseUrl: 'http://api.test', token: () => current, onUnauthorized: () => unauthorized++, dio: dio);
    final late = api.get('/inspections');
    // The user signs in again before the old request's answer arrives.
    current = 'new';
    await expectLater(late, throwsA(isA<ApiException>().having((e) => e.code, 'code', 'unauthorized')));
    expect(unauthorized, 0);
    await expectLater(api.get('/inspections'), throwsA(isA<ApiException>()));
    expect(unauthorized, 1);
  });

  test('a 401 for a token checked with bearer does not end the session', () async {
    final api = client(_Adapter(401, {'error': 'unauthorized'}), token: 'session');
    await expectLater(api.get('/me', bearer: 'stored'), throwsA(isA<ApiException>()));
    expect(unauthorized, 0);
  });

  test('404 and 5xx', () async {
    expect((await fail(_Adapter(404, {'error': 'notFound'}))).code, 'notFound');
    expect((await fail(_Adapter(503, {'error': 'injected'}))).code, 'server');
  });
}
