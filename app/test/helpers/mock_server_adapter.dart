import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mock_data/mock_data.dart';
import 'package:mock_server/mock_server.dart';
import 'package:shelf/shelf.dart' as shelf;

/// Where the app's HTTP repositories point in tests; any host works.
const mockServerUrl = 'http://mock.test/api';

/// Sends dio's requests to the mock server's handler in-process: its routes,
/// token checks, JSON and query parsing, without a socket. [handler] serves
/// [MockDatabase] fixtures for [now].
class MockServerAdapter implements HttpClientAdapter {
  MockServerAdapter({required DateTime now})
    : handler = buildHandler(
        database: () => MockDatabase(clock: () => now),
        defaultDelay: Duration.zero,
      );

  final shelf.Handler handler;

  /// Every request sent, in order.
  final requests = <RequestOptions>[];

  /// `POST /api/admin/reset`: the server starts again from its fixtures, so
  /// accounts created since are gone.
  Future<void> reset() async {
    await handler(shelf.Request('POST', Uri.parse('$mockServerUrl/admin/reset')));
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final body = requestStream == null ? const <int>[] : [for (final chunk in await requestStream.toList()) ...chunk];
    final response = await handler(
      shelf.Request(options.method, options.uri, headers: {for (final e in options.headers.entries) e.key: '${e.value}'}, body: body),
    );
    final bytes = [for (final chunk in await response.read().toList()) ...chunk];
    return ResponseBody.fromBytes(bytes, response.statusCode, headers: response.headersAll);
  }

  @override
  void close({bool force = false}) {}
}
