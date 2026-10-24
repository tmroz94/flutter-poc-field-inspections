import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/layout/window_size.dart';
import '../../core/platform/capabilities.dart';
import '../../core/platform/platform_services.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/local_store.dart';
import '../../data/sync/sync_service.dart';
import '../../l10n/l10n.dart';
import '../auth/auth_controller.dart';
import '../auth/lock_controller.dart';
import '../notifications/reminders.dart';
import 'appearance_screen.dart';

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

    final wide = context.windowSize.isTwoPane;
    final list = ListView(
      children: [
        ListTile(
          leading: CircleAvatar(child: Text(user?.initials ?? '')),
          title: Text(user?.name ?? ''),
          subtitle: Text(user?.email ?? ''),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Symbols.palette),
          title: Text(context.l10n.appearanceAndLanguage),
          subtitle: Text(context.l10n.appearanceSubtitle),
          selected: wide,
          trailing: wide ? null : const Icon(Symbols.chevron_right),
          onTap: wide ? null : () => context.go(Routes.appearance),
        ),
        SwitchListTile(
          secondary: const Icon(Symbols.notifications),
          title: Text(context.l10n.inspectionReminders),
          subtitle: Text(caps.isWeb ? context.l10n.remindersWebSubtitle : context.l10n.remindersSubtitle),
          value: reminders,
          onChanged: caps.isWeb ? null : (v) => _setReminders(context, ref, v),
        ),
        if (caps.biometricLock)
          SwitchListTile(
            secondary: const Icon(Symbols.fingerprint),
            title: Text(context.l10n.biometricUnlock),
            subtitle: Text(context.l10n.biometricSubtitle),
            value: lock.enabled,
            onChanged: (v) => _setBiometric(context, ref, v),
          ),
        ListTile(
          leading: const Icon(Symbols.offline_pin),
          title: Text(context.l10n.offlineData),
          subtitle: Text(context.l10n.offlineDataSubtitle(drafts, waiting)),
          trailing: TextButton(onPressed: () => unawaited(ref.read(syncServiceProvider.notifier).run()), child: Text(context.l10n.syncNow)),
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
          title: Text(context.l10n.resultsTracker),
          subtitle: Text(context.l10n.resultsTrackerSubtitle),
          onTap: () => context.go(Routes.results),
        ),
        ListTile(leading: const Icon(Symbols.devices), title: Text(context.l10n.adaptiveWidgets), onTap: () => context.go(Routes.adaptive)),
        ListTile(
          leading: const Icon(Symbols.monitor_heart),
          title: Text(context.l10n.diagnostics),
          onTap: () => context.go(Routes.diagnostics),
        ),
        ListTile(leading: const Icon(Symbols.link), title: Text(context.l10n.deepLinkTester), onTap: () => context.go(Routes.deepLinks)),
        ListTile(
          leading: Icon(Symbols.logout, color: theme.colorScheme.error),
          title: Text('Sign out', style: TextStyle(color: theme.colorScheme.error)),
          onTap: () => ref.read(authControllerProvider.notifier).signOut(),
        ),
      ],
    );
    if (!wide) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.settingsTitle)),
        body: list,
      );
    }

    // T03: settings list beside the appearance pane.
    final scheme = theme.colorScheme;
    Widget pane(Widget child) =>
        Material(color: scheme.surface, borderRadius: BorderRadius.circular(AppRadii.large), clipBehavior: Clip.antiAlias, child: child);
    return Scaffold(
      backgroundColor: scheme.surfaceContainer,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 380,
                child: pane(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                        child: Text(context.l10n.settingsTitle, style: theme.textTheme.titleLarge),
                      ),
                      Expanded(child: list),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: pane(
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(context.l10n.appearanceAndLanguage, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 24),
                        const AppearanceView(twoColumns: true),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
