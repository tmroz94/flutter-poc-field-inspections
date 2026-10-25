import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/platform/capabilities.dart';
import '../../core/platform/platform_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validation/form_support.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/inspection_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/local/local_store.dart';
import '../../data/models/draft.dart';
import '../../data/models/inspection.dart';
import '../../data/providers.dart';
import '../../data/repositories/inspections_repository.dart';
import '../../data/sync/sync_service.dart';
import '../../l10n/l10n.dart';
import '../inspections/inspection_detail_screen.dart' show PhotoPlaceholder;
import '../inspections/inspections_controller.dart';
import 'wizard_controller.dart';
import 'wizard_screen.dart';
import 'wizard_validation.dart';

/// Body of one wizard step. [errors] is empty until Next was tried on it.
class WizardStepView extends ConsumerWidget {
  const WizardStepView({
    required this.step,
    required this.wizardKey,
    required this.errors,
    required this.onEditStep,
    required this.onSubmit,
    super.key,
  });

  final WizardStep step;
  final String wizardKey;
  final Map<String, String> errors;
  final ValueChanged<int> onEditStep;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (step) {
    WizardStep.site => _SiteStep(wizardKey: wizardKey, errors: errors),
    WizardStep.details => _DetailsStep(wizardKey: wizardKey, errors: errors),
    WizardStep.checklist => _ChecklistStep(wizardKey: wizardKey, errors: errors),
    WizardStep.photos => _PhotosStep(wizardKey: wizardKey, errors: errors),
    WizardStep.review => _ReviewStep(wizardKey: wizardKey, onEditStep: onEditStep, onSubmit: onSubmit),
  };
}

// ---------------------------------------------------------------- Step 1: Site

sealed class _SiteChoice {}

class _Existing extends _SiteChoice {
  _Existing(this.site);
  final SiteOption site;
}

class _AddNew extends _SiteChoice {
  _AddNew(this.name);
  final String name;
}

class _SiteStep extends ConsumerStatefulWidget {
  const _SiteStep({required this.wizardKey, required this.errors});

  final String wizardKey;
  final Map<String, String> errors;

  @override
  ConsumerState<_SiteStep> createState() => _SiteStepState();
}

class _SiteStepState extends ConsumerState<_SiteStep> {
  late final _controller = TextEditingController(text: ref.read(wizardControllerProvider(widget.wizardKey)).draft.siteName);
  final _focus = FocusNode();
  Timer? _debounce;

