import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';
import '../../data/api/api_exception.dart';
import '../../data/local/local_data.dart';
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
      await _activate(Session(token: saved.token, user: user));
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      // Only a rejected token ends the session. Offline-first: no network, a
      // server error or any other failure keeps the cached one.
      if (e.code == 'unauthorized') {
        await ref.read(keyValueStoreProvider).remove(_key);
        state = const AuthState.signedOut();
      } else {
        debugPrint('Session check failed: ${e.code}');
        await _activate(saved);
      }
    } on Object catch (e) {
      // An answer that isn't the API's (e.g. a captive portal's HTML page):
      // treat it like no network rather than staying on the splash.
      debugPrint('Session check failed: $e');
      if (ref.mounted) await _activate(saved);
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
    await _activate(session);
  }

  /// Hands this device's local data to the session's user, then starts the session.
  Future<void> _activate(Session session) async {
    await ref.read(localDataProvider).claimFor(session.user.id);
    if (ref.mounted) state = AuthState.signedIn(session);
  }

  /// [clearLocalData]: the user chose to sign out (Settings), so this device's
  /// drafts, outbox, photos and reminders go too. Without it (a rejected
  /// token, "Use password instead" on the lock screen) they stay for the same
  /// user's next sign-in.
  Future<void> signOut({bool clearLocalData = false}) async {
    if (clearLocalData) {
      try {
        await ref.read(localDataProvider).clear();
      } on Object catch (e) {
        // Still sign out; the owner check clears it before another account uses it.
        debugPrint('Sign-out: could not clear local data: $e');
      }
    }
    await ref.read(keyValueStoreProvider).remove(_key);
    state = const AuthState.signedOut();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
