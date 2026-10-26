import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/platform/capabilities.dart';
import '../../core/platform/notification_service.dart';
import '../../core/platform/platform_services.dart';
import '../../core/router/deep_links.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/inspection_widgets.dart';
import '../../data/models/notification.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../inspections/inspections_controller.dart';
import 'reminders.dart';

final _notificationPermissionProvider = FutureProvider.autoDispose<PermissionState>(
  (ref) => ref.watch(notificationServiceProvider).permission(),
);

/// P17: today / earlier sections, swipe to dismiss with undo, tap opens the
/// notification's route (the same route a system notification carries).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// Hidden right away on swipe; deleted on the server unless undone.
  final Set<String> _hidden = {};

  /// Hides the row now and deletes it on the server once the snackbar closes
  /// without Undo. The snackbar outlives this screen (it moves with the user),
  /// so nothing after the wait may use this screen's `ref` or `setState`.
  Future<void> _dismiss(AppNotification n) async {
    setState(() => _hidden.add(n.id));
    ref.read(hapticsProvider).selection();
    final repository = ref.read(inspectionsRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final closed = messenger
        .showSnackBar(
          SnackBar(
            content: Text(context.l10n.notificationDismissed),
            action: SnackBarAction(
              label: context.l10n.undo,
              onPressed: () {
                if (mounted) setState(() => _hidden.remove(n.id));
              },
            ),
          ),
        )
        .closed;
    if (await closed == SnackBarClosedReason.action) return;
    try {
      await repository.deleteNotification(n.id);
    } on Object catch (e) {
      debugPrint('Delete notification ${n.id} failed: $e');
    }
    // Bell badge and the list (if still open) reload from the server.
    container.invalidate(notificationsProvider);
  }

  /// Opens the route at once; marking it read is best-effort (offline too).
  void _open(AppNotification n) {
    final repository = ref.read(inspectionsRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final route = DeepLinks.toLocation(n.route);
    if (route != null) context.go(route);
    unawaited(
      Future.sync(() => repository.markNotificationsRead(id: n.id))
          .then((_) => container.invalidate(notificationsProvider), onError: (Object e) => debugPrint('Mark ${n.id} read failed: $e')),
    );
  }

  Future<void> _markAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.somethingWentWrong;
    try {
      await ref.read(inspectionsRepositoryProvider).markNotificationsRead();
      if (mounted) ref.invalidate(notificationsProvider);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final data = ref.watch(notificationsProvider);
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final items = (data.value ?? const <AppNotification>[]).where((n) => !_hidden.contains(n.id)).toList();
    final todays = items.where((n) => !n.at.isBefore(today)).toList();
    final earlier = items.where((n) => n.at.isBefore(today)).toList();

    Widget section(String title, List<AppNotification> list) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ),
        for (final n in list) _NotificationTile(n: n, now: now, onTap: () => _open(n), onDismiss: () => unawaited(_dismiss(n))),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.notificationsTitle),
        actions: [IconButton(tooltip: l.markAllRead, onPressed: _markAll, icon: const Icon(Symbols.done_all))],
      ),
      body: RefreshIndicator(
        // A failed refresh shows in the list; the indicator just stops.
        onRefresh: () => ref.refresh(notificationsProvider.future).then((_) {}, onError: (Object _) {}),
        child: ListView(
          children: [
            const _PermissionCard(),
            if (data.isLoading && items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (todays.isNotEmpty) section(l.todaySection, todays),
            if (earlier.isNotEmpty) section(l.earlier, earlier),
            if (!data.isLoading && items.isEmpty)
              data.hasError
                  ? MessageState(
                      icon: Symbols.sync_problem,
                      isError: true,
                      title: l.notificationsLoadFailed,
                      message: l.offlineTryAgain,
                      action: FilledButton.icon(
                        onPressed: () => ref.invalidate(notificationsProvider),
                        icon: const Icon(Symbols.refresh),
                        label: Text(l.tryAgain),
                      ),
                    )
                  : MessageState(icon: Symbols.notifications_off, title: l.noNotificationsTitle, message: l.noNotificationsBody),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.n, required this.now, required this.onTap, required this.onDismiss});

  final AppNotification n;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sameDay = n.at.year == now.year && n.at.month == now.month && n.at.day == now.day;
    final time = sameDay ? DateFormat.Hm(locale).format(n.at) : DateFormat.E(locale).format(n.at);
    return Dismissible(
      key: ValueKey('notification-${n.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        color: scheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.dismiss, style: TextStyle(color: scheme.onErrorContainer)),
            const SizedBox(width: 8),
            Icon(Symbols.delete, color: scheme.onErrorContainer),
          ],
        ),
      ),
      child: Semantics(
        customSemanticsActions: {CustomSemanticsAction(label: l.dismiss): onDismiss},
        child: ListTile(
          onTap: onTap,
          leading: Icon(siteIcon(n.icon), color: n.icon == 'error' ? scheme.error : null),
          title: Text(n.title, style: n.read ? null : const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(n.body),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time, style: Theme.of(context).textTheme.labelSmall),
              if (!n.read) ...[
                const SizedBox(height: 4),
                Semantics(
                  label: l.unread,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Reminders are off on this device" with Turn on (P17). The permission is
/// checked again when the app comes back from the system settings.
class _PermissionCard extends ConsumerStatefulWidget {
  const _PermissionCard();

  @override
  ConsumerState<_PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends ConsumerState<_PermissionCard> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(_notificationPermissionProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _turnOn() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final caps = ref.read(capabilitiesProvider);
    final permissions = ref.read(permissionServiceProvider);
    final result = await ref.read(remindersProvider.notifier).setEnabled(true);
    if (!mounted) return;
    ref.invalidate(_notificationPermissionProvider);
    final message = switch (result) {
      RemindersResult.on => l.remindersOnMessage,
      RemindersResult.permissionDenied => l.remindersBlocked,
      RemindersResult.unsupported => caps.isWeb ? l.remindersWebTest : l.remindersLinuxTest,
      RemindersResult.scheduleFailed => l.remindersScheduleFailed,
      RemindersResult.off => null,
    };
    if (message == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: result == RemindersResult.permissionDenied && caps.openSystemSettings
            ? SnackBarAction(label: l.openSettings, onPressed: () => unawaited(permissions.openSettings()))
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remindersOn = ref.watch(remindersProvider);
    final permission = ref.watch(_notificationPermissionProvider).value;
    final caps = ref.watch(capabilitiesProvider);
    if (remindersOn && permission == PermissionState.granted) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l = context.l10n;
    final blocked = permission == PermissionState.permanentlyDenied;

    return Card.filled(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.notifications_off, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(l.remindersOff, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(switch ((caps.scheduledNotifications, caps.isWeb)) {
              (false, true) => l.remindersOffWeb,
              (false, false) => l.remindersOffLinux,
              _ => blocked ? l.remindersBlocked : l.remindersOffBody,
            }),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: blocked && caps.openSystemSettings
                  ? FilledButton.tonal(onPressed: () => ref.read(permissionServiceProvider).openSettings(), child: Text(l.openSettings))
                  : FilledButton.tonal(onPressed: _turnOn, child: Text(l.turnOn)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sends a notification that opens [route] after [delay] (deep-link tester).
/// Mobile, macOS and Windows schedule it so it also works with the app in the
/// background or closed, with time to close the app first (15 s); the web and
/// Linux show it from a timer while the app is open (5 s).
Future<String> sendTestNotification(WidgetRef ref, String route, {Duration? delay}) async {
  final n = ref.read(notificationServiceProvider);
  delay ??= Duration(seconds: n.canSchedule ? 15 : 5);
  if (await n.permission() != PermissionState.granted && !await n.requestPermission()) {
    return 'Notifications are not allowed on this device.';
  }
  final id = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  final scheduled = await n.schedule(id: id, at: DateTime.now().add(delay), title: 'Test link', body: route, route: route);
  if (!scheduled) {
    Future.delayed(delay, () => n.show(id: id, title: 'Test link', body: route, route: route));
  }
  final keepOpen = n.isWeb ? 'Keep this tab open.' : 'Keep the app open.';
  return 'Notification in ${delay.inSeconds} s. ${scheduled ? 'Put the app in the background or close it to test that too.' : keepOpen}';
}

/// Lists every route and opens it, and sends test notifications (deep links).
class DeepLinksScreen extends ConsumerWidget {
  const DeepLinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(capabilitiesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.deepLinkTester)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              caps.isWeb
                  ? 'Open a route, refresh the page, or paste a URL in the address bar.'
                  : 'Open a route here, from a notification, or with adb / xcrun (docs/deep-links.md).',
            ),
          ),
          for (final r in RouteTable.all)
            ListTile(
              title: Text(r.title),
              subtitle: Text(r.example, style: const TextStyle(fontFamily: 'monospace')),
              // `go`, like a real link: a pushed wizard asks "leave?" on its first step change (decision 71).
              onTap: () => context.go(r.example),
              trailing: IconButton(
                tooltip: 'Notification for ${r.title}',
                icon: const Icon(Symbols.notification_add),
                onPressed: () async {
                  final message = await sendTestNotification(ref, r.example);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                },
              ),
            ),
        ],
      ),
    );
  }
}
