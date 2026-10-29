import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';
import '../../features/notifications/reminders.dart';
import 'local_store.dart';

/// Drafts, the outbox, stored photos and scheduled reminders belong to the
/// account that made them. They're deleted when that user signs out from
/// Settings, or when a different account signs in on this device (after a
/// rejected token ended the session), so one user's queue is never sent
/// under another user's account.
class LocalData {
  LocalData(this._ref);

  final Ref _ref;
  static const _ownerKey = 'local_data_owner';

  /// Called before a session becomes active.
  Future<void> claimFor(String userId) async {
    final kv = _ref.read(keyValueStoreProvider);
    final owner = kv.getString(_ownerKey);
    if (owner == userId) return;
    try {
      if (owner != null) await clear();
      await kv.setString(_ownerKey, userId);
    } on Object catch (e) {
      // Never block sign-in on local storage: sync holds back instead (see
      // [isFor]) and the next sign-in tries again.
      debugPrint('Local data: could not switch owner: $e');
    }
  }

  /// This device's data may be used for [userId]'s session: it's theirs, or
  /// no one's. False when switching owners failed, so another account's
  /// queue is never sent under this one.
  bool isFor(String userId) {
    final owner = _ref.read(keyValueStoreProvider).getString(_ownerKey);
    return owner == null || owner == userId;
  }

  Future<void> clear() async {
    await _ref.read(localStoreProvider).clearAll();
    await _ref.read(remindersProvider.notifier).setEnabled(false);
    await _ref.read(keyValueStoreProvider).remove(_ownerKey);
  }
}

final localDataProvider = Provider<LocalData>(LocalData.new);
