import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/platform/capabilities.dart';
import '../../core/storage/key_value_store.dart';
import 'auth_controller.dart';
import 'auth_models.dart';

@immutable
class LockState {
  const LockState({required this.enabled, required this.locked});

  /// The "Biometric unlock" setting (P19). Always false where unsupported (web).
  final bool enabled;
  final bool locked;
}

/// Locks the app after [timeout] in the background, and on a cold start with
/// a restored session, when biometric unlock is on (iOS and Android only).
class LockController extends Notifier<LockState> {
  static const _key = 'biometric_lock';
  static const timeout = Duration(minutes: 5);

  DateTime Function() clock = DateTime.now;
  DateTime? _hiddenAt;
  AppLifecycleListener? _listener;

  @override
  LockState build() {
    final supported = ref.watch(capabilitiesProvider).biometricLock;
    final enabled = supported && ref.watch(keyValueStoreProvider).getString(_key) == 'true';
    // A cold start with a restored session locks immediately.
    ref.listen(authControllerProvider.select((s) => s.status), (previous, next) {
      if (previous == AuthStatus.restoring && next == AuthStatus.signedIn && state.enabled) {
        state = const LockState(enabled: true, locked: true);
      }
      if (next == AuthStatus.signedOut) state = LockState(enabled: state.enabled, locked: false);
    });
    _listener?.dispose();
    _listener = AppLifecycleListener(onHide: onHidden, onShow: onShown);
    ref.onDispose(() => _listener?.dispose());
    return LockState(enabled: enabled, locked: false);
  }

  @visibleForTesting
  void onHidden() => _hiddenAt = clock();

  @visibleForTesting
  void onShown() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    final signedIn = ref.read(authControllerProvider).status == AuthStatus.signedIn;
    if (state.enabled && signedIn && hiddenAt != null && clock().difference(hiddenAt) >= timeout) {
      state = const LockState(enabled: true, locked: true);
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (!ref.read(capabilitiesProvider).biometricLock) return;
    await ref.read(keyValueStoreProvider).setString(_key, '$enabled');
    state = LockState(enabled: enabled, locked: false);
  }

  /// Called after a successful biometric check (M3 wires local_auth here).
  void unlock() => state = LockState(enabled: state.enabled, locked: false);
}

final lockControllerProvider = NotifierProvider<LockController, LockState>(LockController.new);