  /// Suggestions shown inline under the field (not in an overlay: on the web,
  /// with the accessibility tree on, an overlay opening took focus from the
  /// field and closed itself, so screen-reader users couldn't pick a site).
  List<_SiteChoice> _choices = const [];
  int _highlighted = 0;
  int _lookup = 0;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _choices.isNotEmpty) setState(() => _choices = const []);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Debounced lookup (250 ms): only the last keystroke hits the API.
  void _search(String text) {
    final q = text.trim();
    _debounce?.cancel();
    final lookup = ++_lookup;
    if (q.isEmpty) {
      setState(() => _choices = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      List<_SiteChoice> found;
      try {
        final sites = await ref.read(inspectionsRepositoryProvider).searchSites(q);
        final exact = sites.any((s) => s.name.toLowerCase() == q.toLowerCase());
        found = [for (final s in sites) _Existing(s), if (!exact && q.length >= 3) _AddNew(q)];
      } on ApiException {
        found = [if (q.length >= 3) _AddNew(q)];
      }
      if (!mounted || lookup != _lookup || !_focus.hasFocus) return;
      setState(() {
        _choices = found;
        _highlighted = 0;
      });
    });
  }

  /// Arrow keys move through the suggestions, Enter picks, Escape closes.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_choices.isEmpty || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      setState(() => _highlighted = (_highlighted + step) % _choices.length);
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _select(_choices[_highlighted]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _choices = const []);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _select(_SiteChoice c) {
    _lookup++;
    _debounce?.cancel();
    setState(() => _choices = const []);
    final wizard = ref.read(wizardControllerProvider(widget.wizardKey).notifier);
    switch (c) {
      case _Existing(:final site):
        _controller.text = site.name;
        wizard.update(
          (d) => d.copyWith(
            siteId: () => site.id,
            siteName: site.name,
            siteAddress: '${site.address}, ${site.city}',
            siteLat: () => site.lat,
            siteLng: () => site.lng,
          ),
        );
      case _AddNew(:final name):
        _controller.text = name;
        wizard.update((d) => d.copyWith(siteId: () => null, siteName: name, siteAddress: ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(wizardControllerProvider(widget.wizardKey)).draft;
    final theme = Theme.of(context);
    // One tap region with the field, so tapping a suggestion doesn't count as
    // a tap outside (which would unfocus the field and close the list first).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFieldTapRegion(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                onKeyEvent: _onKey,
                canRequestFocus: false,
                skipTraversal: true,
                child: TextFormField(
                  controller: _controller,
                  focusNode: _focus,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) {
                    if (_choices.isNotEmpty) _select(_choices[_highlighted]);
                  },
                  onChanged: (text) {
                    ref
                        .read(wizardControllerProvider(widget.wizardKey).notifier)
                        .update((d) => d.copyWith(siteId: () => null, siteName: text, siteAddress: ''));
                    _search(text);
                  },
                  decoration: InputDecoration(
                    labelText: 'Site',
                    prefixIcon: const Icon(Symbols.search),
                    helperText: 'Search by name or address',
                    errorText: widget.errors['site'],
                    suffixIcon: ListenableBuilder(
                      listenable: _controller,
                      builder: (_, _) => _controller.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Symbols.cancel),
                              onPressed: () {
                                _controller.clear();
                                _search('');
                                ref
                                    .read(wizardControllerProvider(widget.wizardKey).notifier)
                                    .update((d) => d.copyWith(siteId: () => null, siteName: '', siteAddress: ''));
                              },
                            ),
                    ),
                  ),
                ),
              ),
              if (_choices.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _SiteOptions(query: _controller.text, options: _choices, highlighted: _highlighted, onSelected: _select),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (draft.siteId != null)
          Card.outlined(
            child: ListTile(
              leading: Icon(Symbols.check_circle, fill: 1, color: theme.colorScheme.primary),
              title: Text(draft.siteName),
              subtitle: Text(draft.siteAddress),
            ),
          )
        else if (draft.hasSite)
          Card.outlined(
            child: ListTile(
              leading: Icon(Symbols.add_location_alt, color: theme.colorScheme.primary),
              title: Text('New site: ${draft.siteName.trim()}'),
              subtitle: const Text('It will be created when you submit'),
            ),
          ),
        const SizedBox(height: 24),
        Text('Your location', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        _LocationCheck(wizardKey: widget.wizardKey),
      ],
    );
  }
}

/// P09 "Your location": optional on-site check with accuracy and the
/// distance to the site; warns when more than 200 m away.
class _LocationCheck extends ConsumerStatefulWidget {
  const _LocationCheck({required this.wizardKey});

  final String wizardKey;

  @override
  ConsumerState<_LocationCheck> createState() => _LocationCheckState();
}

