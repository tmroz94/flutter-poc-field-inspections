import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Thin JSON client over dio. Adds the bearer token, maps every failure to an
/// [ApiException], and reports 401s so the session can end.
class ApiClient {
  ApiClient({required String baseUrl, required this.token, this.onUnauthorized, Dio? dio})
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
          );

  final Dio _dio;
  final String? Function() token;
  final void Function()? onUnauthorized;

  /// [bearer] overrides the session token (used to validate a stored token on start-up).
  Future<Object?> get(String path, {Map<String, Object?>? query, String? bearer}) =>
      _send(() => _dio.get<Object?>(path, queryParameters: query, options: _auth(bearer)));

  Future<Object?> post(String path, {Object? body, Map<String, Object?>? query}) =>
      _send(() => _dio.post<Object?>(path, data: body, queryParameters: query, options: _auth()));

  Future<Object?> put(String path, {Object? body, Map<String, Object?>? query}) =>
      _send(() => _dio.put<Object?>(path, data: body, queryParameters: query, options: _auth()));

  Future<Object?> delete(String path) => _send(() => _dio.delete<Object?>(path, options: _auth()));

  Options _auth([String? bearer]) {
    final t = bearer ?? token();
    return Options(headers: {if (t != null) 'Authorization': 'Bearer $t'});
  }

  Future<Object?> _send(Future<Response<Object?>> Function() call) async {
    try {
      return (await call()).data;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  ApiException _map(DioException e) {
    final response = e.response;
    if (response == null) return const ApiException('network');
    final status = response.statusCode;
    final body = response.data is Map ? (response.data! as Map).cast<String, Object?>() : const <String, Object?>{};
    final fields = (body['fields'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const <String, String>{};
    final code = body['error'] as String?;
    if (status == 401 && code != 'invalidCredentials') onUnauthorized?.call();
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
