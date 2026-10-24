import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_exception.dart';
import '../../data/models/inspection.dart';
import '../../data/models/list_query.dart';
import '../../data/models/notification.dart';
import '../../data/providers.dart';

@immutable
class ListState {
  const ListState({
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.hasMore = false,
    this.loading = true,
    this.loadingMore = false,
    this.error,
  });

  final List<InspectionSummary> items;
  final int total;
  final int page;
  final bool hasMore;

  /// First page (or a full refresh) in flight with nothing to show yet.
  final bool loading;
  final bool loadingMore;
  final ApiException? error;

  bool get isEmpty => !loading && error == null && items.isEmpty;

  ListState copyWith({
    List<InspectionSummary>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    ApiException? Function()? error,
  }) => ListState(
    items: items ?? this.items,
    total: total ?? this.total,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error != null ? error() : this.error,
  );
}

/// One paged list per filter combination. Infinite scroll calls [loadMore];
/// pull-to-refresh and the Refresh button call [refresh].
class InspectionListController extends Notifier<ListState> {
  InspectionListController(this.query);

  static const pageSize = 20;

  final ListQuery query;

  /// Bumped on every refresh so late responses from older requests are ignored.
  int _generation = 0;

  @override
  ListState build() {
    Future.microtask(refresh);
    return const ListState();
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    state = state.copyWith(loading: state.items.isEmpty, error: () => null);
    try {
      final page = await ref.read(inspectionsRepositoryProvider).list(query, pageSize: pageSize);
      if (!ref.mounted || gen != _generation) return;
      state = ListState(items: page.items, total: page.total, page: 1, hasMore: page.hasMore, loading: false);
    } on ApiException catch (e) {
      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(loading: false, error: () => e);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final gen = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await ref.read(inspectionsRepositoryProvider).list(query, page: state.page + 1, pageSize: pageSize);
      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        page: page.page,
        hasMore: page.hasMore,
        total: page.total,
        loadingMore: false,
      );
    } on ApiException catch (e) {
      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(loadingMore: false, error: () => e);
    }
  }

  /// Removes the row at once (optimistic); puts it back if the server refuses.
  Future<void> archive(InspectionSummary item) async {
    final index = state.items.indexWhere((i) => i.id == item.id);
    if (index < 0) return;
    state = state.copyWith(items: [...state.items]..removeAt(index), total: state.total - 1);
    try {
      await ref.read(inspectionsRepositoryProvider).setArchived(item.id, archived: true);
    } on ApiException {
      if (ref.mounted) _insert(item, index);
      rethrow;
    }
  }

  Future<void> undoArchive(InspectionSummary item, int index) async {
    _insert(item, index);
    await ref.read(inspectionsRepositoryProvider).setArchived(item.id, archived: false);
  }

  void _insert(InspectionSummary item, int index) {
    if (state.items.any((i) => i.id == item.id)) return;
    state = state.copyWith(items: [...state.items]..insert(index.clamp(0, state.items.length), item), total: state.total + 1);
  }
}

final inspectionListProvider = NotifierProvider.autoDispose.family<InspectionListController, ListState, ListQuery>(
  InspectionListController.new,
);

/// Not-found and offline errors are final for the screen; don't auto-retry.
Duration? _noRetry(int count, Object error) => null;

final inspectionDetailProvider = FutureProvider.autoDispose.family<InspectionDetail, String>(
  (ref, id) => ref.watch(inspectionsRepositoryProvider).get(id),
  retry: _noRetry,
);

final checklistProvider = FutureProvider.family<List<ChecklistItem>, String>(
  (ref, templateId) => ref.watch(inspectionsRepositoryProvider).checklist(templateId),
  retry: _noRetry,
);

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) => ref.watch(inspectionsRepositoryProvider).notifications(),
  retry: _noRetry,
);

/// Open statuses shown on Home.
const openStatuses = {InspectionStatus.scheduled, InspectionStatus.inProgress, InspectionStatus.draft, InspectionStatus.overdue};

/// Home (P02/D02): today's inspections and what's due in the next 7 days.
final homeProvider = FutureProvider.autoDispose<({List<InspectionSummary> today, List<InspectionSummary> week, int openCount})>((
  ref,
) async {
  final repo = ref.watch(inspectionsRepositoryProvider);
  final today = await repo.list(const ListQuery(statuses: openStatuses, due: DueWindow.today), pageSize: 10);
  final open = await repo.list(const ListQuery(statuses: openStatuses), pageSize: 50);
  final now = DateTime.now();
  final weekEnd = DateTime(now.year, now.month, now.day + 7);
  final todayIds = today.items.map((i) => i.id).toSet();
  final week = open.items.where((i) => i.scheduledAt.isBefore(weekEnd) && !todayIds.contains(i.id)).take(5).toList();
  return (today: today.items, week: week, openCount: open.total);
}, retry: _noRetry);
