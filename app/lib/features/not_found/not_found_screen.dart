import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/routes.dart';
import '../../l10n/l10n.dart';

/// Router errorBuilder target (P25 / D06): shows the path that didn't match.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({required this.uri, super.key});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), tooltip: l.goHome, onPressed: () => context.go(Routes.home)),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.pageNotFound, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(l.pageNotFoundBody, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  SelectableText(uri.toString(), style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: () => context.go(Routes.home), child: Text(l.goHome)),
                  TextButton(onPressed: () => context.go(Routes.inspections), child: Text(l.openInspections)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
