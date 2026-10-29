import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/layout/window_size.dart';
import '../../core/platform/capabilities.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/inspection_widgets.dart';
import '../../core/widgets/search_field.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/inspection.dart';
import '../../data/models/list_query.dart';
import '../../l10n/l10n.dart';
import '../notifications/notification_bell.dart';
import 'inspection_actions.dart';
import 'inspections_controller.dart';

/// P03/P04 on phones, T01 list-detail on tablets, D03 table + detail on desktop.
/// Filters live in the URL; [selectedId]/[detail] fill the second pane from 840.
class InspectionsScreen extends ConsumerStatefulWidget {
  const InspectionsScreen({required this.query, this.selectedId, this.detail, super.key});

  final Map<String, String> query;
  final String? selectedId;
  final Widget? detail;

  @override
  ConsumerState<InspectionsScreen> createState() => _InspectionsScreenState();
}

class _InspectionsScreenState extends ConsumerState<InspectionsScreen> {
  late final _search = TextEditingController(text: _query.q);
  final _searchFocus = FocusNode();
  Timer? _debounce;

  ListQuery get _query => ListQuery.fromQuery(widget.query);

  @override
  void didUpdateWidget(InspectionsScreen old) {
    super.didUpdateWidget(old);
    // Keep the field in sync when the URL changes from elsewhere (back, chips, links).
    if (!_searchFocus.hasFocus && _search.text != _query.q) _search.text = _query.q;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Chips and the sheet add a history entry; typing replaces it. With a
  /// detail open beside the list (from 840) the detail stays: its URL carries
  /// the list filters, and replacing it with the plain list URL would swap
  /// the page (and drop the search field's focus mid-typing).
  void _apply(ListQuery q, {bool replace = false}) {
    _debounce?.cancel();
    final selected = widget.selectedId;
    final String location;
    if (selected == null) {
      location = q.toLocation(Routes.inspections);
    } else {
      final tab = GoRouterState.of(context).uri.queryParameters['tab'];
      final params = {...q.toQuery(), 'tab': ?tab};
      location = Uri(path: Routes.inspection(selected), queryParameters: params.isEmpty ? null : params).toString();
    }
    replace ? GoRouter.of(context).replace<void>(location) : context.go(location);
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _apply(_query.copyWith(q: text.trim()), replace: true);
    });
  }

  /// Keeps the filters in the detail URL so the list pane (and back) shows the same list.
  void _open(InspectionSummary item) {
    // A search typed just before would otherwise replace the detail with the list.
    _debounce?.cancel();
    final q = _query.toQuery();
    context.go(Uri(path: '/inspections/${item.id}', queryParameters: q.isEmpty ? null : q).toString());
  }

  Future<void> _archive(InspectionSummary item) async {
    final controller = ref.read(inspectionListProvider(_query).notifier);
    final index = ref.read(inspectionListProvider(_query)).items.indexOf(item);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final l10n = context.l10n;

    // Undo can come after this list is gone (another filter); the controller
    // handles that, and a refusal from the server gets its own message.
    Future<void> undo() async {
      try {
        await controller.undoArchive(item, index);
      } on ApiException {
        messenger.showSnackBar(SnackBar(content: Text(l10n.undoFailed)));
      }
    }

    try {
      await controller.archive(item);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.archived(item.id)),
          action: SnackBarAction(label: l10n.undo, onPressed: () => unawaited(undo())),
        ),
      );
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.archiveFailed)));
    }
  }

  Future<void> _copyLink(InspectionSummary item) => InspectionActions(ref, context).copyLink(Routes.inspection(item.id));

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    final query = _query;
    final state = ref.watch(inspectionListProvider(query));
    ref.listen(inspectionListProvider(query).select((s) => s.error), (_, error) {
      // With rows on screen the error state isn't shown; they're the last list that loaded.
      if (error != null && ref.read(inspectionListProvider(query)).items.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.refreshFailed)));
      }
    });
    final caps = ref.watch(capabilitiesProvider);
    final scheme = Theme.of(context).colorScheme;
    Future<void> refresh() => ref.read(inspectionListProvider(query).notifier).refresh();

    final actions = [
      IconButton(
        tooltip: query.activeFilterCount == 0 ? context.l10n.filterAndSort : context.l10n.filterAndSortActive(query.activeFilterCount),
        isSelected: query.activeFilterCount > 0,
        onPressed: () => context.push(query.toLocation(Routes.inspectionsFilter)),
        icon: Badge(
          isLabelVisible: query.activeFilterCount > 0,
          label: Text('${query.activeFilterCount}'),
          child: const Icon(Symbols.tune),
        ),
      ),
      // Mouse and trackpad users can't pull to refresh.
      if (!caps.pullToRefreshOnly || size.isTwoPane)
        IconButton(tooltip: context.l10n.refreshList, onPressed: refresh, icon: const Icon(Symbols.refresh)),
      if (!size.isTwoPane) const NotificationBell(),
    ];

    Widget filters({required bool statuses}) => _Filters(
      showStatuses: statuses,
      search: _search,
      searchFocus: _searchFocus,
      onSearch: _onSearch,
      onClearSearch: () {
        _search.clear();
        _apply(query.copyWith(q: ''));
      },
      query: query,
      onStatus: (s) => _apply(query.copyWith(statuses: s == null ? {} : {s})),
    );

    final body = _ListBody(
      state: state,
      query: query,
      selectedId: widget.selectedId,
      onOpen: _open,
      onArchive: _archive,
      onCopyLink: _copyLink,
      onRefresh: refresh,
      onLoadMore: () => ref.read(inspectionListProvider(query).notifier).loadMore(),
      onRetryMore: () => ref.read(inspectionListProvider(query).notifier).retryMore(),
      onClearFilters: () {
        _debounce?.cancel();
        _search.clear();
        context.go(Routes.inspections);
      },
      onSort: (s) => _apply(query.copyWith(sort: s)),
      showMenu: !caps.isMobile,
      table: size == WindowSize.large,
    );

    // A landscape phone with the keyboard up leaves ~130 dp here: the status
    // chips step aside so the search field and some rows still fit.
    final listColumn = LayoutBuilder(
      builder: (context, box) => Column(
        children: [
          filters(statuses: box.maxHeight >= 240),
          Expanded(child: body),
        ],
      ),
    );

    if (!size.isTwoPane) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.inspectionsTitle), actions: actions),
        floatingActionButton: size.usesRail
            ? null
            : FloatingActionButton.extended(
                heroTag: 'list-fab',
                onPressed: () => context.go(Routes.newInspectionStep(1)),
                icon: const Icon(Symbols.add),
                label: Text(context.l10n.newShort),
              ),
        body: listColumn,
      );
    }

    // Two panes: T01 (380 px list) or D03 (table 3 : detail 2).
    // Material (not a coloured box) so list tiles can paint their highlight and ink.
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
              Flexible(
                flex: size == WindowSize.large ? 3 : 0,
                child: SizedBox(
                  width: size == WindowSize.large ? null : 380,
                  child: pane(
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 8, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Semantics(
                                  header: true,
                                  child: Text(context.l10n.inspectionsTitle, style: Theme.of(context).textTheme.titleLarge),
                                ),
                              ),
                              ...actions,
                            ],
                          ),
                        ),
                        Expanded(child: listColumn),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: pane(
                  widget.detail ??
                      MessageState(
                        icon: Symbols.assignment,
                        title: context.l10n.selectInspection,
                        message: context.l10n.selectInspectionHint,
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

class _Filters extends StatelessWidget {
  const _Filters({
    required this.showStatuses,
    required this.search,
    required this.searchFocus,
    required this.onSearch,
    required this.onClearSearch,
    required this.query,
    required this.onStatus,
  });

  final TextEditingController search;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final ListQuery query;
  final ValueChanged<InspectionStatus?> onStatus;
  final bool showStatuses;

  @override
  Widget build(BuildContext context) {
    final selected = query.singleStatus;
    final several = query.statuses.length > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          SearchField(
            controller: search,
            focusNode: searchFocus,
            hintText: context.l10n.searchSiteOrId,
            trailing: ListenableBuilder(
              listenable: search,
              builder: (_, _) => search.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(tooltip: context.l10n.clearSearch, onPressed: onClearSearch, icon: const Icon(Symbols.close)),
            ),
            onChanged: onSearch,
          ),
          if (showStatuses) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Semantics(
                container: true,
                label: context.l10n.statusFilter,
                child: Row(
                  children: [
                    FilterChip(label: Text(context.l10n.statusAll), selected: query.statuses.isEmpty, onSelected: (_) => onStatus(null)),
                    for (final s in InspectionStatus.values) ...[
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(s.localized(context.l10n)),
                        selected: selected == s || (several && query.statuses.contains(s)),
                        onSelected: (_) => onStatus(s),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListBody extends ConsumerWidget {
  const _ListBody({
    required this.state,
    required this.query,
    required this.selectedId,
    required this.onOpen,
    required this.onArchive,
    required this.onCopyLink,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRetryMore,
    required this.onClearFilters,
    required this.onSort,
    required this.showMenu,
    required this.table,
  });

  final ListState state;
  final ListQuery query;
  final String? selectedId;
  final ValueChanged<InspectionSummary> onOpen;
  final ValueChanged<InspectionSummary> onArchive;
  final ValueChanged<InspectionSummary> onCopyLink;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onRetryMore;
  final VoidCallback onClearFilters;
  final ValueChanged<SortOrder> onSort;
  final bool showMenu;
  final bool table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = state.error;
    final l = context.l10n;
    if (state.loading) return SingleChildScrollView(child: table ? const SkeletonTable() : const SkeletonList());
    if (error != null && state.items.isEmpty) {
      return Column(
        children: [
          if (error.isNetwork) ...[const SizedBox(height: 4), OfflineBanner(onRetry: onRefresh, strong: true, message: l.noConnection)],
          Expanded(
            child: MessageState(
              icon: Symbols.sync_problem,
              isError: true,
              title: l.loadErrorTitle,
              message: error.isNetwork ? l.loadErrorOffline : l.loadErrorServer,
              action: FilledButton.icon(onPressed: onRefresh, icon: const Icon(Symbols.refresh), label: Text(l.tryAgain)),
              detail: l.errorCode(error.isNetwork ? 'NETWORK_UNREACHABLE' : error.code.toUpperCase()),
            ),
          ),
        ],
      );
    }
    if (state.isEmpty) {
      final statuses = query.statuses.map((s) => s.localized(l)).join(', ');
      // Pull to refresh works here too: on a phone it's the only refresh.
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: box.maxHeight,
              child: MessageState(
                icon: Symbols.search_off,
                title: l.noMatchTitle,
                message: query.q.isNotEmpty
                    ? l.noMatchSearch(query.q)
                    : query.statuses.isEmpty
                    ? l.noMatchAny
                    : l.noMatchStatuses(statuses),
                action: FilledButton.tonal(onPressed: onClearFilters, child: Text(l.clearFilters)),
              ),
            ),
          ),
        ),
      );
    }
    if (table) {
      return _InspectionsTable(
        state: state,
        query: query,
        selectedId: selectedId,
        onOpen: onOpen,
        onArchive: onArchive,
        onCopyLink: onCopyLink,
        onLoadMore: onLoadMore,
        onRetryMore: onRetryMore,
        onSort: onSort,
      );
    }
    final now = ref.watch(clockProvider)();
    final extra = state.hasMore || state.loadingMore ? 1 : 0;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: state.items.length + extra,
        itemBuilder: (context, i) {
          // Infinite scroll near the end; after a failed page it waits for Retry.
          if (i >= state.items.length - 5 && state.moreError == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
          }
          if (i == state.items.length) return state.moreError != null ? _LoadMoreFailed(onRetry: onRetryMore) : const _LoadingMore();
          final item = state.items[i];
          return _InspectionTile(
            item: item,
            now: now,
            selected: item.id == selectedId,
            onTap: () => onOpen(item),
            onArchive: () => onArchive(item),
            onCopyLink: () => onCopyLink(item),
            showMenu: showMenu,
          );
        },
      ),
    );
  }
}

class _LoadingMore extends StatelessWidget {
  const _LoadingMore();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(width: 12),
        Text(context.l10n.loadingMore),
      ],
    ),
  );
}

