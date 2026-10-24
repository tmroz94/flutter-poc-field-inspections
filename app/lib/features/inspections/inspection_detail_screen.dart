import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/layout/window_size.dart';
import '../../core/platform/capabilities.dart';
import '../../core/router/deep_links.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/inspection_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/inspection.dart';
import '../../data/models/list_query.dart';
import 'inspection_actions.dart';
import 'inspection_list_screen.dart';
import 'inspections_controller.dart';

enum DetailTab {
  overview('Overview'),
  checklist('Checklist'),
  photos('Photos'),
  history('History');

  const DetailTab(this.label);
  final String label;
}

/// `/inspections/:id?tab=`: pushed full screen under 840 (P06), the detail
/// pane of the list-detail layout from 840 (T01, D03).
class InspectionDetailScreen extends StatelessWidget {
  const InspectionDetailScreen({required this.id, required this.tab, super.key});

  final String id;
  final DetailTab tab;

  @override
  Widget build(BuildContext context) {
    final params = GoRouterState.of(context).uri.queryParameters;
    final listQuery = {
      for (final e in params.entries)
        if (e.key != 'tab') e.key: e.value,
    };
    if (context.windowSize.isTwoPane) {
      return InspectionsScreen(
        query: listQuery,
        selectedId: id,
        detail: InspectionDetailView(id: id, tab: tab, pane: true),
      );
    }
    return Scaffold(
      body: InspectionDetailView(id: id, tab: tab, pane: false),
    );
  }
}

/// Location of this inspection keeping the list's filters, so back and the
/// list pane show the same filtered list.
String detailLocation(BuildContext context, String id, DetailTab tab) {
  final params = GoRouterState.of(context).uri.queryParameters;
  final list = ListQuery.fromQuery(params).toQuery();
  final query = {...list, if (tab != DetailTab.overview) 'tab': tab.name};
  return Uri(path: '/inspections/$id', queryParameters: query.isEmpty ? null : query).toString();
}

class InspectionDetailView extends ConsumerWidget {
  const InspectionDetailView({required this.id, required this.tab, required this.pane, super.key});

  final String id;
  final DetailTab tab;

  /// Shown beside the list (no back button, smaller hero, no Hero flight).
  final bool pane;

