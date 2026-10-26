import 'package:material_ui/material_ui.dart';

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
