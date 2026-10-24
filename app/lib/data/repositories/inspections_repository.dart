import 'package:mock_data/mock_data.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/inspection.dart';
import '../models/list_query.dart';
import '../models/notification.dart';

abstract interface class InspectionsRepository {
  Future<PageResult<InspectionSummary>> list(ListQuery query, {int page = 1, int pageSize = 20});
  Future<InspectionDetail> get(String id);
  Future<void> setArchived(String id, {required bool archived});
  Future<List<ChecklistItem>> checklist(String templateId);
  Future<List<AppNotification>> notifications();
}

Map<String, Object?> _listParams(ListQuery q, int page, int pageSize) => {
  if (q.statuses.isNotEmpty) 'status': q.statuses.map((s) => s.name).join(','),
  if (q.q.isNotEmpty) 'q': q.q,
  'sort': q.sort.name,
  'due': q.due.name,
  if (q.from != null) 'from': q.from!.toIso8601String(),
  if (q.to != null) 'to': q.to!.toIso8601String(),
  'page': page,
  'pageSize': pageSize,
};

PageResult<InspectionSummary> _page(Map<String, Object?> json) => PageResult(
  items: [for (final i in json['items']! as List) InspectionSummary.fromJson((i as Map).cast<String, Object?>())],
  total: (json['total']! as num).toInt(),
  page: (json['page']! as num).toInt(),
  hasMore: json['hasMore'] == true,
);

Map<String, Object?> _map(Object? data) => (data! as Map).cast<String, Object?>();

class HttpInspectionsRepository implements InspectionsRepository {
  HttpInspectionsRepository(this._api);

  final ApiClient _api;

  @override
  Future<PageResult<InspectionSummary>> list(ListQuery query, {int page = 1, int pageSize = 20}) async =>
      _page(_map(await _api.get('/inspections', query: _listParams(query, page, pageSize))));

  @override
  Future<InspectionDetail> get(String id) async =>
      InspectionDetail.fromJson(_map(await _api.get('/inspections/${Uri.encodeComponent(id)}')));

  @override
  Future<void> setArchived(String id, {required bool archived}) =>
      _api.post('/inspections/${Uri.encodeComponent(id)}/${archived ? 'archive' : 'unarchive'}');

  @override
  Future<List<ChecklistItem>> checklist(String templateId) async {
    final json = _map(await _api.get('/checklist-templates/$templateId'));
    return [for (final i in json['items']! as List) ChecklistItem.fromJson((i as Map).cast<String, Object?>())];
  }

  @override
  Future<List<AppNotification>> notifications() async => [
    for (final n in (await _api.get('/notifications'))! as List) AppNotification.fromJson((n as Map).cast<String, Object?>()),
  ];
}

/// Offline fake over [MockDatabase] with simulated latency.
class FakeInspectionsRepository implements InspectionsRepository {
  FakeInspectionsRepository(this._db, {this.latency = const Duration(milliseconds: 400)});

  final MockDatabase _db;
  final Duration latency;

  Future<T> _run<T>(T Function() body) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    try {
      return body();
    } on MockError catch (e) {
      throw ApiException(e.status == 404 ? 'notFound' : e.code, status: e.status, fields: e.fields);
    }
  }

  @override
  Future<PageResult<InspectionSummary>> list(ListQuery query, {int page = 1, int pageSize = 20}) => _run(() {
    final p = _listParams(query, page, pageSize);
    return _page(
      _db.listInspections(
        status: query.statuses.isEmpty ? null : query.statuses.map((s) => s.name).toSet(),
        q: query.q,
        sort: p['sort']! as String,
        due: p['due']! as String,
        from: query.from,
        to: query.to,
        page: page,
        pageSize: pageSize,
      ),
    );
  });

  @override
  Future<InspectionDetail> get(String id) => _run(() => InspectionDetail.fromJson(_db.getInspection(id)));

  @override
  Future<void> setArchived(String id, {required bool archived}) => _run(() => _db.setArchived(id, archived));

  @override
  Future<List<ChecklistItem>> checklist(String templateId) => _run(
    () => [for (final i in _db.checklistTemplate(templateId)['items']! as List) ChecklistItem.fromJson((i as Map).cast<String, Object?>())],
  );

  @override
  Future<List<AppNotification>> notifications() => _run(() => [for (final n in _db.notifications()) AppNotification.fromJson(n)]);
}
