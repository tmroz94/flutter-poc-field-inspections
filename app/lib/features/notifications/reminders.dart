import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/capabilities.dart';
import '../../core/platform/notification_service.dart';
import '../../core/platform/platform_services.dart';
import '../../core/router/routes.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/theme/theme_settings.dart';
import '../../core/widgets/inspection_widgets.dart';
import '../../data/models/inspection.dart';
import '../../data/models/list_query.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../inspections/inspections_controller.dart';

enum RemindersResult { on, off, permissionDenied, unsupported, scheduleFailed }

/// "Inspection reminders" (P19, P17): a notification 30 minutes before each
/// open inspection, which opens that inspection when tapped. The web and Linux
/// can't schedule notifications, so there the setting explains why it's off.
///
/// The set is rebuilt on sign-in and whenever this app changes inspections
/// (submit, sync, archive), so new, moved and finished inspections are right.
class RemindersController extends Notifier<bool> {
  static const _key = 'reminders';
  static const leadTime = Duration(minutes: 30);

  Future<int?>? _running;
  bool _again = false;

  @override
  bool build() {
    ref
      ..listen(authControllerProvider.select((s) => s.status), (_, next) {
        if (next == AuthStatus.signedIn) unawaited(reschedule());
      })
      ..listen(inspectionsRevisionProvider, (_, _) => unawaited(reschedule()))
      // Their text is in the app language.
      ..listen(themeSettingsProvider.select((s) => s.locale), (_, _) => unawaited(reschedule()));
    return ref.watch(keyValueStoreProvider).getString(_key) == 'true';
  }

  Future<RemindersResult> setEnabled(bool on) async {
    final notifications = ref.read(notificationServiceProvider);
    if (!on) {
      try {
        await notifications.cancelAll();
      } on Object catch (e) {
        debugPrint('Reminders: cancel failed: $e');
      }
      await ref.read(keyValueStoreProvider).setString(_key, 'false');
      state = false;
      return RemindersResult.off;
    }
    if (!ref.read(capabilitiesProvider).scheduledNotifications) return RemindersResult.unsupported;
    if (await notifications.permission() != PermissionState.granted && !await notifications.requestPermission()) {
      return RemindersResult.permissionDenied;
    }
    await ref.read(keyValueStoreProvider).setString(_key, 'true');
    state = true;
    return await reschedule() == null ? RemindersResult.scheduleFailed : RemindersResult.on;
  }

  /// Replaces the scheduled reminders with one per upcoming open inspection.
  /// Returns how many, or null when the inspections couldn't be loaded (the
  /// previous reminders stay). Calls during a run make it run once more.
  Future<int?> reschedule() {
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _schedule().whenComplete(() {
      _running = null;
      if (_again && ref.mounted) {
        _again = false;
        unawaited(reschedule());
      }
    });
  }

  Future<int?> _schedule() async {
    if (!state ||
        !ref.read(capabilitiesProvider).scheduledNotifications ||
        ref.read(authControllerProvider).status != AuthStatus.signedIn) {
      return 0;
    }
    final notifications = ref.read(notificationServiceProvider);
    final List<InspectionSummary> items;
    try {
      items = (await ref.read(inspectionsRepositoryProvider).list(const ListQuery(statuses: openStatuses), pageSize: 100)).items;
    } on Object catch (e) {
      debugPrint('Reminders: could not load inspections: $e');
      return null;
    }
    if (!ref.mounted || !state) return 0;
    final l = _strings();
    // 24-hour time in both languages (en-GB, pl), without needing intl's locale data here.
    String time(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final now = ref.read(clockProvider)();
    var count = 0;
    try {
      await notifications.cancelAll();
      for (final i in items) {
        // Turned off meanwhile: stop (and clear what this run already set, below).
        if (!ref.mounted || !state) break;
        final at = i.scheduledAt.subtract(leadTime);
        if (at.isBefore(now)) continue;
        final ok = await notifications.schedule(
          id: i.id.hashCode & 0x7fffffff,
          at: at,
          title: l.reminderTitle(i.site, time(i.scheduledAt)),
          body: l.reminderBody,
          route: Routes.inspection(i.id),
          channelName: l.reminderChannel,
          channelDescription: l.reminderChannelDescription,
        );
        if (ok) count++;
      }
      if (!ref.mounted || !state) {
        await notifications.cancelAll();
        return 0;
      }
    } on Object catch (e) {
      debugPrint('Reminders: scheduling failed: $e');
      return null;
    }
    return count;
  }

  /// Notifications are built outside the widget tree: the app's language
  /// setting, else the device's.
  AppLocalizations _strings() {
    final locale = ref.read(themeSettingsProvider).locale ?? PlatformDispatcher.instance.locale;
    return lookupAppLocalizations(locale.languageCode == 'pl' ? const Locale('pl') : const Locale('en'));
  }
}

final remindersProvider = NotifierProvider<RemindersController, bool>(RemindersController.new);
