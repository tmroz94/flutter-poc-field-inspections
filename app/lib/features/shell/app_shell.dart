import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/layout/window_size.dart';
import '../../core/router/routes.dart';

class _Destination {
  const _Destination(this.label, this.icon, {this.branch, this.location});

  final String label;
  final IconData icon;

  /// Shell branch this destination switches to, or null for a plain link.
  final int? branch;
  final String? location;
}

const _branchDestinations = [
  _Destination('Home', Symbols.home, branch: 0),
  _Destination('Inspections', Symbols.assignment, branch: 1),
  _Destination('Map', Symbols.map, branch: 2),
  _Destination('Settings', Symbols.settings, branch: 3),
];

/// Desktop (D02) adds a direct link to the results tracker.
const _resultsDestination = _Destination('PoC results', Symbols.fact_check, location: Routes.results);

/// Adaptive app shell: navigation bar under 600, collapsed rail 600–1199,
/// extended rail with a "New inspection" FAB from 1200 (boards P02, T01, D02).
/// Each branch keeps its own navigation stack.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    final location = GoRouterState.of(context).uri.path;
    final destinations = [..._branchDestinations, if (size == WindowSize.large) _resultsDestination];
    final onResults = location.startsWith(Routes.results);
    final selected = size == WindowSize.large && onResults ? destinations.length - 1 : navigationShell.currentIndex;

    void select(int index) {
      final d = destinations[index];
      if (d.branch != null) {
        // Re-selecting the current tab pops it back to its root, as on iOS and Android.
        navigationShell.goBranch(d.branch!, initialLocation: d.branch == navigationShell.currentIndex && !onResults);
      } else {
        context.go(d.location!);
      }
    }

    if (!size.usesRail) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: select,
          destinations: [
            for (final d in destinations) NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.icon, fill: 1), label: d.label),
          ],
        ),
      );
    }

    final extended = size == WindowSize.large;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 240,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            selectedIndex: selected,
            onDestinationSelected: select,
            leading: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: extended
                  ? FloatingActionButton.extended(
                      heroTag: 'rail-fab',
                      onPressed: () => context.push(Routes.newInspectionStep(1)),
                      icon: const Icon(Symbols.add),
                      label: const Text('New inspection'),
                    )
                  : FloatingActionButton(
                      heroTag: 'rail-fab',
                      tooltip: 'New inspection',
                      onPressed: () => context.push(Routes.newInspectionStep(1)),
                      child: const Icon(Symbols.add),
                    ),
            ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.icon, fill: 1), label: Text(d.label)),
            ],
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
