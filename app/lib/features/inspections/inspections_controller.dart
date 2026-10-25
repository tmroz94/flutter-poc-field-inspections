import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';
import '../../core/widgets/inspection_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/inspection.dart';
import '../../data/models/list_query.dart';
import '../../data/models/notification.dart';
import '../../data/providers.dart';
import '../../data/repositories/inspections_repository.dart';

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
    this.moreError,
  });

  final List<InspectionSummary> items;
  final int total;
  final int page;
  final bool hasMore;

  /// First page (or a full refresh) in flight with nothing to show yet.
  final bool loading;
  final bool loadingMore;

  /// The first page failed.
  final ApiException? error;

  /// The next page failed; paging waits for [InspectionListController.retryMore].
  final ApiException? moreError;

  bool get isEmpty => !loading && error == null && items.isEmpty;

  ListState copyWith({
    List<InspectionSummary>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    ApiException? Function()? error,
    ApiException? Function()? moreError,
  }) => ListState(
    items: items ?? this.items,
    total: total ?? this.total,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error != null ? error() : this.error,
    moreError: moreError != null ? moreError() : this.moreError,
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
  bool _refreshing = false;

  // Read once: archive undo can outlive this list (the user changed the filter).
  late InspectionsRepository _repo;
  late InspectionsRevision _revision;

  @override
  ListState build() {
    _repo = ref.read(inspectionsRepositoryProvider);
    _revision = ref.read(inspectionsRevisionProvider.notifier);
    Future.microtask(refresh);
    return const ListState();
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    _refreshing = true;
    // A page that was loading belongs to the old list; its answer is dropped (generation).
    state = state.copyWith(loading: state.items.isEmpty, loadingMore: false, error: () => null, moreError: () => null);
    try {
      final page = await _repo.list(query, pageSize: pageSize);
      if (!ref.mounted || gen != _generation) return;
      state = ListState(items: page.items, total: page.total, page: 1, hasMore: page.hasMore, loading: false);
    } on ApiException catch (e) {
      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(loading: false, error: () => e);
    } finally {
      if (gen == _generation) _refreshing = false;
    }
  }

  /// Loads the next page. Not while a refresh runs (its page 1 would get the
  /// old list's next page appended), and not again after a failure until
  /// [retryMore], so an offline list doesn't keep firing requests.
  Future<void> loadMore() async {
    if (_refreshing || state.loading || state.loadingMore || !state.hasMore || state.moreError != null) return;
    final gen = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.list(query, page: state.page + 1, pageSize: pageSize);
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
      state = state.copyWith(loadingMore: false, moreError: () => e);
    }
  }

  Future<void> retryMore() async {
    state = state.copyWith(moreError: () => null);
    await loadMore();
  }

  /// Removes the row at once (optimistic); puts it back if the server refuses.
  Future<void> archive(InspectionSummary item) async {
    final index = state.items.indexWhere((i) => i.id == item.id);
    if (index < 0) return;
    _remove(item);
    try {
      await _repo.setArchived(item.id, archived: true);
      _revision.changed(lists: false);
    } on ApiException {
      if (ref.mounted) _insert(item, index);
      rethrow;
    }
  }

  /// Undo from the snackbar. This list may be gone by then (another filter),
  /// so it only touches its own rows while still mounted; otherwise the
  /// other lists reload. Throws [ApiException] if the server refuses.
  Future<void> undoArchive(InspectionSummary item, int index) async {
    if (ref.mounted) _insert(item, index);
    try {
      await _repo.setArchived(item.id, archived: false);
      _revision.changed(lists: !ref.mounted);
    } on ApiException {
      if (ref.mounted) _remove(item);
      rethrow;
    }
  }

  void _remove(InspectionSummary item) {
    if (!state.items.any((i) => i.id == item.id)) return;
    state = state.copyWith(items: state.items.where((i) => i.id != item.id).toList(), total: state.total - 1);
  }

  void _insert(InspectionSummary item, int index) {
    if (state.items.any((i) => i.id == item.id)) return;
    state = state.copyWith(items: [...state.items]..insert(index.clamp(0, state.items.length), item), total: state.total + 1);
  }
}

final inspectionListProvider = NotifierProvider.autoDispose.family<InspectionListController, ListState, ListQuery>(
  InspectionListController.new,
);

/// Bumped whenever this app changes inspections on the server (submit, sync,
/// archive), so Home reloads and reminders reschedule.
class InspectionsRevision extends Notifier<int> {
  @override
  int build() => 0;

  /// [lists]: also reload every inspections list (archive updates its own list in place).
  void changed({bool lists = true}) {
    if (lists) ref.invalidate(inspectionListProvider);
    ref
      ..invalidate(inspectionDetailProvider)
      ..invalidate(homeProvider);
    state++;
  }
}

final inspectionsRevisionProvider = NotifierProvider<InspectionsRevision, int>(InspectionsRevision.new);

/// Not-found and offline errors are final for the screen; don't auto-retry.
Duration? _noRetry(int count, Object error) => null;

final inspectionDetailProvider = FutureProvider.autoDispose.family<InspectionDetail, String>(
  (ref, id) => ref.watch(inspectionsRepositoryProvider).get(id),
  retry: _noRetry,
);

/// Reference data the wizard needs offline: the last copy that loaded is kept
/// on the device and used when the server can't be reached. A result stays
/// for the session; a failure doesn't (the next read tries again).
Future<T> _cachedReference<T>(
  Ref ref,
  String key,
  Future<T> Function() load,
  T Function(Object? json) parse,
  Object? Function(T v) toJson,
) async {
  final keepAlive = ref.keepAlive();
  final store = ref.read(keyValueStoreProvider);
  try {
    final value = await load();
    await store.setString(key, jsonEncode(toJson(value)));
    return value;
  } on ApiException catch (e) {
    final cached = store.getString(key);
    if (e.isNetwork && cached != null) {
      try {
        return parse(jsonDecode(cached));
      } on Object {
        // A cache from an older format: report the network error instead.
      }
    }
    keepAlive.close();
    rethrow;
  } on Object {
    keepAlive.close();
    rethrow;
  }
}

final checklistProvider = FutureProvider.autoDispose.family<List<ChecklistItem>, String>(
  (ref, templateId) => _cachedReference(
    ref,
    'cache.checklist.$templateId',
    () => ref.watch(inspectionsRepositoryProvider).checklist(templateId),
    (json) => [for (final i in json! as List) ChecklistItem.fromJson((i as Map).cast<String, Object?>())],
    (items) => [for (final i in items) i.toJson()],
  ),
  retry: _noRetry,
);

/// Types offered in wizard step 2.
final inspectionTypesProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => _cachedReference(
    ref,
    'cache.inspectionTypes',
    () => ref.watch(inspectionsRepositoryProvider).inspectionTypes(),
    (json) => [for (final t in json! as List) t as String],
    (types) => types,
  ),
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
  final now = ref.read(clockProvider)();
  final weekEnd = DateTime(now.year, now.month, now.day + 7);
  final todayIds = today.items.map((i) => i.id).toSet();
  final week = open.items.where((i) => i.scheduledAt.isBefore(weekEnd) && !todayIds.contains(i.id)).take(5).toList();
  return (today: today.items, week: week, openCount: open.total);
}, retry: _noRetry);