class _LoadMoreFailed extends StatelessWidget {
  const _LoadMoreFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: Semantics(liveRegion: true, child: Text(context.l10n.loadMoreFailed))),
        const SizedBox(width: 8),
        TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
      ],
    ),
  );
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.item, required this.onArchive, required this.onCopyLink});

  final InspectionSummary item;
  final VoidCallback onArchive;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      MenuItemButton(leadingIcon: const Icon(Symbols.archive), onPressed: onArchive, child: Text(context.l10n.archive)),
      MenuItemButton(leadingIcon: const Icon(Symbols.link), onPressed: onCopyLink, child: Text(context.l10n.copyLink)),
      MenuItemButton(
        leadingIcon: const Icon(Symbols.map),
        onPressed: () => context.go(Routes.mapSite(item.siteId, inspectionId: item.id)),
        child: Text(context.l10n.showOnMap),
      ),
    ],
    builder: (context, controller, _) => IconButton(
      tooltip: context.l10n.actionsFor(item.id),
      onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      icon: const Icon(Symbols.more_vert),
    ),
  );
}

class _InspectionTile extends StatelessWidget {
  const _InspectionTile({
    required this.item,
    required this.now,
    required this.selected,
    required this.onTap,
    required this.onArchive,
    required this.onCopyLink,
    required this.showMenu,
  });

