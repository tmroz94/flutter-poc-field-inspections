import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/platform/capabilities.dart';
import '../../../core/platform/platform_services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/form_support.dart';
import '../../../data/models/inspection.dart';
import '../../../l10n/l10n.dart';
import '../../inspections/inspections_controller.dart';
import '../wizard_controller.dart';
import '../wizard_text.dart';
import 'photos_step.dart' show addPickedPhoto;

// ----------------------------------------------------------- Step 3: Checklist

/// P11: Pass / Fail / N/A per item; a Fail asks for severity, follow-up, a
/// note and photos.
class ChecklistStep extends ConsumerStatefulWidget {
  const ChecklistStep({required this.wizardKey, required this.errors, super.key});

  final String wizardKey;
  final Map<String, String> errors;

  @override
  ConsumerState<ChecklistStep> createState() => _ChecklistStepState();
}

class _ChecklistStepState extends ConsumerState<ChecklistStep> {
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
    final l = context.l10n;
    final list = items.value;
    if (list == null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: items.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.checklistLoadFailed, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    FilledButton.tonal(onPressed: () => ref.invalidate(checklistProvider(fireSafetyTemplateId)), child: Text(l.tryAgain)),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final itemErrors = widget.errors.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.checklistProgress(d.type ?? '—', d.answers.length, list.length), style: theme.textTheme.bodyMedium),
        if (itemErrors > 0) ...[
          const SizedBox(height: 12),
          FormErrorBanner(l.itemsNeedAttention(itemErrors)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(onPressed: _jumpToFirstError, child: Text(l.jumpToFirst)),
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
            // Desktop apps have no camera picker: the photo comes from a file.
            onAddPhoto: () => addPickedPhoto(
              ref,
              context,
              widget.wizardKey,
              camera: ref.read(capabilitiesProvider).camera,
              forItem: item.id,
              explainDeniedCamera: true,
            ),
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
    final l = context.l10n;
    final failed = widget.answer == Answer.fail;
    final f = widget.failure;
    final severity = severityText(l, f.severity);
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
              segments: [
                ButtonSegment(value: Answer.pass, label: Text(l.answerPass)),
                ButtonSegment(value: Answer.fail, label: Text(l.answerFail)),
                ButtonSegment(value: Answer.na, label: Text(l.answerNa)),
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
                            Expanded(child: Text(l.severity)),
                            Text(severity, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.error)),
                          ],
                        ),
                        Slider(
                          value: f.severity.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: severity,
                          semanticFormatterCallback: (v) => l.severitySemantics(severityText(l, v.round())),
                          onChanged: (v) => widget.onFailure(f.copyWith(severity: v.round())),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.followUpVisit),
                          value: f.followUp,
                          onChanged: (v) => widget.onFailure(f.copyWith(followUp: v)),
                        ),
                        TextField(
                          controller: _note,
                          minLines: 1,
                          maxLines: 4,
                          onChanged: (v) => widget.onFailure(f.copyWith(note: v)),
                          decoration: InputDecoration(labelText: l.whatIsWrong),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Symbols.add_a_photo),
                              label: Text(widget.photoCount == 0 ? l.addPhoto : l.addPhotoCount(widget.photoCount)),
                              onPressed: widget.onAddPhoto,
                            ),
                            ActionChip(avatar: const Icon(Symbols.mic), label: Text(l.dictateNote)),
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
