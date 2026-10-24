import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/routes.dart';

/// Router errorBuilder target (P25 / D06): shows the path that didn't match.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({required this.uri, super.key});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Go to home', onPressed: () => context.go(Routes.home)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Page not found', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                const Text(
                  'Nothing lives at this address. The link may be old, or the inspection was deleted.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SelectableText(uri.toString(), style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => context.go(Routes.home), child: const Text('Go to home')),
                TextButton(onPressed: () => context.go(Routes.inspections), child: const Text('Open inspections')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
