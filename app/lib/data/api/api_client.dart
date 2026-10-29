import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Thin JSON client over dio. Adds the bearer token, maps every failure to an
/// [ApiException], and reports 401s so the session can end. [adapter] replaces
/// the network transport (tests send requests to the mock server in-process).
class ApiClient {
  ApiClient({required String baseUrl, required this.token, this.onUnauthorized, Dio? dio, HttpClientAdapter? adapter})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 15),
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            ),
          ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  final Dio _dio;
  final String? Function() token;
  final void Function()? onUnauthorized;

  /// [bearer] overrides the session token (used to validate a stored token on start-up).
  Future<Object?> get(String path, {Map<String, Object?>? query, String? bearer}) => _send(
    (options) => _dio.get<Object?>(path, queryParameters: query, options: options),
    bearer: bearer,
  );

  Future<Object?> post(String path, {Object? body, Map<String, Object?>? query, Map<String, String>? headers}) => _send(
    (options) => _dio.post<Object?>(path, data: body, queryParameters: query, options: options),
    headers: headers,
  );

  Future<Object?> put(String path, {Object? body, Map<String, Object?>? query}) =>
      _send((options) => _dio.put<Object?>(path, data: body, queryParameters: query, options: options));

  Future<Object?> delete(String path) => _send((options) => _dio.delete<Object?>(path, options: options));

  Future<Object?> _send(Future<Response<Object?>> Function(Options options) call, {String? bearer, Map<String, String>? headers}) async {
    final sent = bearer ?? token();
    try {
      return (await call(Options(headers: {...?headers, if (sent != null) 'Authorization': 'Bearer $sent'}))).data;
    } on DioException catch (e) {
      // Only a 401 for the token in use now ends the session: a late answer
      // to an older one (the user signed in again meanwhile) or a token
      // checked with [bearer] leaves it alone.
      throw _map(e, endsSession: bearer == null && sent == token());
    }
  }

  ApiException _map(DioException e, {required bool endsSession}) {
    final response = e.response;
    if (response == null) return const ApiException('network');
    final status = response.statusCode;
    final body = response.data is Map ? (response.data! as Map).cast<String, Object?>() : const <String, Object?>{};
    final fields = switch (body['fields']) {
      final Map<Object?, Object?> m => m.map((k, v) => MapEntry('$k', '$v')),
      _ => const <String, String>{},
    };
    final code = switch (body['error']) {
      final String s => s,
      _ => null,
    };
    if (status == 401 && code != 'invalidCredentials' && endsSession) onUnauthorized?.call();
    return ApiException(
      switch ((status, code)) {
        (_, 'invalidCredentials') => 'invalidCredentials',
        (401, _) => 'unauthorized',
        (404, _) => 'notFound',
        (422, _) => 'validation',
        (final s?, _) when s >= 500 => 'server',
        _ => code ?? 'unknown',
      },
      status: status,
      fields: fields,
    );
  }
}