class _LocationCheckState extends ConsumerState<_LocationCheck> {
  bool _busy = false;
  String? _problem;
  bool _canOpenSettings = false;

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final fix = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _canOpenSettings = fix.status == LocationStatus.deniedForever && ref.read(capabilitiesProvider).openSystemSettings;
      _problem = switch (fix.status) {
        LocationStatus.ok => null,
        LocationStatus.serviceOff => 'Location is turned off on this device.',
        LocationStatus.denied => 'Location permission was not given. The check is optional.',
        LocationStatus.deniedForever => 'Location is blocked for this app.',
        LocationStatus.unsupported => 'Location is not available here.',
        LocationStatus.error => "Couldn't get a position. Try again outside or near a window.",
      };
    });
    if (fix.status == LocationStatus.ok) {
      ref
          .read(wizardControllerProvider(widget.wizardKey).notifier)
          .update((d) => d.copyWith(myLocation: () => (lat: fix.lat!, lng: fix.lng!, accuracy: fix.accuracy ?? 0)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(wizardControllerProvider(widget.wizardKey)).draft;
    final theme = Theme.of(context);
    final fix = d.myLat == null ? null : LocationFix(LocationStatus.ok, lat: d.myLat, lng: d.myLng, accuracy: d.myAccuracy);
    final distance = fix?.distanceTo(d.siteLat, d.siteLng);
    final far = distance != null && distance > 200;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Symbols.my_location, color: theme.colorScheme.primary),
              title: Text(fix == null ? 'Not checked yet' : '${fix.lat!.toStringAsFixed(4)}° N, ${fix.lng!.toStringAsFixed(4)}° E'),
              subtitle: Text(
                fix == null
                    ? 'Optional: confirms you are on site.'
                    : [
                        'Accuracy ±${fix.accuracy?.round() ?? '?'} m',
                        if (distance != null)
                          '${distance >= 1000 ? '${(distance / 1000).toStringAsFixed(1)} km' : '${distance.round()} m'} from the site',
                      ].join(' · '),
              ),
            ),
            if (far) Text('You seem to be more than 200 m from the site address.', style: TextStyle(color: theme.colorScheme.tertiary)),
            if (_problem != null) Text(_problem!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _update,
                  icon: _busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Symbols.refresh),
                  label: Text(fix == null ? 'Check location' : 'Update location'),
                ),
                if (_canOpenSettings)
                  TextButton(onPressed: () => ref.read(permissionServiceProvider).openSettings(), child: Text(context.l10n.openSettings)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteOptions extends StatelessWidget {
  const _SiteOptions({required this.query, required this.options, required this.highlighted, required this.onSelected});

  final String query;
  final List<_SiteChoice> options;
  final int highlighted;
  final ValueChanged<_SiteChoice> onSelected;

  /// Bold the typed text inside a suggestion, as on P09.
  Widget _highlight(BuildContext context, String text) {
    final q = query.trim().toLowerCase();
    final i = text.toLowerCase().indexOf(q);
    if (q.isEmpty || i < 0) return Text(text);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, i)),
          TextSpan(
            text: text.substring(i, i + q.length),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: text.substring(i + q.length)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(AppRadii.extraSmall),
        color: theme.colorScheme.surfaceContainer,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320, maxWidth: 560),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, i) {
              final o = options[i];
              return ListTile(
                selected: i == highlighted,
                selectedTileColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                onTap: () => onSelected(o),
                leading: switch (o) {
                  _Existing(:final site) => Icon(siteIcon(site.icon)),
                  _AddNew() => Icon(Symbols.add_location_alt, color: theme.colorScheme.primary),
                },
                title: switch (o) {
                  _Existing(:final site) => _highlight(context, site.name),
                  _AddNew(:final name) => Text('Add “$name” as a new site', style: TextStyle(color: theme.colorScheme.primary)),
                },
                subtitle: switch (o) {
                  _Existing(:final site) => Text('${site.address}, ${site.city}'),
                  _AddNew() => null,
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Step 2: Details

class _DetailsStep extends ConsumerStatefulWidget {
  const _DetailsStep({required this.wizardKey, required this.errors});

  final String wizardKey;
  final Map<String, String> errors;

  @override
  ConsumerState<_DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends ConsumerState<_DetailsStep> {
  late final InspectionDraft _initial = ref.read(wizardControllerProvider(widget.wizardKey)).draft;
  late final _duration = TextEditingController(text: _initial.duration);
  late final _notes = TextEditingController(text: _initial.notes);
  final _durationFocus = FocusNode();
  final _notesFocus = FocusNode();

  @override
  void dispose() {
    _duration.dispose();
    _notes.dispose();
    _durationFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  WizardController get _wizard => ref.read(wizardControllerProvider(widget.wizardKey).notifier);

  Future<void> _pickDate(InspectionDraft d) async {
    final today = ref.read(clockProvider)();
    final first = d.inspectionId == null ? DateTime(today.year, today.month, today.day) : DateTime(today.year - 1);
    final initial = d.date != null && !d.date!.isBefore(first) ? d.date! : first;
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDate: initial,
    );
    if (picked != null) _wizard.update((x) => x.copyWith(date: () => picked));
  }

  Future<void> _pickTime(InspectionDraft d) async {
    final m = d.startMinutes ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked != null) _wizard.update((x) => x.copyWith(startMinutes: () => picked.hour * 60 + picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(wizardControllerProvider(widget.wizardKey)).draft;
    final types = ref.watch(inspectionTypesProvider).value ?? const <String>[];
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateText = d.date == null ? '' : DateFormat.yMMMEd(locale).format(d.date!);
    final timeText = d.startMinutes == null
        ? ''
        : '${(d.startMinutes! ~/ 60).toString().padLeft(2, '0')}:${(d.startMinutes! % 60).toString().padLeft(2, '0')}';
    final e = widget.errors;

    Widget pair(Widget a, Widget b) => LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 520
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: a),
                const SizedBox(width: 12),
                Expanded(child: b),
              ],
            )
          : Column(children: [a, const SizedBox(height: 20), b]),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) => DropdownMenu<String>(
            width: c.maxWidth,
            initialSelection: d.type,
            label: const Text('Inspection type'),
            errorText: e['type'],
            dropdownMenuEntries: [for (final t in types) DropdownMenuEntry(value: t, label: t)],
            onSelected: (t) => _wizard.update((x) => x.copyWith(type: () => t)),
          ),
        ),
        const SizedBox(height: 20),
        pair(
          _PickerField(
            label: 'Date',
            value: dateText,
            error: e['date'],
            icon: Symbols.calendar_today,
            tooltip: 'Open calendar',
            onTap: () => _pickDate(d),
          ),
          _PickerField(
            label: 'Start time',
            value: timeText,
            error: e['time'],
            icon: Symbols.schedule,
            tooltip: 'Open time picker',
            onTap: () => _pickTime(d),
          ),
        ),
        const SizedBox(height: 20),
        Text('Priority', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        SegmentedButton<Priority>(
          segments: const [
            ButtonSegment(value: Priority.low, label: Text('Low')),
            ButtonSegment(value: Priority.normal, label: Text('Normal')),
            ButtonSegment(value: Priority.high, label: Text('High')),
          ],
          selected: {d.priority},
          onSelectionChanged: (s) => _wizard.update((x) => x.copyWith(priority: s.first)),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _duration,
          focusNode: _durationFocus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
          // iOS number pads have no Next key; Done closes the keyboard (docs/decisions.md).
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _notesFocus.requestFocus(),
          onChanged: (v) => _wizard.update((x) => x.copyWith(duration: v)),
          decoration: InputDecoration(labelText: 'Estimated duration (minutes)', helperText: 'From 15 to 480', errorText: e['duration']),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _notes,
          focusNode: _notesFocus,
          minLines: 3,
          maxLines: 6,
          maxLength: 500,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          textInputAction: TextInputAction.newline,
          onChanged: (v) => _wizard.update((x) => x.copyWith(notes: v)),
          decoration: InputDecoration(
            labelText: 'Notes for the site manager',
            helperText: 'Optional',
            errorText: e['notes'],
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

/// Read-only field that opens a picker (date, time).
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.error,
  });

  final String label;
  final String value;
  final String? error;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label${value.isEmpty ? '' : ', $value'}',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.extraSmall),
      child: InputDecorator(
        isEmpty: value.isEmpty,
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          suffixIcon: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon)),
        ),
        child: Text(value),
      ),
    ),
  );
}

