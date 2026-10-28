import 'package:flutter/foundation.dart';
import 'package:mock_data/mock_data.dart';
import 'package:mock_data/mock_data.dart' as mock show inspectionTypes;

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
  Future<void> markNotificationsRead({String? id});
  Future<void> deleteNotification(String id);
  Future<List<SiteOption>> searchSites(String query);
  Future<List<String>> inspectionTypes();

  /// Creates (no [id]) or updates an inspection; [submit] marks it submitted.
  /// [requestKey] makes a create safe to retry: the server returns the
  /// inspection that key already created (`Idempotency-Key`).
  /// Throws [ApiException] `validation` with field codes, or `network`.
  Future<InspectionDetail> save(Map<String, Object?> body, {String? id, bool submit = false, String? requestKey});
}

/// A site suggestion for the wizard's autocomplete (P09).
class SiteOption {
  const SiteOption({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.icon,
    this.lat,
    this.lng,
  });

  factory SiteOption.fromJson(Map<String, Object?> j) => SiteOption(
    id: j['id']! as String,
    name: j['name']! as String,
    address: j['address'] as String? ?? '',
    city: j['city'] as String? ?? '',
    icon: j['icon'] as String? ?? 'location_on',
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
  );

  final String id;
  final String name;
  final String address;
  final String city;
  final String icon;
  final double? lat;
  final double? lng;
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

/// Reads a successful answer with [read]. One the app can't read (a captive
/// portal's HTML page, a changed shape) fails like any other call, as
/// [ApiException] `unknown`, so screens show their error state instead of
/// waiting forever.
Future<T> _read<T>(Future<Object?> call, T Function(Object? data) read) async {
  final data = await call;
  try {
    return read(data);
  } on Object catch (e) {
    debugPrint('Unreadable answer: $e');
    throw const ApiException('unknown');
  }
}

class HttpInspectionsRepository implements InspectionsRepository {
  HttpInspectionsRepository(this._api);

  final ApiClient _api;

  @override
  Future<PageResult<InspectionSummary>> list(ListQuery query, {int page = 1, int pageSize = 20}) =>
      _read(_api.get('/inspections', query: _listParams(query, page, pageSize)), (d) => _page(_map(d)));

  @override
  Future<InspectionDetail> get(String id) =>
      _read(_api.get('/inspections/${Uri.encodeComponent(id)}'), (d) => InspectionDetail.fromJson(_map(d)));

  @override
  Future<void> setArchived(String id, {required bool archived}) =>
      _api.post('/inspections/${Uri.encodeComponent(id)}/${archived ? 'archive' : 'unarchive'}');

  @override
  Future<List<ChecklistItem>> checklist(String templateId) => _read(
    _api.get('/checklist-templates/${Uri.encodeComponent(templateId)}'),
    (d) => [for (final i in _map(d)['items']! as List) ChecklistItem.fromJson((i as Map).cast<String, Object?>())],
  );

  @override
  Future<List<AppNotification>> notifications() =>
      _read(_api.get('/notifications'), (d) => [for (final n in d! as List) AppNotification.fromJson((n as Map).cast<String, Object?>())]);

  @override
  Future<void> markNotificationsRead({String? id}) => _api.post('/notifications/read', body: {'id': ?id});

  @override
  Future<void> deleteNotification(String id) => _api.delete('/notifications/${Uri.encodeComponent(id)}');

  @override
  Future<List<SiteOption>> searchSites(String query) => _read(
    _api.get('/sites', query: {'q': query}),
    (d) => [for (final s in d! as List) SiteOption.fromJson((s as Map).cast<String, Object?>())],
  );

  @override
  Future<List<String>> inspectionTypes() => _read(_api.get('/inspection-types'), (d) => [for (final t in d! as List) t as String]);

  @override
  Future<InspectionDetail> save(Map<String, Object?> body, {String? id, bool submit = false, String? requestKey}) {
    final query = {'submit': '$submit'};
    final call = id == null
        ? _api.post('/inspections', body: body, query: query, headers: {'Idempotency-Key': ?requestKey})
        : _api.put('/inspections/${Uri.encodeComponent(id)}', body: body, query: query);
    return _read(call, (d) => InspectionDetail.fromJson(_map(d)));
  }
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

  @override
  Future<void> markNotificationsRead({String? id}) => _run(() => _db.markNotificationsRead(id: id));

  @override
  Future<void> deleteNotification(String id) => _run(() => _db.deleteNotification(id));

  @override
  Future<List<SiteOption>> searchSites(String query) => _run(() => [for (final s in _db.searchSites(query)) SiteOption.fromJson(s)]);

  @override
  Future<List<String>> inspectionTypes() => _run(() => List.of(mock.inspectionTypes));

  @override
  Future<InspectionDetail> save(Map<String, Object?> body, {String? id, bool submit = false, String? requestKey}) => _run(
    () => InspectionDetail.fromJson(
      id == null ? _db.createInspection(body, submit: submit, requestKey: requestKey) : _db.updateInspection(id, body, submit: submit),
    ),
  );
}
