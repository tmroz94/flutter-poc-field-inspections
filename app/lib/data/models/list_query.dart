import 'package:flutter/foundation.dart';

import 'inspection.dart';

/// Labels are localized where they're shown (filter sheet, table headers).
enum SortOrder { dueAsc, dueDesc, siteAsc }

enum DueWindow { any, today, week, custom }

/// Inspections list filters. The URL query is the source of truth
/// (`/inspections?status=overdue,draft&sort=dueDesc&q=sub&due=week`), so a
/// filtered list can be shared, bookmarked and restored on refresh.
@immutable
class ListQuery {
  const ListQuery({this.statuses = const {}, this.q = '', this.sort = SortOrder.dueAsc, this.due = DueWindow.any, this.from, this.to});

  factory ListQuery.fromQuery(Map<String, String> p) {
    final statuses = {for (final s in (p['status'] ?? '').split(',')) ?InspectionStatus.values.asNameMap()[s.trim()]};
    return ListQuery(
      statuses: statuses,
      q: p['q']?.trim() ?? '',
      sort: SortOrder.values.asNameMap()[p['sort']] ?? SortOrder.dueAsc,
      due: DueWindow.values.asNameMap()[p['due']] ?? DueWindow.any,
      from: DateTime.tryParse(p['from'] ?? ''),
      to: DateTime.tryParse(p['to'] ?? ''),
    );
  }

  /// Empty means every status.
  final Set<InspectionStatus> statuses;
  final String q;
  final SortOrder sort;
  final DueWindow due;
  final DateTime? from;
  final DateTime? to;

  bool get isDefault => statuses.isEmpty && q.isEmpty && sort == SortOrder.dueAsc && due == DueWindow.any;

  /// Number of non-default filters, shown as the badge on the filter button.
  int get activeFilterCount => (statuses.isEmpty ? 0 : 1) + (sort == SortOrder.dueAsc ? 0 : 1) + (due == DueWindow.any ? 0 : 1);

  /// Single-status chip selection, as on P03 ("All" when none or several).
  InspectionStatus? get singleStatus => statuses.length == 1 ? statuses.first : null;

  ListQuery copyWith({
    Set<InspectionStatus>? statuses,
    String? q,
    SortOrder? sort,
    DueWindow? due,
    DateTime? Function()? from,
    DateTime? Function()? to,
  }) => ListQuery(
    statuses: statuses ?? this.statuses,
    q: q ?? this.q,
    sort: sort ?? this.sort,
    due: due ?? this.due,
    from: from != null ? from() : this.from,
    to: to != null ? to() : this.to,
  );

  /// Only non-default values, in a stable order, so equal filters give equal URLs.
  Map<String, String> toQuery() => {
    if (statuses.isNotEmpty) 'status': (statuses.map((s) => s.name).toList()..sort()).join(','),
    if (q.isNotEmpty) 'q': q,
    if (sort != SortOrder.dueAsc) 'sort': sort.name,
    if (due != DueWindow.any) 'due': due.name,
    if (due == DueWindow.custom && from != null) 'from': _date(from!),
    if (due == DueWindow.custom && to != null) 'to': _date(to!),
  };

  String toLocation(String path) {
    final q = toQuery();
    return q.isEmpty ? path : Uri(path: path, queryParameters: q).toString();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) => other is ListQuery && mapEquals(other.toQuery(), toQuery());

  @override
  int get hashCode => Object.hashAllUnordered(toQuery().entries.map((e) => '${e.key}=${e.value}'));

  @override
  String toString() => 'ListQuery(${toQuery()})';
}