// ----------------------------------------------------------- Step 3: Checklist

class _ChecklistStep extends ConsumerStatefulWidget {
  const _ChecklistStep({required this.wizardKey, required this.errors});

  final String wizardKey;
  final Map<String, String> errors;

  @override
  ConsumerState<_ChecklistStep> createState() => _ChecklistStepState();
}

class _ChecklistStepState extends ConsumerState<_ChecklistStep> {
  final Map<String, GlobalKey> _keys = {};

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  void _jumpToFirstError() {
    final first = widget.errors.keys.firstOrNull;
    final ctx = first == null ? null : _keys[first]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: Durations.medium2, alignment: 0.1);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(wizardControllerProvider(widget.wizardKey)).draft;
    final items = ref.watch(checklistProvider(fireSafetyTemplateId));
    final wizard = ref.read(wizardControllerProvider(widget.wizardKey).notifier);
    final theme = Theme.of(context);
    final list = items.value;
    if (list == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${d.type ?? 'Fire safety, annual'} · ${d.answers.length} of ${list.length} answered', style: theme.textTheme.bodyMedium),
        if (widget.errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          FormErrorBanner('${widget.errors.length} ${widget.errors.length == 1 ? 'item needs' : 'items need'} attention'),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(onPressed: _jumpToFirstError, child: const Text('Jump to the first one')),
          ),
        ],
        const SizedBox(height: 12),
        for (final item in list) ...[
          _ChecklistCard(
            key: _keyFor(item.id),
            item: item,
            answer: d.answers[item.id],
            failure: d.failures[item.id] ?? const FailDetail(),
            photoCount: d.attachments.where((a) => a.forItem == item.id).length,
            error: widget.errors[item.id],
            onAnswer: (a) {
              ref.read(hapticsProvider).selection();
              wizard.update((x) {
                final answers = {...x.answers};
                a == null ? answers.remove(item.id) : answers[item.id] = a;
                return x.copyWith(answers: answers);
              });
            },
            onFailure: (f) => wizard.update((x) => x.copyWith(failures: {...x.failures, item.id: f})),
            onAddPhoto: () => addPickedPhoto(ref, context, widget.wizardKey, camera: true, forItem: item.id),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ChecklistCard extends StatefulWidget {
  const _ChecklistCard({
    required this.item,
    required this.answer,
    required this.failure,
    required this.photoCount,
    required this.error,
    required this.onAnswer,
    required this.onFailure,
    required this.onAddPhoto,
    super.key,
  });

  final ChecklistItem item;
  final Answer? answer;
  final FailDetail failure;
  final int photoCount;
  final String? error;
  final ValueChanged<Answer?> onAnswer;
  final ValueChanged<FailDetail> onFailure;
  final VoidCallback onAddPhoto;

  @override
  State<_ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends State<_ChecklistCard> {
  late final _note = TextEditingController(text: widget.failure.note);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed = widget.answer == Answer.fail;
    final f = widget.failure;
    return Card.outlined(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(color: widget.error != null ? theme.colorScheme.error : theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.item.title, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            SegmentedButton<Answer>(
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Answer.pass, label: Text('Pass')),
                ButtonSegment(value: Answer.fail, label: Text('Fail')),
                ButtonSegment(value: Answer.na, label: Text('N/A')),
              ],
              selected: {?widget.answer},
              onSelectionChanged: (s) => widget.onAnswer(s.firstOrNull),
            ),
            // Implicit animation: the failure details grow in and out (P11).
            AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Durations.medium2,
              curve: Easing.emphasizedDecelerate,
              alignment: Alignment.topCenter,
              child: !failed
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(child: Text('Severity')),
                            Text(f.severityLabel, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.error)),
                          ],
                        ),
                        Slider(
                          value: f.severity.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: f.severityLabel,
                          semanticFormatterCallback: (v) => 'Severity ${FailDetail(severity: v.round()).severityLabel}',
                          onChanged: (v) => widget.onFailure(f.copyWith(severity: v.round())),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Requires follow-up visit'),
                          value: f.followUp,
                          onChanged: (v) => widget.onFailure(f.copyWith(followUp: v)),
                        ),
                        TextField(
                          controller: _note,
                          minLines: 1,
                          maxLines: 4,
                          onChanged: (v) => widget.onFailure(f.copyWith(note: v)),
                          decoration: const InputDecoration(labelText: 'What is wrong?'),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Symbols.add_a_photo),
                              label: Text(widget.photoCount == 0 ? 'Add photo' : 'Add photo (${widget.photoCount})'),
                              onPressed: widget.onAddPhoto,
                            ),
                            const ActionChip(avatar: Icon(Symbols.mic), label: Text('Dictate note (not in the PoC)')),
                          ],
                        ),
                      ],
                    ),
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 8),
              Text(widget.error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------- Step 4: Photos, files

/// Saves picked bytes on the device (SQLite blob) and adds the attachment to
/// the draft. Returns false when the type or size is not allowed.
Future<bool> saveAttachment(WidgetRef ref, String wizardKey, PickedFile file, {String? forItem}) async {
  final ext = file.name.split('.').last.toLowerCase();
  if (!WizardValidator.allowedExtensions.contains(ext) || file.bytes.length > WizardValidator.maxFileBytes) return false;
  final id = '${file.isImage ? 'ph' : 'f'}-${DateTime.now().microsecondsSinceEpoch}';
  await ref.read(localStoreProvider).putBlob(id, file.bytes, file.mime);
  ref
      .read(wizardControllerProvider(wizardKey).notifier)
      .update(
        (d) => d.copyWith(
          attachments: [
            ...d.attachments,
            DraftAttachment(id: id, name: file.name, sizeBytes: file.bytes.length, isPhoto: file.isImage, forItem: forItem),
          ],
        ),
      );
  return true;
}

enum CaptureResult { added, cancelled, rejected, denied, failed }

/// Camera or gallery into the draft. Handles cancel and a denied camera.
Future<CaptureResult> addPickedPhoto(WidgetRef ref, BuildContext context, String wizardKey, {required bool camera, String? forItem}) async {
  try {
    final file = await ref.read(mediaServiceProvider).photo(camera: camera);
    if (file == null) return CaptureResult.cancelled;
    final ok = await saveAttachment(ref, wizardKey, file, forItem: forItem);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use JPG, PNG or HEIC up to 20 MB.')));
    }
    return ok ? CaptureResult.added : CaptureResult.rejected;
  } on PlatformException catch (e) {
    // iOS reports camera_access_denied / photo_access_denied.
    if (e.code.contains('access_denied')) return CaptureResult.denied;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't open the ${camera ? 'camera' : 'gallery'}.")));
    }
    return CaptureResult.failed;
  }
}

