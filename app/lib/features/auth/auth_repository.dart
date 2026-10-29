import 'package:mock_data/mock_data.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_exception.dart';
import 'auth_models.dart';

abstract interface class AuthRepository {
  Future<Session> signIn(String email, String password);
  Future<Session> signUp({required String name, required String email, required String password});
  Future<void> requestPasswordReset(String email);
  Future<bool> isEmailAvailable(String email);

  /// Validates a stored token. Throws [ApiException] `unauthorized` when the
  /// server rejects it, or `network` when the server can't be reached.
  Future<AppUser> me(String token);
}

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._api);

  final ApiClient _api;

  Map<String, Object?> _map(Object? data) => (data! as Map).cast<String, Object?>();

  @override
  Future<Session> signIn(String email, String password) async =>
      Session.fromJson(_map(await _api.post('/auth/sign-in', body: {'email': email.trim(), 'password': password})));

  @override
  Future<Session> signUp({required String name, required String email, required String password}) async =>
      Session.fromJson(_map(await _api.post('/auth/sign-up', body: {'name': name.trim(), 'email': email.trim(), 'password': password})));

  @override
  Future<void> requestPasswordReset(String email) => _api.post('/auth/forgot-password', body: {'email': email.trim()});

  @override
  Future<bool> isEmailAvailable(String email) async =>
      _map(await _api.get('/auth/email-available', query: {'email': email.trim()}))['available'] == true;

  /// Short timeout: the app waits on its splash for this answer, and a
  /// network that never answers counts as offline (the cached session stays).
  @override
  Future<AppUser> me(String token) async =>
      AppUser.fromJson(_map(await _api.get('/me', bearer: token).timeout(meTimeout, onTimeout: () => throw const ApiException('network'))));

  static const meTimeout = Duration(seconds: 5);
}

/// Offline fake over the shared [MockDatabase], used when the mock server is
/// not running and in tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._db, {this.latency = const Duration(milliseconds: 300)});

  final MockDatabase _db;
  final Duration latency;

  Future<T> _run<T>(T Function() body) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    try {
      return body();
    } on MockError catch (e) {
      throw ApiException(e.code, status: e.status, fields: e.fields);
    }
  }

  @override
  Future<Session> signIn(String email, String password) => _run(() => Session.fromJson(_db.signIn(email.trim(), password)));

  @override
  Future<Session> signUp({required String name, required String email, required String password}) =>
      _run(() => Session.fromJson(_db.signUp(name: name, email: email.trim(), password: password)));

  @override
  Future<void> requestPasswordReset(String email) => _run(() {});

  @override
  Future<bool> isEmailAvailable(String email) => _run(() => _db.isEmailAvailable(email.trim()));

  @override
  Future<AppUser> me(String token) => _run(() => AppUser.fromJson(_db.authenticate(token)));
}
