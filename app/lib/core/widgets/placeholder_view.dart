import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Temporary body for screens not built yet (milestone M0). Shows which
/// boards the screen implements and the route it was opened with, plus links
/// so every route can be walked through before the real UI lands.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({required this.title, this.boards = const [], this.links = const {}, this.showAppBar = true, super.key});

  final String title;
  final List<String> boards;

  /// Label → location.
  final Map<String, String> links;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uri = GoRouterState.of(context).uri;
    final body = ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (boards.isNotEmpty) Text('Boards: ${boards.join(', ')}', style: theme.textTheme.bodyMedium),
        SelectableText(uri.toString(), style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
        const SizedBox(height: 16),
        for (final e in links.entries)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(onPressed: () => context.push(e.value), child: Text(e.key)),
          ),
      ],
    );
    if (!showAppBar) return Scaffold(body: SafeArea(child: body));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}