/// A saved photo, or the placeholder for simulated or fixture photos.
class AttachmentImage extends ConsumerWidget {
  const AttachmentImage({required this.attachment, required this.index, super.key});

  final DraftAttachment attachment;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(blobProvider(attachment.id)).value;
    if (bytes == null) return PhotoPlaceholder(index: index);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true, semanticLabel: attachment.name),
    );
  }
}

class _PhotosStep extends ConsumerStatefulWidget {
  const _PhotosStep({required this.wizardKey, required this.errors});

  final String wizardKey;
  final Map<String, String> errors;

  @override
  ConsumerState<_PhotosStep> createState() => _PhotosStepState();
}

class _PhotosStepState extends ConsumerState<_PhotosStep> {
  final _grid = GlobalKey<SliverAnimatedGridState>();
  late List<DraftAttachment> _shown = ref.read(wizardControllerProvider(widget.wizardKey)).draft.photos;
  bool _cameraDenied = false;
  bool _dragging = false;
  void Function()? _stopPaste;

  @override
  void initState() {
    super.initState();
    // Web: Ctrl/Cmd+V of a screenshot or copied image adds it (D04 "Paste image").
    if (ref.read(capabilitiesProvider).isWeb) _stopPaste = ref.read(mediaServiceProvider).onPaste(_add);
  }

