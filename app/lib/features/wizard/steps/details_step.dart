import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/inspection_widgets.dart';
import '../../../data/models/draft.dart';
import '../../../data/models/inspection.dart';
import '../../../l10n/l10n.dart';
import '../../inspections/inspections_controller.dart';
import '../wizard_controller.dart';
import '../wizard_text.dart';

// ------------------------------------------------------------- Step 2: Details

/// P10: type, date and time, priority, duration and notes.
class DetailsStep extends ConsumerStatefulWidget {
  const DetailsStep({required this.wizardKey, required this.errors, super.key});

  final String wizardKey;
  final Map<String, String> errors;

  @override
  ConsumerState<DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends ConsumerState<DetailsStep> {
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
    final wizard = _wizard;
    final today = ref.read(clockProvider)();
    final first = d.inspectionId == null ? DateTime(today.year, today.month, today.day) : DateTime(today.year - 1);
    final initial = d.date != null && !d.date!.isBefore(first) ? d.date! : first;
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDate: initial,
    );
    if (picked != null && mounted) wizard.update((x) => x.copyWith(date: () => picked));
  }

  Future<void> _pickTime(InspectionDraft d) async {
    final wizard = _wizard;
    final m = d.startMinutes ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked != null && mounted) wizard.update((x) => x.copyWith(startMinutes: () => picked.hour * 60 + picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(wizardControllerProvider(widget.wizardKey)).draft;
    final typesAsync = ref.watch(inspectionTypesProvider);
    final types = typesAsync.value ?? const <String>[];
    final l = context.l10n;
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
            // DropdownMenu applies initialSelection to its text only when the
            // selection changes, not when the entries arrive: types that load
            // after the first build (cold link to step 2, Try again) would
            // leave the field blank although a type is set.
            key: ValueKey(Object.hashAll(types)),
            width: c.maxWidth,
            initialSelection: d.type,
            label: Text(l.inspectionType),
            errorText: e['type'],
            dropdownMenuEntries: [for (final t in types) DropdownMenuEntry(value: t, label: t)],
            onSelected: (t) => _wizard.update((x) => x.copyWith(type: () => t)),
          ),
        ),
        if (typesAsync.hasError && types.isEmpty)
          Row(
            children: [
              Expanded(
                child: Text(l.typesLoadFailed, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
              TextButton(onPressed: () => ref.invalidate(inspectionTypesProvider), child: Text(l.tryAgain)),
            ],
          ),
        const SizedBox(height: 20),
        pair(
          _PickerField(
            label: l.dateLabel,
            value: dateText,
            error: e['date'],
            icon: Symbols.calendar_today,
            tooltip: l.openCalendar,
            onTap: () => _pickDate(d),
          ),
          _PickerField(
            label: l.startTime,
            value: timeText,
            error: e['time'],
            icon: Symbols.schedule,
            tooltip: l.openTimePicker,
            onTap: () => _pickTime(d),
          ),
        ),
        const SizedBox(height: 20),
        Text(l.priority, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        SegmentedButton<Priority>(
          segments: [for (final p in Priority.values) ButtonSegment(value: p, label: Text(priorityText(l, p)))],
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
          decoration: InputDecoration(labelText: l.durationLabel, helperText: l.durationHelper, errorText: e['duration']),
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
          decoration: InputDecoration(labelText: l.notesLabel, helperText: l.optional, errorText: e['notes'], alignLabelWithHint: true),
        ),
      ],
    );
  }
}

/// Read-only field that opens a picker (date, time). Screen readers get one
/// button with the label, the value and the error, if any.
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
    label: [label, if (value.isNotEmpty) value, ?error].join(', '),
    excludeSemantics: true,
    onTap: onTap,
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