  void _back(BuildContext context) {
    // Go to the list location explicitly so the detail's ?tab= doesn't stay in the URL.
    final list = ListQuery.fromQuery(GoRouterState.of(context).uri.queryParameters);
    context.go(list.toLocation(Routes.inspections));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(inspectionDetailProvider(id));
    return switch (detail) {
      AsyncData(:final value) => _DetailBody(detail: value, tab: tab, pane: pane, onBack: () => _back(context)),
      AsyncError(:final error) => Scaffold(
        appBar: pane ? null : AppBar(leading: BackButton(onPressed: () => _back(context))),
        body: error is ApiException && error.code == 'notFound'
            ? MessageState(
                icon: Symbols.search_off,
                title: 'Inspection not found',
                message: 'There is no inspection $id. It may have been deleted or the link is wrong.',
                action: FilledButton.tonal(onPressed: () => context.go(Routes.inspections), child: const Text('Back to inspections')),
              )
            : MessageState(
                icon: Symbols.sync_problem,
                isError: true,
                title: "Couldn't load $id",
                message: error is ApiException && error.isNetwork ? "You're offline. Connect and try again." : 'Something went wrong.',
                action: FilledButton.icon(
                  onPressed: () => ref.invalidate(inspectionDetailProvider(id)),
                  icon: const Icon(Symbols.refresh),
                  label: const Text('Try again'),
                ),
              ),
      ),
      _ => const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading inspection')),
    };
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.detail, required this.tab, required this.pane, required this.onBack});

  final InspectionDetail detail;
  final DetailTab tab;
  final bool pane;
  final VoidCallback onBack;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: DetailTab.values.length, vsync: this, initialIndex: widget.tab.index);

  @override
  void didUpdateWidget(_DetailBody old) {
    super.didUpdateWidget(old);
    // The URL changed (back/forward, link): follow it.
    if (widget.tab.index != _tabs.index) _tabs.animateTo(widget.tab.index);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Tabs replace the URL instead of adding history entries, so browser back
  /// leaves the inspection instead of stepping through its tabs.
  void _selectTab(int index) => GoRouter.of(context).replace<void>(detailLocation(context, widget.detail.id, DetailTab.values[index]));

  Future<void> _copyLink() async {
    final path = Routes.inspection(widget.detail.id, tab: widget.tab == DetailTab.overview ? null : widget.tab.name);
    final link = ref.read(capabilitiesProvider).isWeb ? '${Uri.base.origin}$path' : '${DeepLinks.scheme}://${DeepLinks.schemeHost}$path';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link copied: $link')));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final s = d.summary;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timeFmt = DateFormat.Hm();
    final now = ref.watch(clockProvider)();
    final when = '${relativeWhen(s.scheduledAt, now)}–${timeFmt.format(d.endsAt)}';
    final wideTablet = context.windowSize.usesRail;
    final actions = InspectionActions(ref, context);

    final hero = Container(
      width: double.infinity,
      height: widget.pane ? 160 : (wideTablet ? 280 : 200),
      margin: widget.pane || wideTablet ? const EdgeInsets.symmetric(horizontal: 24) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: widget.pane || wideTablet ? BorderRadius.circular(AppRadii.extraLarge) : null,
      ),
      child: Semantics(
        label: 'Site photo placeholder',
        child: Icon(siteIcon(s.icon), size: 56, color: scheme.onSecondaryContainer),
      ),
    );

    final iconActions = [
      IconButton(tooltip: 'Copy link', onPressed: _copyLink, icon: const Icon(Symbols.link)),
      IconButton(
        tooltip: 'Share report',
        onPressed: () => actions.share(s, path: detailLocation(context, s.id, widget.tab)),
        icon: const Icon(Symbols.share),
      ),
      MenuAnchor(
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(Symbols.edit),
            onPressed: () => context.push(Routes.editInspection(s.id)),
            child: const Text('Edit'),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Symbols.map),
            onPressed: () => context.go(Routes.mapSite(s.siteId)),
            child: const Text('Show on map'),
          ),
        ],
        builder: (context, c, _) =>
            IconButton(tooltip: 'More options', onPressed: () => c.isOpen ? c.close() : c.open(), icon: const Icon(Symbols.more_vert)),
      ),
    ];

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(s.status),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(s.site, style: wideTablet && !widget.pane ? theme.textTheme.headlineMedium : theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: 4),
          Text(
            '${s.id} · $when${widget.pane || wideTablet ? ' · ${s.address}' : ''}',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(avatar: const Icon(Symbols.directions), label: const Text('Directions'), onPressed: () => actions.directions(s)),
              ActionChip(avatar: const Icon(Symbols.call), label: const Text('Call site'), onPressed: () => actions.call(d.siteManager)),
              ActionChip(
                avatar: const Icon(Symbols.picture_as_pdf),
                label: const Text('Export PDF'),
                onPressed: () => actions.exportPdf(d),
              ),
            ],
          ),
        ],
      ),
    );

    final tabBody = switch (DetailTab.values[_tabs.index]) {
      DetailTab.overview => _Overview(detail: d),
      DetailTab.checklist => _Checklist(detail: d),
      DetailTab.photos => _Photos(
        detail: d,
        columns: wideTablet ? 4 : 3,
        onShare: (ids) => actions.share(s, path: Routes.photo(d.id, ids.first)),
      ),
      DetailTab.history => _History(detail: d),
    };

    final content = CustomScrollView(
      slivers: [
        if (widget.pane)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      detailLocation(context, s.id, widget.tab),
                      style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant, fontFamily: 'monospace'),
                    ),
                  ),
                  ...iconActions,
                ],
              ),
            ),
          )
        else if (wideTablet)
          SliverAppBar(
            pinned: true,
            leading: BackButton(onPressed: widget.onBack),
            title: const Text('Inspection'),
            actions: iconActions,
          ),
        SliverToBoxAdapter(
          child: Stack(
            children: [
              if (widget.pane) hero else Hero(tag: 'site-${s.id}', child: hero),
              if (!widget.pane && !wideTablet)
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        IconButton.filledTonal(tooltip: 'Back', onPressed: widget.onBack, icon: const Icon(Symbols.arrow_back)),
                        const Spacer(),
                        for (final a in iconActions) a,
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(child: header),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarHeader(
            TabBar(
              controller: _tabs,
              isScrollable: widget.pane,
              tabAlignment: widget.pane ? TabAlignment.start : TabAlignment.fill,
              onTap: _selectTab,
              tabs: [for (final t in DetailTab.values) Tab(text: t.label)],
            ),
            scheme.surface,
          ),
        ),
        SliverToBoxAdapter(child: tabBody),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );

    return Scaffold(
      body: content,
      floatingActionButton: s.status.isOpen
          ? FloatingActionButton.extended(
              heroTag: 'detail-fab-${s.id}',
              onPressed: () => context.push(Routes.editInspection(s.id, step: 3)),
              icon: const Icon(Symbols.edit),
              label: const Text('Continue'),
            )
          : null,
    );
  }
}

class _TabBarHeader extends SliverPersistentHeaderDelegate {
  _TabBarHeader(this.tabBar, this.color);

  final TabBar tabBar;
  final Color color;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => ColoredBox(color: color, child: tabBar);

  @override
  bool shouldRebuild(_TabBarHeader old) => old.tabBar != tabBar || old.color != color;
}

class _Overview extends StatelessWidget {
  const _Overview({required this.detail});

