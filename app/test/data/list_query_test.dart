import 'package:field_inspections/data/models/inspection.dart';
import 'package:field_inspections/data/models/list_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the URL query and ignores unknown values', () {
    final q = ListQuery.fromQuery({'status': 'overdue,bogus,draft', 'q': ' sub ', 'sort': 'dueDesc', 'due': 'nope', 'tab': 'photos'});
    expect(q.statuses, {InspectionStatus.overdue, InspectionStatus.draft});
    expect(q.q, 'sub');
    expect(q.sort, SortOrder.dueDesc);
    expect(q.due, DueWindow.any);
  });

  test('writes only non-default values, in a stable order', () {
    expect(const ListQuery().toQuery(), isEmpty);
    expect(const ListQuery().toLocation('/inspections'), '/inspections');
    const q = ListQuery(statuses: {InspectionStatus.overdue, InspectionStatus.draft}, q: 'boiler', due: DueWindow.week);
    expect(q.toQuery(), {'status': 'draft,overdue', 'q': 'boiler', 'due': 'week'});
    expect(q.toLocation('/inspections'), '/inspections?status=draft%2Coverdue&q=boiler&due=week');
  });

  test('round-trips through the URL', () {
    final q = ListQuery(
      statuses: const {InspectionStatus.scheduled},
      sort: SortOrder.siteAsc,
      due: DueWindow.custom,
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
    );
    expect(ListQuery.fromQuery(q.toQuery()), q);
  });

  test('custom dates are dropped unless the window is custom', () {
    final q = ListQuery(due: DueWindow.week, from: DateTime(2026));
    expect(q.toQuery().containsKey('from'), isFalse);
  });

  test('equality ignores set order; active filter count', () {
    const a = ListQuery(statuses: {InspectionStatus.draft, InspectionStatus.overdue});
    const b = ListQuery(statuses: {InspectionStatus.overdue, InspectionStatus.draft});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.activeFilterCount, 1);
    expect(const ListQuery(q: 'x').activeFilterCount, 0, reason: 'search is shown in the field, not the badge');
    expect(const ListQuery(sort: SortOrder.dueDesc, due: DueWindow.today).activeFilterCount, 2);
  });
}
