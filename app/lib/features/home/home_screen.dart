import 'package:material_ui/material_ui.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderView(
    title: 'Home',
    boards: const ['P02', 'D02'],
    links: {
      'Notifications': Routes.notifications,
      'Inspection INS-1042': Routes.inspection('INS-1042'),
      'New inspection': Routes.newInspectionStep(1),
    },
  );
}