  @override
  void dispose() {
    _stopPaste?.call();
    super.dispose();
  }

  Duration get _duration => MediaQuery.disableAnimationsOf(context) ? Duration.zero : Durations.medium2;

  /// Keeps the animated grid in step with photos added elsewhere (drop, paste).
  void _syncGrid(List<DraftAttachment> photos) {
    for (final p in photos) {
      if (!_shown.any((s) => s.id == p.id)) {
        _shown = [..._shown, p];
        _grid.currentState?.insertItem(_shown.length - 1, duration: _duration);
      }
    }
  }

  Future<void> _add(PickedFile file) async {
    if (!await saveAttachment(ref, widget.wizardKey, file) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${file.name}: use JPG, PNG, HEIC or PDF up to 20 MB.')));
    }
  }

  Future<void> _capture({required bool camera}) async {
    final result = await addPickedPhoto(ref, context, widget.wizardKey, camera: camera);
    if (result == CaptureResult.denied && mounted) setState(() => _cameraDenied = true);
  }

  Future<void> _attachFiles() async {
    for (final f in await ref.read(mediaServiceProvider).files()) {
      await _add(f);
    }
  }

  void _remove(DraftAttachment photo) {
    final index = _shown.indexWhere((p) => p.id == photo.id);
    if (index < 0) return;
    ref
        .read(wizardControllerProvider(widget.wizardKey).notifier)
        .update((d) => d.copyWith(attachments: d.attachments.where((a) => a.id != photo.id).toList()));
    unawaited(ref.read(localStoreProvider).deleteBlob(photo.id));
    _shown = [..._shown]..removeAt(index);
    _grid.currentState?.removeItem(index, (context, animation) => _tile(photo, index, animation), duration: _duration);
  }

