import 'package:material_ui/material_ui.dart';

import 'steps/checklist_step.dart';
import 'steps/details_step.dart';
import 'steps/photos_step.dart';
import 'steps/review_step.dart';
import 'steps/site_step.dart';
import 'wizard_validation.dart';

/// Body of one wizard step (each in `steps/`). [errors] is empty until Next
/// was tried on it.
class WizardStepView extends StatelessWidget {
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
  Widget build(BuildContext context) => switch (step) {
    WizardStep.site => SiteStep(wizardKey: wizardKey, errors: errors),
    WizardStep.details => DetailsStep(wizardKey: wizardKey, errors: errors),
    WizardStep.checklist => ChecklistStep(wizardKey: wizardKey, errors: errors),
    WizardStep.photos => PhotosStep(wizardKey: wizardKey, errors: errors),
    WizardStep.review => ReviewStep(wizardKey: wizardKey, onEditStep: onEditStep, onSubmit: onSubmit),
  };
}
