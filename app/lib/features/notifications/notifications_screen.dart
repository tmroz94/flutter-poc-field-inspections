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

  Future<void> _dismiss(AppNotification n) async {
    setState(() => _hidden.add(n.id));
    ref.read(hapticsProvider).selection();
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final closed = messenger
        .showSnackBar(
          SnackBar(
            content: Text(context.l10n.notificationDismissed),
            action: SnackBarAction(label: context.l10n.undo, onPressed: () => setState(() => _hidden.remove(n.id))),
          ),
        )
        .closed;
    if (await closed != SnackBarClosedReason.action) {
      await ref.read(inspectionsRepositoryProvider).deleteNotification(n.id);
    }
  }

  Future<void> _open(AppNotification n) async {
    await ref.read(inspectionsRepositoryProvider).markNotificationsRead(id: n.id);
    ref.invalidate(notificationsProvider);
    if (!mounted) return;
    final route = DeepLinks.toLocation(n.route);
    if (route != null) context.go(route);
  }

  Future<void> _markAll() async {
    await ref.read(inspectionsRepositoryProvider).markNotificationsRead();
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        for (final n in list) _NotificationTile(n: n, now: now, onTap: () => _open(n), onDismiss: () => _dismiss(n)),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notificationsTitle),
        actions: [IconButton(tooltip: context.l10n.markAllRead, onPressed: _markAll, icon: const Icon(Symbols.done_all))],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificationsProvider.future),
        child: ListView(
          children: [
            const _PermissionCard(),
            if (data.isLoading && items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (todays.isNotEmpty) section('Today', todays),
            if (earlier.isNotEmpty) section('Earlier', earlier),
            if (!data.isLoading && items.isEmpty)
              const MessageState(icon: Symbols.notifications_off, title: 'No notifications', message: "You're all caught up."),
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
    final sameDay = n.at.year == now.year && n.at.month == now.month && n.at.day == now.day;
    final time = sameDay ? DateFormat.Hm().format(n.at) : DateFormat.E().format(n.at);
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
            Text('Dismiss', style: TextStyle(color: scheme.onErrorContainer)),
            const SizedBox(width: 8),
            Icon(Symbols.delete, color: scheme.onErrorContainer),
          ],
        ),
      ),
      child: Semantics(
        customSemanticsActions: {const CustomSemanticsAction(label: 'Dismiss'): onDismiss},
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
                  label: 'Unread',
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

/// "Reminders are off on this device" with Turn on (P17).
class _PermissionCard extends ConsumerWidget {
  const _PermissionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersOn = ref.watch(remindersProvider);
    final permission = ref.watch(_notificationPermissionProvider).value;
    final caps = ref.watch(capabilitiesProvider);
    if (remindersOn && permission == PermissionState.granted) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final blocked = permission == PermissionState.permanentlyDenied;

    Future<void> turnOn() async {
      final result = await ref.read(remindersProvider.notifier).setEnabled(true);
      ref.invalidate(_notificationPermissionProvider);
      if (!context.mounted) return;
      final message = switch (result) {
        RemindersResult.on => 'Reminders are on: 30 minutes before each inspection.',
        RemindersResult.permissionDenied => 'Notifications are blocked. Allow them in the system settings.',
        RemindersResult.unsupported =>
          caps.isWeb
              ? 'Browsers can’t schedule notifications. Test ones work from the deep-link tester while this tab is open.'
              : 'Linux can’t schedule notifications. Test ones work from the deep-link tester while the app is open.',
        RemindersResult.off => '',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }

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
                Expanded(child: Text('Reminders are off on this device', style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              caps.scheduledNotifications
                  ? 'Turn them on to get an alert 30 minutes before each inspection.'
                  : caps.isWeb
                  ? 'Browsers show notifications only while the app is open and can’t schedule them.'
                  : 'Linux shows notifications only while the app is open and can’t schedule them.',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: blocked && caps.openSystemSettings
                  ? FilledButton.tonal(
                      onPressed: () => ref.read(permissionServiceProvider).openSettings(),
                      child: Text(context.l10n.openSettings),
                    )
                  : FilledButton.tonal(onPressed: turnOn, child: Text(context.l10n.turnOn)),
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
              onTap: () => context.push(r.example),
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
