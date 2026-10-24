import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/capabilities.dart';
import '../../core/platform/notification_service.dart';
import '../../core/platform/platform_services.dart';
import '../../core/router/routes.dart';
import '../../core/storage/key_value_store.dart';
import '../../data/models/list_query.dart';
import '../../data/providers.dart';
import '../inspections/inspections_controller.dart';

enum RemindersResult { on, off, permissionDenied, unsupportedOnWeb }

/// "Inspection reminders" (P19, P17): a notification 30 minutes before each
/// open inspection, which opens that inspection when tapped. The web can't
/// schedule notifications, so there the setting explains why it's off.
class RemindersController extends Notifier<bool> {
  static const _key = 'reminders';
  static const leadTime = Duration(minutes: 30);

  @override
  bool build() => ref.watch(keyValueStoreProvider).getString(_key) == 'true';

  Future<RemindersResult> setEnabled(bool on) async {
    final notifications = ref.read(notificationServiceProvider);
    if (!on) {
      await notifications.cancelAll();
      await ref.read(keyValueStoreProvider).setString(_key, 'false');
      state = false;
      return RemindersResult.off;
    }
    if (ref.read(capabilitiesProvider).isWeb) return RemindersResult.unsupportedOnWeb;
    if (await notifications.permission() != PermissionState.granted && !await notifications.requestPermission()) {
      return RemindersResult.permissionDenied;
    }
    await ref.read(keyValueStoreProvider).setString(_key, 'true');
    state = true;
    await reschedule();
    return RemindersResult.on;
  }

  /// Schedules one reminder per upcoming open inspection.
  Future<int> reschedule() async {
    if (!state) return 0;
    final notifications = ref.read(notificationServiceProvider);
    await notifications.cancelAll();
    final page = await ref.read(inspectionsRepositoryProvider).list(const ListQuery(statuses: openStatuses), pageSize: 100);
    final now = DateTime.now();
    var count = 0;
    for (final i in page.items) {
      final at = i.scheduledAt.subtract(leadTime);
      if (at.isBefore(now)) continue;
      final ok = await notifications.schedule(
        id: i.id.hashCode & 0x7fffffff,
        at: at,
        title: '${i.site} at ${i.scheduledAt.hour.toString().padLeft(2, '0')}:${i.scheduledAt.minute.toString().padLeft(2, '0')}',
        body: 'Starts in 30 minutes',
        route: Routes.inspection(i.id),
      );
      if (ok) count++;
    }
    return count;
  }
}

final remindersProvider = NotifierProvider<RemindersController, bool>(RemindersController.new);
