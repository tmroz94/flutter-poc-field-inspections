import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/layout/window_size.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/inspection_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/local/local_store.dart';
import '../../data/models/draft.dart';
import '../../data/models/inspection.dart';
import '../../data/sync/sync_service.dart';
import '../../l10n/l10n.dart';
import '../auth/auth_controller.dart';
import '../inspections/inspections_controller.dart';
import '../notifications/notification_bell.dart';

/// P02 (phone) / D02 (desktop): greeting, offline banner, today's cards and
/// what's due this week.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting(BuildContext context, DateTime now, String name) => switch (now.hour) {
    < 12 => context.l10n.greetingMorning(name),
    < 18 => context.l10n.greetingAfternoon(name),
    _ => context.l10n.greetingEvening(name),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final data = ref.watch(homeProvider);
    final now = ref.watch(clockProvider)();
    final size = context.windowSize;
    final theme = Theme.of(context);
    final drafts = ref.watch(draftsProvider).value ?? const <String, InspectionDraft>{};
    final outbox = ref.watch(outboxProvider).value ?? const <OutboxEntry>[];
    final waiting = outbox.where((e) => e.lastError == null).length;
    final offline = (data.error is ApiException && (data.error! as ApiException).isNetwork) || ref.watch(syncServiceProvider).offline;

    Future<void> refresh() => ref.refresh(homeProvider.future).then((_) {}, onError: (_) {});

    return Scaffold(
      appBar: AppBar(
        title: Text(_greeting(context, now, user?.firstName ?? '')),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: context.l10n.accountAndSettings,
            icon: CircleAvatar(radius: 16, child: Text(user?.initials ?? '', style: theme.textTheme.labelMedium)),
            onPressed: () => context.go(Routes.settings),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: size.usesRail
          ? null
          : FloatingActionButton.extended(
              heroTag: 'home-fab',
              onPressed: () => context.push(Routes.newInspectionStep(1)),
              icon: const Icon(Symbols.add),
              label: Text(context.l10n.newInspection),
            ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          children: [
            if (offline) ...[
              OfflineBanner(
                onRetry: () {
                  unawaited(ref.read(syncServiceProvider.notifier).run());
                  unawaited(refresh());
                },
                message: waiting == 0 ? context.l10n.offlineConnect : context.l10n.offlineReportsWaiting(waiting),
              ),
              const SizedBox(height: 16),
            ],
            if (drafts.isNotEmpty || outbox.isNotEmpty) ...[
              _LocalWork(drafts: drafts, outbox: outbox, onRetry: () => ref.read(syncServiceProvider.notifier).run()),
              const SizedBox(height: 16),
            ],
            _SectionHeader(
              title: context.l10n.homeToday,
              action: TextButton(onPressed: () => context.go(Routes.inspections), child: Text(context.l10n.seeAll)),
            ),
            switch (data) {
              AsyncData(:final value) when value.today.isEmpty => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(context.l10n.homeNothingToday),
              ),
              AsyncData(:final value) => _TodayCards(items: value.today, now: now),
              AsyncError() => const SizedBox.shrink(),
              _ => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
            },
            const SizedBox(height: 24),
            _SectionHeader(title: context.l10n.homeDueThisWeek),
            if (data case AsyncData(:final value))
              if (value.week.isEmpty)
                Padding(padding: const EdgeInsets.all(16), child: Text(context.l10n.homeNothingWeek))
              else
                for (final i in value.week) _DueTile(item: i, now: now),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        ),
        ?action,
      ],
    ),
  );
}

/// Horizontal cards on phones; a responsive grid from 600 (D02).
class _TodayCards extends StatelessWidget {
  const _TodayCards({required this.items, required this.now});

  final List<InspectionSummary> items;
  final DateTime now;

  /// Media keeps 112 px; the text block grows with the text size (up to 200%).
  static double cardHeight(BuildContext context) => 132 + MediaQuery.textScalerOf(context).scale(1) * 112;

