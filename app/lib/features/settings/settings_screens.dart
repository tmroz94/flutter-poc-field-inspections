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

/// P19: profile, reminders, biometric lock, offline data and the PoC tools;
/// from 840 px the appearance pane sits beside the list (T03).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _setReminders(BuildContext context, WidgetRef ref, bool on) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final canOpenSettings = ref.read(capabilitiesProvider).openSystemSettings;
    final permissions = ref.read(permissionServiceProvider);
    final result = await ref.read(remindersProvider.notifier).setEnabled(on);
    final message = switch (result) {
      RemindersResult.permissionDenied => l.remindersBlocked,
      RemindersResult.unsupported => l.remindersUnsupported,
      RemindersResult.scheduleFailed => l.remindersScheduleFailed,
      RemindersResult.on || RemindersResult.off => null,
    };
    if (message == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: result == RemindersResult.permissionDenied && canOpenSettings
            ? SnackBarAction(label: l.openSettings, onPressed: () => unawaited(permissions.openSettings()))
            : null,
      ),
    );
  }

  Future<void> _setBiometric(BuildContext context, WidgetRef ref, bool on) async {
    final lock = ref.read(lockControllerProvider.notifier);
    if (!on) return lock.setEnabled(false);
    final bio = ref.read(biometricServiceProvider);
    final reason = context.l10n.biometricReason;
    final notSetUp = context.l10n.biometricNotSetUp;
    final messenger = ScaffoldMessenger.of(context);
    if (!await bio.available()) {
      messenger.showSnackBar(SnackBar(content: Text(notSetUp)));
      return;
    }
    // Confirm once so the user knows what they're turning on.
    if (await bio.authenticate(reason: reason)) await lock.setEnabled(true);
  }

  /// Signing out deletes this device's drafts, outbox, photos and reminders
  /// (another account may sign in next); unsent work is listed first.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authControllerProvider.notifier);
    final drafts = ref.read(draftsProvider).value?.length ?? 0;
    final unsent = ref.read(outboxProvider).value?.length ?? 0;
    if (drafts + unsent > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) {
          final l = dialog.l10n;
          return AlertDialog(
            title: Text(l.signOutTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.signOutLocalData),
                const SizedBox(height: 8),
                if (unsent > 0) Text('• ${l.signOutUnsent(unsent)}'),
                if (drafts > 0) Text('• ${l.signOutDrafts(drafts)}'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l.cancel)),
              TextButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l.signOutConfirm)),
            ],
          );
        },
      );
      if (!(ok ?? false)) return;
    }
    await auth.signOut(clearLocalData: true);
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
          subtitle: Text(
            caps.scheduledNotifications
                ? context.l10n.remindersSubtitle
                : caps.isWeb
                ? context.l10n.remindersWebSubtitle
                : context.l10n.remindersLinuxSubtitle,
          ),
          value: reminders,
          onChanged: caps.scheduledNotifications ? (v) => _setReminders(context, ref, v) : null,
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
              Text(context.l10n.pocTools, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
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
          title: Text(context.l10n.signOut, style: TextStyle(color: theme.colorScheme.error)),
          onTap: () => _signOut(context, ref),
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