  final InspectionSummary item;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final VoidCallback onCopyLink;

  /// Pointer platforms get a menu; swipe still works on touch.
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tile = ListTile(
      selected: selected,
      selectedTileColor: scheme.secondaryContainer,
      shape: selected ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.medium)) : null,
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      minTileHeight: 72,
      onTap: onTap,
      leading: SiteThumb(inspection: item, heroTag: 'site-${item.id}'),
      title: Text(item.site, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${item.id} · ${localizedWhen(context, item.scheduledAt, now)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusChip(item.status, outlined: selected),
          if (showMenu) _RowMenu(item: item, onArchive: onArchive, onCopyLink: onCopyLink) else const SizedBox(width: 8),
        ],
      ),
    );
    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onArchive(),
      background: Container(
        color: scheme.tertiaryContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.archive, style: TextStyle(color: scheme.onTertiaryContainer)),
            const SizedBox(width: 8),
            Icon(Symbols.archive, color: scheme.onTertiaryContainer),
          ],
        ),
      ),
      child: Semantics(
        customSemanticsActions: {CustomSemanticsAction(label: context.l10n.archive): onArchive},
        child: tile,
      ),
    );
  }
}

/// D03: sortable data table with a row menu and "Load more".
class _InspectionsTable extends ConsumerWidget {
  const _InspectionsTable({
    required this.state,
    required this.query,
    required this.selectedId,
    required this.onOpen,
    required this.onArchive,
    required this.onCopyLink,
    required this.onLoadMore,
    required this.onRetryMore,
    required this.onSort,
  });