  @override
  Widget build(BuildContext context) {
    final height = cardHeight(context);
    if (!context.windowSize.usesRail) {
      return SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(
            width: 248,
            child: _TodayCard(item: items[i], now: now),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: LayoutBuilder(
        builder: (context, c) {
          final columns = (c.maxWidth / 280).floor().clamp(1, 4);
          final width = (c.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final i in items)
                SizedBox(
                  width: width,
                  height: height,
                  child: _TodayCard(item: i, now: now),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.item, required this.now});

  final InspectionSummary item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat.Hm().format(item.scheduledAt);
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(Routes.inspection(item.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: theme.colorScheme.secondaryContainer,
                child: Icon(siteIcon(item.icon), size: 32, color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.site, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    '$time · ${item.address}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  StatusChip(item.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueTile extends StatelessWidget {
  const _DueTile({required this.item, required this.now});

  final InspectionSummary item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overdue = item.status == InspectionStatus.overdue;
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(item.scheduledAt.year, item.scheduledAt.month, item.scheduledAt.day)).inDays;
    final subtitle = switch (item.status) {
      InspectionStatus.overdue => context.l10n.overdueByDays(days),
      InspectionStatus.draft => context.l10n.draftNotSynced,
      _ => '${item.status.localized(context.l10n)} · ${DateFormat.Hm().format(item.scheduledAt)}',
    };
    final weekday = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][item.scheduledAt.weekday - 1];
    return ListTile(
      onTap: () => context.go(Routes.inspection(item.id)),
      leading: CircleAvatar(
        backgroundColor: overdue ? scheme.errorContainer : scheme.primaryContainer,
        foregroundColor: overdue ? scheme.onErrorContainer : scheme.onPrimaryContainer,
        child: Text(weekday, style: Theme.of(context).textTheme.labelLarge),
      ),
      title: Text(item.site),
      subtitle: Text(subtitle),
      trailing: Icon(switch (item.status) {
        InspectionStatus.overdue => Symbols.error,
        InspectionStatus.draft => Symbols.cloud_upload,
        _ => Symbols.chevron_right,
      }, color: overdue ? scheme.error : null),
    );
  }
}

/// Drafts saved on this device and reports waiting in the outbox.
class _LocalWork extends StatelessWidget {
  const _LocalWork({required this.drafts, required this.outbox, required this.onRetry});

  final Map<String, InspectionDraft> drafts;
  final List<OutboxEntry> outbox;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat.Hm();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (drafts.isNotEmpty) ...[
          _SectionHeader(title: context.l10n.homeDraftsOnDevice),
          for (final MapEntry(key: key, value: d) in drafts.entries)
            ListTile(
              leading: Icon(Symbols.edit_note, color: scheme.tertiary),
              title: Text(d.siteName.isEmpty ? (key == 'new' ? 'New inspection' : key) : d.siteName),
              subtitle: Text(
                [context.l10n.stepOf(d.lastStep, 5), if (d.updatedAt != null) context.l10n.savedAt(time.format(d.updatedAt!))].join(' · '),
              ),
              trailing: const Icon(Symbols.chevron_right),
              onTap: () => context.push(key == 'new' ? Routes.newInspectionStep(d.lastStep) : Routes.editInspection(key, step: d.lastStep)),
            ),
        ],
        if (outbox.isNotEmpty) ...[
          _SectionHeader(
            title: context.l10n.homeWaitingToSend,
            action: TextButton(onPressed: onRetry, child: Text(context.l10n.syncNow)),
          ),
          for (final e in outbox)
            ListTile(
              leading: Icon(
                e.lastError == null ? Symbols.cloud_upload : Symbols.sync_problem,
                color: e.lastError == null ? null : scheme.error,
              ),
              title: Text(e.site.isEmpty ? (e.inspectionId ?? 'New inspection') : e.site),
              subtitle: Text(
                e.lastError == null ? 'Queued ${time.format(e.createdAt)} · sends when online' : 'Rejected by the server: ${e.lastError}',
              ),
            ),
        ],
      ],
    );
  }
}
