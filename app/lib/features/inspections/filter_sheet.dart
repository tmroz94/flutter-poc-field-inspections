import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/routes.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/inspection.dart';
import '../../data/models/list_query.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';

/// P05: filter and sort as a bottom sheet with its own URL
/// (`/inspections/filter?…`). Applying goes to `/inspections?…`, which also
/// closes the sheet; back, Esc or the scrim close it without changes.
class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({required this.query, super.key});

  final Map<String, String> query;

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late ListQuery _draft = ListQuery.fromQuery(widget.query);

  /// Checkbox state: an empty filter means every status is ticked.
  late Set<InspectionStatus> _checked = _draft.statuses.isEmpty ? InspectionStatus.values.toSet() : {..._draft.statuses};
  int? _count;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _recount();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  ListQuery get _result => _draft.copyWith(statuses: _checked.length == InspectionStatus.values.length ? {} : _checked);

  bool get _rangeInvalid =>
      _draft.due == DueWindow.custom && (_draft.from == null || _draft.to == null || _draft.to!.isBefore(_draft.from!));

  bool get _canApply => _checked.isNotEmpty && !_rangeInvalid;

  void _change(void Function() update) {
    setState(update);
    _recount();
  }

  void _recount() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      if (!_canApply) {
        if (mounted) setState(() => _count = null);
        return;
      }
      try {
        final page = await ref.read(inspectionsRepositoryProvider).list(_result, pageSize: 1);
        if (mounted) setState(() => _count = page.total);
      } on ApiException {
        if (mounted) setState(() => _count = null);
      }
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _draft.from != null && _draft.to != null ? DateTimeRange(start: _draft.from!, end: _draft.to!) : null,
    );
    if (picked != null) _change(() => _draft = _draft.copyWith(from: () => picked.start, to: () => picked.end));
  }

  void _reset() => _change(() {
    _draft = const ListQuery().copyWith(q: _draft.q);
    _checked = InspectionStatus.values.toSet();
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final dateFmt = DateFormat.yMMMd();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(header: true, child: Text('Filter and sort', style: theme.textTheme.titleLarge)),
                ),
                TextButton(onPressed: _reset, child: Text(context.l10n.reset)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
              child: Text('Status', style: label),
            ),
            Wrap(
              children: [
                for (final s in InspectionStatus.values)
                  SizedBox(
                    width: 180,
                    child: CheckboxListTile(
                      value: _checked.contains(s),
                      title: Text(s.localized(context.l10n)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => _change(() => v! ? _checked.add(s) : _checked.remove(s)),
                    ),
                  ),
              ],
            ),
            if (_checked.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(context.l10n.selectAtLeastOneStatus, style: TextStyle(color: theme.colorScheme.error)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: Text('Due', style: label),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SegmentedButton<DueWindow>(
                segments: [
                  for (final d in DueWindow.values)
                    ButtonSegment(
                      value: d,
                      label: Text(switch (d) {
                        DueWindow.any => context.l10n.dueAny,
                        DueWindow.today => context.l10n.dueToday,
                        DueWindow.week => context.l10n.dueWeek,
                        DueWindow.custom => context.l10n.dueCustom,
                      }),
                    ),
                ],
                selected: {_draft.due},
                onSelectionChanged: (s) {
                  _change(() => _draft = _draft.copyWith(due: s.first));
                  if (s.first == DueWindow.custom && _draft.from == null) _pickRange();
                },
              ),
            ),
            if (_draft.due == DueWindow.custom)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Symbols.date_range),
                  label: Text(
                    _draft.from == null || _draft.to == null
                        ? 'Choose dates'
                        : '${dateFmt.format(_draft.from!)} – ${dateFmt.format(_draft.to!)}',
                  ),
                ),
              ),
            if (_draft.due == DueWindow.custom && _rangeInvalid && _draft.from != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Text('The end date must be on or after the start date', style: TextStyle(color: theme.colorScheme.error)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 4),
              child: Text('Sort by', style: label),
            ),
            RadioGroup<SortOrder>(
              groupValue: _draft.sort,
              onChanged: (v) => _change(() => _draft = _draft.copyWith(sort: v)),
              child: Column(
                children: [
                  for (final s in SortOrder.values)
                    RadioListTile<SortOrder>(
                      value: s,
                      contentPadding: EdgeInsets.zero,
                      title: Text(switch (s) {
                        SortOrder.dueAsc => context.l10n.sortDueAsc,
                        SortOrder.dueDesc => context.l10n.sortDueDesc,
                        SortOrder.siteAsc => context.l10n.sortSiteAsc,
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _canApply ? () => context.go(_result.toLocation(Routes.inspections)) : null,
                child: Text(switch (_count) {
                  null => context.l10n.showResultsPlain,
                  final n => context.l10n.showResults(n),
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
