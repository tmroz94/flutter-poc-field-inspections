import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/layout/window_size.dart';
import '../../core/platform/capabilities.dart';
import '../../core/platform/platform_services.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/adaptive_segments.dart';
import '../../l10n/l10n.dart';
import 'results_model.dart';

enum _Filter { all, failing, notTested }

(IconData, Color, String) _look(ResultStatus s, ColorScheme c, AppLocalizations l) => switch (s) {
  ResultStatus.pass => (Symbols.check_circle, c.primary, l.resultPass),
  ResultStatus.partial => (Symbols.contrast, c.tertiary, l.resultPartial),
  ResultStatus.fail => (Symbols.cancel, c.error, l.resultFail),
  ResultStatus.notTested => (Symbols.radio_button_unchecked, c.onSurfaceVariant, l.resultNotTested),
  ResultStatus.na => (Symbols.block, c.onSurfaceVariant, l.resultNa),
};

class _StatusIcon extends StatelessWidget {
  const _StatusIcon(this.status, this.platform);

  final ResultStatus status;
  final PocPlatform platform;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _look(status, Theme.of(context).colorScheme, context.l10n);
    final filled = status != ResultStatus.notTested && status != ResultStatus.na;
    return Semantics(
      label: '${platform.label}: $label',
      excludeSemantics: true,
      child: Icon(icon, size: 22, color: color, fill: filled ? 1 : 0),
    );
  }
}

/// P21 (phone) and D05 (desktop): per-platform summary, filter, results by
/// scenario group. Rows open the edit sheet (P22); export CSV/JSON, import JSON.
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  _Filter _filter = _Filter.all;

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _export({required bool csv}) async {
    final s = ref.read(resultsProvider);
    final text = csv ? ResultsController.toCsv(s) : const JsonEncoder.withIndent('  ').convert(ResultsController.toJson(s));
    await ref
        .read(shareServiceProvider)
        .shareFile(
          bytes: utf8.encode(text),
          fileName: 'poc-results.${csv ? 'csv' : 'json'}',
          mime: csv ? 'text/csv' : 'application/json',
          caps: ref.read(capabilitiesProvider),
        );
  }

  Future<void> _import() async {
    final text = await ref.read(mediaServiceProvider).jsonText();
    if (text == null) return;
    try {
      ref.read(resultsProvider.notifier).importJson(text);
      _say('Results imported.');
    } on FormatException {
      _say('That file is not a PoC results export.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(resultsProvider);
    final wide = context.windowSize == WindowSize.large;
    final theme = Theme.of(context);
    final rows = state.results.where(
      (r) => switch (_filter) {
        _Filter.all => true,
        _Filter.failing => r.failing,
        _Filter.notTested => r.untested,
      },
    );
    final groups = <String, List<ScenarioResult>>{};
    for (final r in rows) {
      groups.putIfAbsent(r.group, () => []).add(r);
    }

    final datasetLabel = switch (state.dataset) {
      ResultsDataset.findings => 'Findings so far',
      ResultsDataset.sample => l.sampleData,
      ResultsDataset.blank => 'Blank',
      ResultsDataset.custom => 'Your results',
    };

    final menu = MenuAnchor(
      menuChildren: [
        MenuItemButton(leadingIcon: const Icon(Symbols.table), onPressed: () => _export(csv: true), child: const Text('Export CSV')),
        MenuItemButton(
          leadingIcon: const Icon(Symbols.data_object),
          onPressed: () => _export(csv: false),
          child: const Text('Export JSON'),
        ),
        MenuItemButton(leadingIcon: const Icon(Symbols.upload_file), onPressed: _import, child: Text(l.importResults)),
        const Divider(),
        MenuItemButton(
          onPressed: () => ref.read(resultsProvider.notifier).load(ResultsDataset.findings),
          child: const Text('Load findings so far'),
        ),
        MenuItemButton(
          onPressed: () => ref.read(resultsProvider.notifier).load(ResultsDataset.sample),
          child: const Text('Load design sample (D05)'),
        ),
        MenuItemButton(onPressed: () => ref.read(resultsProvider.notifier).load(ResultsDataset.blank), child: const Text('Start blank')),
      ],
      builder: (context, c, _) =>
          IconButton(tooltip: l.exportResults, onPressed: () => c.isOpen ? c.close() : c.open(), icon: const Icon(Symbols.ios_share)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.resultsTitle), actions: [menu]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // In the body, not the app bar: a badge there overflows at large text.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: theme.colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(AppRadii.small)),
                child: Text(datasetLabel, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onTertiaryContainer)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth >= 720
                    ? (c.maxWidth - 16) / 3
                    : c.maxWidth >= 360
                    ? (c.maxWidth - 16) / 3
                    : c.maxWidth;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in PocPlatform.values)
                      SizedBox(
                        width: w,
                        child: _PlatformCard(platform: p, state: state),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AdaptiveSegments<_Filter>(
              segments: [(_Filter.all, l.filterAll), (_Filter.failing, l.filterFailing), (_Filter.notTested, l.filterNotTested)],
              selected: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          const SizedBox(height: 8),
          if (wide) _ResultsTable(groups: groups) else ...[for (final g in groups.entries) _Group(name: g.key, rows: g.value)],
          const _Legend(),
        ],
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({required this.platform, required this.state});

  final PocPlatform platform;
  final ResultsState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final total = state.results.length;
    final segments = [
      (state.count(platform, ResultStatus.pass), c.primary),
      (state.count(platform, ResultStatus.partial), c.tertiary),
      (state.count(platform, ResultStatus.fail), c.error),
      (state.count(platform, ResultStatus.notTested) + state.count(platform, ResultStatus.na), c.outlineVariant),
    ];
    final icon = switch (platform) {
      PocPlatform.ios => Symbols.phone_iphone,
      PocPlatform.android => Symbols.android,
      PocPlatform.web => Symbols.language,
    };
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Flexible(child: Text(platform.label, style: theme.textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 4),
            Text(context.l10n.testedOf(state.tested(platform), total), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Semantics(
              label:
                  '${state.count(platform, ResultStatus.pass)} pass, ${state.count(platform, ResultStatus.partial)} partial, ${state.count(platform, ResultStatus.fail)} fail',
              excludeSemantics: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      for (final (n, color) in segments)
                        if (n > 0)
                          Expanded(
                            flex: n,
                            child: Container(color: color),
                          ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${state.count(platform, ResultStatus.fail)} fail · ${state.count(platform, ResultStatus.partial)} partial',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.name, required this.rows});

  final String name;
  final List<ScenarioResult> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(name, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                ),
              ),
              for (final p in PocPlatform.values)
                SizedBox(
                  width: 40,
                  child: Text(p == PocPlatform.android ? 'Andr.' : p.label, textAlign: TextAlign.center, style: theme.textTheme.labelSmall),
                ),
            ],
          ),
        ),
        for (final r in rows)
          InkWell(
            onTap: () => context.go(Routes.result(r.id)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(r.name)),
                    for (final p in PocPlatform.values) SizedBox(width: 40, child: _StatusIcon(r.of(p).status, p)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// D05: table with a notes column; horizontal scroll when narrow.
class _ResultsTable extends StatelessWidget {
  const _ResultsTable({required this.groups});

  final Map<String, List<ScenarioResult>> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // One note shared by every platform is shown once, without a prefix.
    String notes(ScenarioResult r) {
      final byPlatform = {
        for (final p in PocPlatform.values)
          if (r.of(p).notes.isNotEmpty) p: r.of(p).notes,
      };
      if ({...byPlatform.values}.length == 1) return byPlatform.values.first;
      return [for (final e in byPlatform.entries) '${e.key.label}: ${e.value}'].join(' · ');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FixedColumnWidth(80),
          2: FixedColumnWidth(80),
          3: FixedColumnWidth(80),
          4: FlexColumnWidth(3),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow),
            children: [
              for (final h in ['Scenario', 'iOS', 'Android', 'Web', context.l10n.notes])
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(h, style: theme.textTheme.labelLarge),
                ),
            ],
          ),
          for (final g in groups.entries) ...[
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
                  child: Text(g.key, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                ),
                for (var i = 0; i < 4; i++) const SizedBox.shrink(),
              ],
            ),
            for (final r in g.value)
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
                ),
                children: [
                  TableRowInkWell(
                    onTap: () => context.go(Routes.result(r.id)),
                    child: Padding(padding: const EdgeInsets.all(12), child: Text(r.name)),
                  ),
                  for (final p in PocPlatform.values) Center(child: _StatusIcon(r.of(p).status, p)),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(notes(r), style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(AppRadii.medium)),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          for (final s in ResultStatus.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_look(s, c, l).$1, size: 18, color: _look(s, c, l).$2, fill: s.isTested ? 1 : 0),
                const SizedBox(width: 4),
                Text(_look(s, c, l).$3),
              ],
            ),
        ],
      ),
    );
  }
}

