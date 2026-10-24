import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/platform/capabilities.dart';
import '../../core/platform/platform_services.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_view.dart';
import '../../data/local/local_store.dart';
import '../../data/sync/sync_service.dart';
import '../auth/auth_controller.dart';
import '../auth/lock_controller.dart';
import '../notifications/reminders.dart';

/// P19: profile, reminders, biometric lock, offline data and the PoC tools.
/// The tablet two-pane version (T03) and appearance (P20) arrive in M4.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _setReminders(BuildContext context, WidgetRef ref, bool on) async {
    final result = await ref.read(remindersProvider.notifier).setEnabled(on);
    if (!context.mounted) return;
    final message = switch (result) {
      RemindersResult.permissionDenied => 'Notifications are blocked for this app. Allow them in the system settings.',
      RemindersResult.unsupportedOnWeb => 'Browsers can’t schedule notifications, so reminders are mobile-only.',
      _ => null,
    };
    if (message != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setBiometric(BuildContext context, WidgetRef ref, bool on) async {
    final lock = ref.read(lockControllerProvider.notifier);
    if (!on) return lock.setEnabled(false);
    final bio = ref.read(biometricServiceProvider);
    if (!await bio.available()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Set up a fingerprint, face or screen lock on this device first.')));
      }
      return;
    }
    // Confirm once so the user knows what they're turning on.
    if (await bio.authenticate()) await lock.setEnabled(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    final caps = ref.watch(capabilitiesProvider);
    final reminders = ref.watch(remindersProvider);
    final lock = ref.watch(lockControllerProvider);
    final drafts = ref.watch(draftsProvider).value?.length ?? 0;
    final waiting = ref.watch(outboxProvider).value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(child: Text(user?.initials ?? '')),
            title: Text(user?.name ?? ''),
            subtitle: Text(user?.email ?? ''),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Symbols.palette),
            title: const Text('Appearance and language'),
            subtitle: const Text('Theme, contrast, text size, language'),
            trailing: const Icon(Symbols.chevron_right),
            onTap: () => context.go(Routes.appearance),
          ),
          SwitchListTile(
            secondary: const Icon(Symbols.notifications),
            title: const Text('Inspection reminders'),
            subtitle: Text(caps.isWeb ? 'Not available in the browser' : '30 minutes before start'),
            value: reminders,
            onChanged: caps.isWeb ? null : (v) => _setReminders(context, ref, v),
          ),
          if (caps.biometricLock)
            SwitchListTile(
              secondary: const Icon(Symbols.fingerprint),
              title: const Text('Biometric unlock'),
              subtitle: const Text('Lock after 5 minutes in the background'),
              value: lock.enabled,
              onChanged: (v) => _setBiometric(context, ref, v),
            ),
          ListTile(
            leading: const Icon(Symbols.offline_pin),
            title: const Text('Offline data'),
            subtitle: Text('$drafts ${drafts == 1 ? 'draft' : 'drafts'} · $waiting waiting to send'),
            trailing: TextButton(onPressed: () => unawaited(ref.read(syncServiceProvider.notifier).run()), child: const Text('Sync now')),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Symbols.science, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('PoC tools', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Symbols.fact_check),
            title: const Text('Results tracker'),
            subtitle: const Text('Pass, fail and notes per platform'),
            onTap: () => context.go(Routes.results),
          ),
          ListTile(leading: const Icon(Symbols.devices), title: const Text('Adaptive widgets'), onTap: () => context.go(Routes.adaptive)),
          ListTile(
            leading: const Icon(Symbols.monitor_heart),
            title: const Text('Diagnostics'),
            onTap: () => context.go(Routes.diagnostics),
          ),
          ListTile(leading: const Icon(Symbols.link), title: const Text('Deep-link tester'), onTap: () => context.go(Routes.deepLinks)),
          ListTile(
            leading: Icon(Symbols.logout, color: theme.colorScheme.error),
            title: Text('Sign out', style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderView(title: 'Appearance and language', boards: ['P20']);
}