  Widget _tile(DraftAttachment p, int index, Animation<double> animation) => ScaleTransition(
    scale: CurvedAnimation(parent: animation, curve: Easing.emphasizedDecelerate),
    child: Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Semantics(
          label: 'Photo ${index + 1}${p.forItem != null ? ', for a failed item' : ''}',
          child: AttachmentImage(attachment: p, index: index),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: IconButton.filled(
            tooltip: 'Remove photo ${index + 1}',
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.inverseSurface,
              foregroundColor: Theme.of(context).colorScheme.onInverseSurface,
              minimumSize: const Size(28, 28),
              iconSize: 18,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            onPressed: () => _remove(p),
            icon: const Icon(Symbols.close),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(wizardControllerProvider(widget.wizardKey)).draft;
    _syncGrid(d.photos);
    final theme = Theme.of(context);
    final caps = ref.watch(capabilitiesProvider);
    final e = widget.errors;

    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        FilledButton.tonalIcon(
          onPressed: _cameraDenied ? null : () => _capture(camera: true),
          icon: const Icon(Symbols.photo_camera),
          label: Text(caps.isWeb ? 'Use camera' : 'Take photo'),
        ),
        OutlinedButton.icon(
          onPressed: () => _capture(camera: false),
          icon: const Icon(Symbols.photo_library),
          label: const Text('Gallery'),
        ),
      ],
    );

    // Pointer platforms get a drop zone (D04); phones and tablets get buttons.
    final zone = DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) async {
        setState(() => _dragging = false);
        for (final f in detail.files) {
          await _add(PickedFile(name: f.name, bytes: await f.readAsBytes(), mime: mimeFor(f.name)));
        }
      },
      child: AnimatedContainer(
        duration: _duration,
        constraints: const BoxConstraints(minHeight: 160),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _dragging ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.large),
          border: Border.all(color: _dragging ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, width: _dragging ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(Symbols.upload, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              _dragging ? 'Drop files to upload' : 'Drag files here, or paste an image',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            Text('JPG, PNG, HEIC or PDF, up to 20 MB each.', style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            buttons,
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Add photos of the findings and any documents the site gave you.', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        if (_cameraDenied) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(AppRadii.medium)),
            child: Row(
              children: [
                Icon(Symbols.no_photography, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Camera access is off. You can still choose photos from the gallery.',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                if (caps.openSystemSettings)
                  TextButton(onPressed: () => ref.read(permissionServiceProvider).openSettings(), child: Text(context.l10n.openSettings)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (caps.isMobile) buttons else zone,
        const SizedBox(height: 16),
        Text('Photos · ${d.photos.length}', style: theme.textTheme.titleSmall),
        if (e['photos'] != null) Text(e['photos']!, style: TextStyle(color: theme.colorScheme.error)),
        const SizedBox(height: 8),
        CustomScrollView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(6),
              sliver: SliverAnimatedGrid(
                key: _grid,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                initialItemCount: _shown.length,
                itemBuilder: (context, i, animation) => _tile(_shown[i], i, animation),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Text('Files · ${d.files.length}', style: theme.textTheme.titleSmall)),
            TextButton.icon(onPressed: _attachFiles, icon: const Icon(Symbols.attach_file), label: const Text('Attach file')),
          ],
        ),
        for (final f in d.files)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(f.name.toLowerCase().endsWith('.pdf') ? Symbols.picture_as_pdf : Symbols.draft),
            title: Text(f.name),
            subtitle: Text('${(f.sizeBytes / 1000).round()} KB · saved on this device'),
            trailing: IconButton(
              tooltip: 'Remove ${f.name}',
              onPressed: () {
                unawaited(ref.read(localStoreProvider).deleteBlob(f.id));
                ref
                    .read(wizardControllerProvider(widget.wizardKey).notifier)
                    .update((x) => x.copyWith(attachments: x.attachments.where((a) => a.id != f.id).toList()));
              },
              icon: const Icon(Symbols.close),
            ),
          ),
        for (final key in ['size', 'type'])
          if (e[key] != null) Text(e[key]!, style: TextStyle(color: theme.colorScheme.error)),
      ],
    );
  }
}

// -------------------------------------------------------------- Step 5: Review

class _ReviewStep extends ConsumerWidget {
  const _ReviewStep({required this.wizardKey, required this.onEditStep, required this.onSubmit});