/// P22: edit one scenario's result for a platform. Device is required unless
/// not tested or N/A; notes are required for Fail and Partial.
class ResultSheet extends ConsumerStatefulWidget {
  const ResultSheet({required this.featureId, super.key});

  final String featureId;

  @override
  ConsumerState<ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends ConsumerState<ResultSheet> {
  final _form = GlobalKey<FormState>();
  late PocPlatform _platform = ref.read(capabilitiesProvider).isWeb
      ? PocPlatform.web
      : (ref.read(capabilitiesProvider).platform == TargetPlatform.iOS ? PocPlatform.ios : PocPlatform.android);
  late final _device = TextEditingController();
  late final _notes = TextEditingController();
  ResultStatus _status = ResultStatus.notTested;

  ScenarioResult? get _row => ref.read(resultsProvider).results.where((r) => r.id == widget.featureId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _loadPlatform();
  }

  void _loadPlatform() {
    final r = _row?.of(_platform) ?? const PlatformResult();
    _status = r.status;
    _device.text = r.device;
    _notes.text = r.notes;
  }

  @override
  void dispose() {
    _device.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    ref
        .read(resultsProvider.notifier)
        .setResult(widget.featureId, _platform, PlatformResult(status: _status, device: _device.text.trim(), notes: _notes.text.trim()));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final row = _row;
    if (row == null) {
      return const Padding(padding: EdgeInsets.all(24), child: Text('Unknown scenario.'));
    }
    final needsDevice = _status.isTested;
    final needsNotes = _status == ResultStatus.fail || _status == ResultStatus.partial;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(row.group, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
              Text(row.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(l.platform, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              AdaptiveSegments<PocPlatform>(
                segments: [for (final p in PocPlatform.values) (p, p.label)],
                selected: _platform,
                onChanged: (v) => setState(() {
                  _platform = v;
                  _loadPlatform();
                }),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in ResultStatus.values)
                    ChoiceChip(
                      label: Text(_look(s, theme.colorScheme, l).$3),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _device,
                decoration: InputDecoration(labelText: l.device, helperText: needsDevice ? 'e.g. Pixel 8, Android 16' : 'Optional'),
                validator: (v) => needsDevice && (v == null || v.trim().isEmpty) ? 'Which device and version did you test on?' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: InputDecoration(labelText: l.notes, alignLabelWithHint: true),
                validator: (v) => needsNotes && (v == null || v.trim().isEmpty) ? 'Describe what failed or only partly worked' : null,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => context.pop(), child: Text(l.cancel)),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: Text(l.save)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
