import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';
import '../../data/api/api_exception.dart';
import '../../data/providers.dart';
import 'auth_models.dart';

/// Holds the session. Starts in [AuthStatus.restoring] while the stored token
/// is checked, so a cold-start deep link waits on the splash route instead of
/// bouncing to sign-in.
class AuthController extends Notifier<AuthState> {
  static const _key = 'session';

  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthState.restoring();
  }

  Future<void> _restore() async {
    final raw = ref.read(keyValueStoreProvider).getString(_key);
    if (raw == null) {
      state = const AuthState.signedOut();
      return;
    }
    final Session saved;
    try {
      saved = Session.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      await ref.read(keyValueStoreProvider).remove(_key);
      state = const AuthState.signedOut();
      return;
    }
    try {
      final user = await ref.read(authRepositoryProvider).me(saved.token);
      if (!ref.mounted) return;
      state = AuthState.signedIn(Session(token: saved.token, user: user));
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      // Offline-first: a network failure keeps the cached session.
      if (e.code == 'network') {
        state = AuthState.signedIn(saved);
      } else {
        await ref.read(keyValueStoreProvider).remove(_key);
        state = const AuthState.signedOut();
      }
    }
  }

  /// With [remember] off ("Keep me signed in" unchecked) the session lives
  /// only in memory and ends when the app or tab closes.
  Future<void> signIn(String email, String password, {bool remember = true}) async =>
      _save(await ref.read(authRepositoryProvider).signIn(email, password), persist: remember);

  Future<void> signUp({required String name, required String email, required String password}) async =>
      _save(await ref.read(authRepositoryProvider).signUp(name: name, email: email, password: password));

  Future<void> _save(Session session, {bool persist = true}) async {
    final store = ref.read(keyValueStoreProvider);
    if (persist) {
      await store.setString(_key, jsonEncode(session.toJson()));
    } else {
      await store.remove(_key);
    }
    if (!ref.mounted) return;
    state = AuthState.signedIn(session);
  }

  Future<void> signOut() async {
    await ref.read(keyValueStoreProvider).remove(_key);
    state = const AuthState.signedOut();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
