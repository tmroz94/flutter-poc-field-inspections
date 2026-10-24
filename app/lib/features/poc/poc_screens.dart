import 'package:material_ui/material_ui.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_view.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderView(
    title: 'PoC results',
    boards: const ['P21', 'D05'],
    links: {'Back navigation result': Routes.result('back-navigation')},
  );
}

class ResultSheet extends StatelessWidget {
  const ResultSheet({required this.featureId, super.key});

  final String featureId;

  @override
  Widget build(BuildContext context) => SizedBox(height: 320, child: Center(child: Text('Edit result: $featureId (P22)')));
}

class AdaptiveWidgetsScreen extends StatelessWidget {
  const AdaptiveWidgetsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderView(title: 'Adaptive widgets', boards: ['P23']);
}

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderView(title: 'Diagnostics', boards: ['P24']);
}
