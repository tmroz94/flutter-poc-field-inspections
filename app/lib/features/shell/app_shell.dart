import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/layout/window_size.dart';
import '../../core/router/routes.dart';
import '../../l10n/l10n.dart';

enum _Destination {
  home(Symbols.home, branch: 0),
  inspections(Symbols.assignment, branch: 1),
  map(Symbols.map, branch: 2),
  settings(Symbols.settings, branch: 3),

  /// Desktop (D02) adds a direct link to the results tracker.
  results(Symbols.fact_check, location: Routes.results);

  const _Destination(this.icon, {this.branch, this.location});

  final IconData icon;

  /// Shell branch this destination switches to, or null for a plain link.
  final int? branch;
  final String? location;

  String label(AppLocalizations l) => switch (this) {
    home => l.navHome,
    inspections => l.navInspections,
    map => l.navMap,
    settings => l.navSettings,
    results => l.navPocResults,
  };
}

/// Adaptive app shell: navigation bar under 600, collapsed rail 600–1199,
/// extended rail with a "New inspection" FAB from 1200 (boards P02, T01, D02).
/// Each branch keeps its own navigation stack.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    final l = context.l10n;
    final location = GoRouterState.of(context).uri.path;
    final destinations = [
      _Destination.home,
      _Destination.inspections,
      _Destination.map,
      _Destination.settings,
      if (size == WindowSize.large) _Destination.results,
    ];
    final onResults = location.startsWith(Routes.results);
    final selected = size == WindowSize.large && onResults ? destinations.length - 1 : navigationShell.currentIndex;

    void select(int index) {
      final d = destinations[index];
      if (d.branch != null) {
        // Selecting the current branch again pops it back to its root, as on
        // iOS and Android. That includes Settings while the results tracker
        // (inside the Settings branch) is open.
        navigationShell.goBranch(d.branch!, initialLocation: d.branch == navigationShell.currentIndex);
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
            for (final d in destinations) NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.icon, fill: 1), label: d.label(l)),
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
                      onPressed: () => _newInspection(context),
                      icon: const Icon(Symbols.add),
                      label: Text(l.newInspection),
                    )
                  : FloatingActionButton(
                      heroTag: 'rail-fab',
                      tooltip: l.newInspection,
                      onPressed: () => _newInspection(context),
                      child: const Icon(Symbols.add),
                    ),
            ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.icon, fill: 1), label: Text(d.label(l))),
            ],
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

/// The rail's New inspection button works on every tab; Close returns to the
/// tab it was opened from (the list is the wizard's own parent).
void _newInspection(BuildContext context) {
  final here = GoRouterState.of(context).uri;
  context.go(Routes.newInspectionStep(1, from: here.path.startsWith(Routes.inspections) ? null : here.toString()));
}
