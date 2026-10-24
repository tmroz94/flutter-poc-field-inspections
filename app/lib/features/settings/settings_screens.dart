import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_view.dart';
import '../auth/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Stack(
      children: [
        const PlaceholderView(
          title: 'Settings',
          boards: ['P19', 'T03'],
          links: {
            'Appearance and language': Routes.appearance,
            'PoC results': Routes.results,
            'Adaptive widgets': Routes.adaptive,
            'Diagnostics': Routes.diagnostics,
            'Deep-link tester': Routes.deepLinks,
          },
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: TextButton(onPressed: () => ref.read(authControllerProvider.notifier).signOut(), child: const Text('Sign out')),
        ),
      ],
    ),
  );
}

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderView(title: 'Appearance and language', boards: ['P20']);
}