  final String wizardKey;
  final ValueChanged<int> onEditStep;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wizardControllerProvider(wizardKey));
    final d = state.draft;
    final items = ref.watch(checklistProvider(fireSafetyTemplateId)).value ?? const [];
    final v = WizardValidator(ValidationText.of(context), today: ref.watch(clockProvider)(), checklist: items);
    final online = ref.watch(connectivityProvider).value ?? true;
    final theme = Theme.of(context);
    final fails = d.answers.values.where((a) => a == Answer.fail).length;
    final followUp = d.failures.entries.any((e) => d.answers[e.key] == Answer.fail && e.value.followUp);
    final when = d.scheduledAt == null ? 'No date' : DateFormat.yMMMEd().add_Hm().format(d.scheduledAt!);

    Widget card(WizardStep s, IconData icon, String text) {
      final errors = v.step(s, d);
      return Card.filled(
        child: ListTile(
          leading: Icon(icon, color: errors.isEmpty ? null : theme.colorScheme.error),
          title: Text(s.title),
          subtitle: Text(
            errors.isEmpty ? text : errors.values.join(' · '),
            style: errors.isEmpty ? null : TextStyle(color: theme.colorScheme.error),
          ),
          trailing: TextButton(onPressed: () => onEditStep(s.number), child: const Text('Edit')),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(WizardStep.site, Symbols.location_on, [d.siteName, if (d.siteAddress.isNotEmpty) d.siteAddress].join(' · ')),
        card(WizardStep.details, Symbols.event, '${d.type ?? '—'} · $when · ${d.priority.name} priority · ${d.duration} min'),
        card(
          WizardStep.checklist,
          Symbols.rule,
          '${d.answers.length} of ${items.length} answered · $fails failed${followUp ? ' · follow-up visit needed' : ''}',
        ),
        card(WizardStep.photos, Symbols.photo_library, '${d.photos.length} photos · ${d.files.length} files'),
        if (!online) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(AppRadii.medium)),
            child: Row(
              children: [
                Icon(Symbols.cloud_off, color: theme.colorScheme.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "You're offline. The report is saved on this device and sends automatically when you're back online.",
                    style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        CheckboxListTile(
          value: d.confirmed,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.confirmFindings),
          onChanged: (c) => ref.read(wizardControllerProvider(wizardKey).notifier).update((x) => x.copyWith(confirmed: c ?? false)),
        ),
        if (state.submitError != null) ...[
          FormErrorBanner(
            state.submitError!.fields.isEmpty
                ? "Couldn't submit (${state.submitError!.code}). Try again."
                : 'The server rejected: ${state.submitError!.fields.entries.map((e) => '${e.key} (${ValidationText.of(context).server(e.value)})').join(', ')}',
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        BusyButton(label: context.l10n.submit, busy: state.submitting, onPressed: v.canSubmit(d) ? onSubmit : null),
        if (!v.canSubmit(d))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Fix the steps marked in red and confirm the findings to submit.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