  final InspectionDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    return Column(
      children: [
        ListTile(leading: const Icon(Symbols.location_on), title: Text(s.address), subtitle: Text('${detail.postcode} ${s.city}')),
        ListTile(
          leading: const Icon(Symbols.category),
          title: Text(s.type),
          subtitle: Text('Checklist template v3 · ${detail.total} items'),
        ),
        ListTile(
          leading: const Icon(Symbols.person),
          title: Text(detail.siteManager.name),
          subtitle: Text([detail.siteManager.role, ?detail.siteManager.phone].join(' · ')),
        ),
        ListTile(leading: const Icon(Symbols.badge), title: Text(detail.inspector.name), subtitle: Text(detail.inspector.role)),
        if (detail.notes.isNotEmpty) ListTile(leading: const Icon(Symbols.notes), title: const Text('Notes'), subtitle: Text(detail.notes)),
      ],
    );
  }
}

class _Checklist extends ConsumerWidget {
  const _Checklist({required this.detail});

  final InspectionDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = ref.watch(checklistProvider(detail.templateId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('${detail.answered} of ${detail.total} checked', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (detail.failed > 0)
                Text('${detail.failed} failed', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(
            value: detail.total == 0 ? 0 : detail.answered / detail.total,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        if (items case AsyncData(:final value))
          for (final item in value) _ChecklistRow(title: item.title, answer: detail.answers[item.id])
        else
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.title, required this.answer});

  final String title;
  final Answer? answer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, label, fill) = switch (answer) {
      Answer.pass => (Symbols.check_circle, scheme.primary, 'Pass', 1.0),
      Answer.fail => (Symbols.cancel, scheme.error, 'Fail', 1.0),
      Answer.na => (Symbols.remove_circle_outline, scheme.onSurfaceVariant, 'N/A', 0.0),
      null => (Symbols.radio_button_unchecked, scheme.onSurfaceVariant, 'To do', 0.0),
    };
    return ListTile(
      leading: Icon(icon, color: color, fill: fill),
      title: Text(title),
      trailing: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: answer == Answer.fail ? scheme.error : null)),
    );
  }
}

/// Photo grid. Tap opens the viewer (Hero); long-press starts multi-select (P07).
class _Photos extends StatefulWidget {
  const _Photos({required this.detail, required this.columns, required this.onShare});

  final InspectionDetail detail;
  final int columns;
  final ValueChanged<List<String>> onShare;

  @override
  State<_Photos> createState() => _PhotosState();
}

class _PhotosState extends State<_Photos> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final photos = widget.detail.photos;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (photos.isEmpty) {
      return const MessageState(
        icon: Symbols.photo_library,
        title: 'No photos yet',
        message: 'Photos taken during the inspection show up here.',
      );
    }
    final selecting = _selected.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selecting ? '${_selected.length} selected' : 'Long-press a photo to select several.',
                  style: selecting ? theme.textTheme.titleMedium : theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              if (selecting) ...[
                IconButton(tooltip: 'Share selected', onPressed: () => widget.onShare(_selected.toList()), icon: const Icon(Symbols.share)),
                IconButton(tooltip: 'Cancel selection', onPressed: () => setState(_selected.clear), icon: const Icon(Symbols.close)),
              ],
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: widget.columns, mainAxisSpacing: 4, crossAxisSpacing: 4),
          itemCount: photos.length,
          itemBuilder: (context, i) {
            final p = photos[i];
            final isSelected = _selected.contains(p.id);
            void toggle() => setState(() => isSelected ? _selected.remove(p.id) : _selected.add(p.id));
            return Semantics(
              button: true,
              selected: selecting ? isSelected : null,
              label: selecting ? 'Photo ${i + 1}' : 'Open photo ${i + 1} of ${photos.length}',
              child: GestureDetector(
                onTap: selecting ? toggle : () => context.push(Routes.photo(widget.detail.id, p.id)),
                onLongPress: toggle,
                child: AnimatedScale(
                  scale: isSelected ? 0.9 : 1,
                  duration: Durations.short4,
                  curve: Easing.standard,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'photo-${widget.detail.id}-${p.id}',
                        child: PhotoPlaceholder(index: i),
                      ),
                      if (selecting)
                        PositionedDirectional(
                          top: 6,
                          start: 6,
                          child: Icon(
                            isSelected ? Symbols.check_circle : Symbols.radio_button_unchecked,
                            fill: isSelected ? 1 : 0,
                            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Stand-in for fixture photos, which have no image bytes.
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({required this.index, this.iconSize = 32, super.key});

  final int index;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [scheme.secondaryContainer, scheme.tertiaryContainer, scheme.primaryContainer, scheme.surfaceContainerHighest];
    return DecoratedBox(
      decoration: BoxDecoration(color: colors[index % colors.length], borderRadius: BorderRadius.circular(AppRadii.small)),
      child: Center(
        child: Icon(Symbols.photo, size: iconSize, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.detail});

  final InspectionDetail detail;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.MMMd().add_Hm();
    return Column(
      children: [
        for (final h in detail.history)
          ListTile(leading: Icon(siteIcon(h.icon)), title: Text(h.title), subtitle: Text([fmt.format(h.at), ?h.by].join(' · '))),
      ],
    );
  }
}
