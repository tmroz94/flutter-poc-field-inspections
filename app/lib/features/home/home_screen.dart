import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/layout/window_size.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/inspection_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/inspection.dart';
import '../auth/auth_controller.dart';
import '../inspections/inspections_controller.dart';
import '../notifications/notification_bell.dart';

/// P02 (phone) / D02 (desktop): greeting, offline banner, today's cards and
/// what's due this week.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting(DateTime now) => switch (now.hour) {
    < 12 => 'Good morning',
    < 18 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final data = ref.watch(homeProvider);
    final now = ref.watch(clockProvider)();
    final size = context.windowSize;
    final theme = Theme.of(context);
    final offline = data.error is ApiException && (data.error! as ApiException).isNetwork;

    Future<void> refresh() => ref.refresh(homeProvider.future).then((_) {}, onError: (_) {});

    return Scaffold(
      appBar: AppBar(
        title: Text('${_greeting(now)}, ${user?.firstName ?? ''}'),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Account and settings',
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
              label: const Text('New inspection'),
            ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          children: [
            if (offline) ...[OfflineBanner(onRetry: refresh, message: 'Connect to load your inspections.'), const SizedBox(height: 16)],
            _SectionHeader(
              title: 'Today',
              action: TextButton(onPressed: () => context.go(Routes.inspections), child: const Text('See all')),
            ),
            switch (data) {
              AsyncData(:final value) when value.today.isEmpty => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Nothing scheduled for today.'),
              ),
              AsyncData(:final value) => _TodayCards(items: value.today, now: now),
              AsyncError() => const SizedBox.shrink(),
              _ => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
            },
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Due this week'),
            if (data case AsyncData(:final value))
              if (value.week.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text('Nothing else due this week.'))
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
    final time = relativeWhen(item.scheduledAt, now).replaceFirst('Today ', '');
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
      InspectionStatus.overdue => 'Overdue by $days ${days == 1 ? 'day' : 'days'}',
      InspectionStatus.draft => 'Draft · not synced',
      _ => '${item.status.label} · ${relativeWhen(item.scheduledAt, now).split(' ').last}',
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
