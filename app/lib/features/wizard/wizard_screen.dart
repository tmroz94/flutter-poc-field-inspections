import 'package:material_ui/material_ui.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_view.dart';

/// New or edit inspection: 5 steps, step in `?step=`.
class WizardScreen extends StatelessWidget {
  const WizardScreen({required this.step, this.inspectionId, super.key});

  static const stepCount = 5;

  final int step;

  /// Null for a new inspection.
  final String? inspectionId;

  @override
  Widget build(BuildContext context) {
    final id = inspectionId;
    String stepLink(int s) => id == null ? Routes.newInspectionStep(s) : Routes.editInspection(id, step: s);
    return PlaceholderView(
      title: '${id == null ? 'New inspection' : 'Edit $id'} · step $step of $stepCount',
      boards: const ['P09', 'P10', 'P11', 'P12', 'P13', 'T02', 'D04'],
      links: {if (step < stepCount) 'Next': stepLink(step + 1), if (step == stepCount) 'Submit': Routes.submitted(id ?? 'INS-1046')},
    );
  }
}