  final ListState state;
  final ListQuery query;
  final String? selectedId;
  final ValueChanged<InspectionSummary> onOpen;
  final ValueChanged<InspectionSummary> onArchive;
  final ValueChanged<InspectionSummary> onCopyLink;
  final VoidCallback onLoadMore;
  final VoidCallback onRetryMore;

  /// Goes through the screen's filter navigation, so an open detail stays open.
  final ValueChanged<SortOrder> onSort;

  static const _minWidth = 560.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();

    Widget header(String label, {double? width, int flex = 0, SortOrder? sort, IconData? arrow}) {
      final text = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          if (arrow != null) ...[const SizedBox(width: 4), Icon(arrow, size: 18)],
        ],
      );
      final cell = sort == null
          ? text
          : InkWell(
              onTap: () => onSort(sort),
              child: Semantics(button: true, label: context.l10n.sortByColumn(label), child: text),
            );
      return width != null
          ? SizedBox(
              width: width,
              child: Align(alignment: AlignmentDirectional.centerStart, child: cell),
            )
          : Expanded(flex: flex, child: cell);
    }

    final dueSorted = query.sort == SortOrder.dueAsc || query.sort == SortOrder.dueDesc;
    final table = Column(
      children: [
        Container(
          height: 44,
          color: theme.colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              header(context.l10n.columnId, width: 96),
              header(
                context.l10n.siteLabel,
                flex: 1,
                sort: SortOrder.siteAsc,
                arrow: query.sort == SortOrder.siteAsc ? Symbols.arrow_upward : null,
              ),
              header(
                context.l10n.due,
                width: 140,
                sort: query.sort == SortOrder.dueAsc ? SortOrder.dueDesc : SortOrder.dueAsc,
                arrow: dueSorted ? (query.sort == SortOrder.dueAsc ? Symbols.arrow_upward : Symbols.arrow_downward) : null,
              ),
              header(context.l10n.statusLabel, width: 140),
              const SizedBox(width: 56),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final item in state.items)
                Material(
                  color: item.id == selectedId ? theme.colorScheme.secondaryContainer : Colors.transparent,
                  child: Semantics(
                    button: true,
                    selected: item.id == selectedId,
                    child: InkWell(
                      onTap: () => onOpen(item),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 52),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 96,
                              child: Text(item.id, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                            ),
                            Expanded(
                              child: Text(item.site, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                            ),
                            // Wraps at large text rather than being cut off.
                            SizedBox(width: 140, child: Text(localizedWhen(context, item.scheduledAt, now))),
                            SizedBox(
                              width: 140,
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: StatusChip(item.status, outlined: item.id == selectedId),
                              ),
                            ),
                            SizedBox(
                              width: 56,
                              child: _RowMenu(item: item, onArchive: () => onArchive(item), onCopyLink: () => onCopyLink(item)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (state.moreError != null)
                _LoadMoreFailed(onRetry: onRetryMore)
              else if (state.hasMore || state.loadingMore)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: state.loadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton(onPressed: onLoadMore, child: Text(context.l10n.loadMore)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= _minWidth
          ? table
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: _minWidth, height: c.maxHeight, child: table),
            ),
    );
  }
}
