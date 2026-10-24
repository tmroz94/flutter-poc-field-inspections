import 'package:mock_data/mock_data.dart';

import 'auth_models.dart';

abstract interface class AuthRepository {
  Future<Session> signIn(String email, String password);
  Future<Session> signUp({required String name, required String email, required String password});
  Future<void> requestPasswordReset(String email);
  Future<bool> isEmailAvailable(String email);

  /// Validates a stored token. Throws [AuthException] `unauthorized` when the
  /// server rejects it, or `network` when the server can't be reached.
  Future<AppUser> me(String token);
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
      throw AuthException(e.code, fields: e.fields);
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
