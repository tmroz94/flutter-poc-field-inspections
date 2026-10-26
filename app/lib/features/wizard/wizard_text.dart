import 'package:material_ui/material_ui.dart';

import '../../core/validation/validators.dart';
import '../../data/models/inspection.dart';
import '../../l10n/l10n.dart';
import 'wizard_validation.dart';

/// Localized step names.
String stepTitle(BuildContext context, WizardStep s) => switch (s) {
  WizardStep.site => context.l10n.stepSite,
  WizardStep.details => context.l10n.stepDetails,
  WizardStep.checklist => context.l10n.stepChecklist,
  WizardStep.photos => context.l10n.stepPhotos,
  WizardStep.review => context.l10n.stepReview,
};

/// "3 · Major": severity 1 (minor) … 5 (critical).
String severityText(AppLocalizations l, int severity) => l.severityValue(severity, switch (severity) {
  1 => l.severityMinor,
  2 => l.severityLow,
  3 => l.severityMajor,
  4 => l.severityHigh,
  _ => l.severityCritical,
});

String priorityText(AppLocalizations l, Priority p) => switch (p) {
  Priority.low => l.priorityLow,
  Priority.normal => l.priorityNormal,
  Priority.high => l.priorityHigh,
};

/// The form field a server field error is about, by the name the wizard shows
/// (the server reports its own keys, such as `durationMin`).
String serverFieldName(AppLocalizations l, String field) => switch (field) {
  'site' || 'siteId' || 'address' => l.siteLabel,
  'type' => l.inspectionType,
  'scheduledAt' => l.dateLabel,
  'durationMin' => l.durationLabel,
  'priority' => l.priority,
  'notes' => l.notes,
  'answers' || 'failures' => l.stepChecklist,
  'photos' || 'files' => l.stepPhotos,
  'checkedInAt' || 'lat' || 'lng' => l.yourLocation,
  'confirmed' => l.confirmFindings,
  _ => field,
};

/// "Date (The date is in the past), …": the server's field errors with the
/// names and messages the wizard uses.
String serverFieldErrors(BuildContext context, Map<String, String> fields) {
  final l = context.l10n;
  final t = ValidationText.of(context);
  return fields.entries.map((e) => '${serverFieldName(l, e.key)} (${t.server(e.value, field: e.key)})').join(', ');
}

/// An outbox entry's stored rejection (`scheduledAt: past, notes: tooLong`,
/// or just a code such as `server`) in the app's language.
String outboxRejectionText(BuildContext context, String stored) {
  final pairs = RegExp(r'(\w+): (\w+)').allMatches(stored).toList();
  if (pairs.isEmpty) return stored;
  return serverFieldErrors(context, {for (final m in pairs) m[1]!: m[2]!});
}
