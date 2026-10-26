import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/validation/form_support.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/inspection_widgets.dart';
import '../../../data/models/inspection.dart';
import '../../../data/sync/sync_service.dart';
import '../../../l10n/l10n.dart';
import '../../inspections/inspections_controller.dart';
import '../wizard_controller.dart';
import '../wizard_text.dart';
import '../wizard_validation.dart';

// -------------------------------------------------------------- Step 5: Review

/// P13: one card per step (errors in red), the confirmation and Submit.
class ReviewStep extends ConsumerWidget {
  const ReviewStep({required this.wizardKey, required this.onEditStep, required this.onSubmit, super.key});

  final String wizardKey;
  final ValueChanged<int> onEditStep;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wizardControllerProvider(wizardKey));
    final d = state.draft;
    final items = ref.watch(checklistProvider(fireSafetyTemplateId)).value ?? const [];
    final t = ValidationText.of(context);
    final v = WizardValidator(t, today: ref.watch(clockProvider)(), checklist: items);
    final online = ref.watch(connectivityProvider).value ?? true;
    final theme = Theme.of(context);
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fails = d.answers.values.where((a) => a == Answer.fail).length;
    final followUp = d.failures.entries.any((e) => d.answers[e.key] == Answer.fail && e.value.followUp);
    final when = d.scheduledAt == null ? l.noDate : DateFormat.yMMMEd(locale).add_Hm().format(d.scheduledAt!);
    final error = state.submitError;

    Widget card(WizardStep s, IconData icon, String text) {
      final errors = v.step(s, d);
      return Card.filled(
        child: ListTile(
          leading: Icon(icon, color: errors.isEmpty ? null : theme.colorScheme.error),
          title: Text(stepTitle(context, s)),
          subtitle: Text(
            errors.isEmpty ? text : errors.values.join(' · '),
            style: errors.isEmpty ? null : TextStyle(color: theme.colorScheme.error),
          ),
          trailing: TextButton(onPressed: () => onEditStep(s.number), child: Text(l.edit)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(WizardStep.site, Symbols.location_on, [d.siteName, if (d.siteAddress.isNotEmpty) d.siteAddress].join(' · ')),
        card(WizardStep.details, Symbols.event, l.reviewDetails(d.type ?? '—', when, priorityText(l, d.priority), d.duration)),
        card(
          WizardStep.checklist,
          Symbols.rule,
          [l.reviewChecklist(d.answers.length, items.length, fails), if (followUp) l.reviewFollowUp].join(' · '),
        ),
        card(WizardStep.photos, Symbols.photo_library, l.wizardHintPhotos(d.photos.length, d.files.length)),
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
                  child: Text(l.reviewOffline, style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
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
          title: Text(l.confirmFindings),
          onChanged: (c) => ref.read(wizardControllerProvider(wizardKey).notifier).update((x) => x.copyWith(confirmed: c ?? false)),
        ),
        if (error != null) ...[
          FormErrorBanner(error.fields.isEmpty ? l.submitFailed(error.code) : l.serverRejected(serverFieldErrors(context, error.fields))),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        BusyButton(label: l.submit, busy: state.submitting, onPressed: v.canSubmit(d) ? onSubmit : null),
        if (!v.canSubmit(d))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.fixStepsToSubmit, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}
