import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_screens.dart';
import '../../features/auth/lock_controller.dart';
import '../../features/home/home_screen.dart';
import '../../features/inspections/inspection_screens.dart';
import '../../features/map/map_screen.dart';
import '../../features/not_found/not_found_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/poc/poc_screens.dart';
import '../../features/settings/settings_screens.dart';
import '../../features/shell/app_shell.dart';
import '../../features/wizard/submitted_screen.dart';
import '../../features/wizard/wizard_controller.dart';
import '../../features/wizard/wizard_screen.dart';
import '../layout/window_size.dart';
import 'guards.dart';
import 'routes.dart';
import 'sheet_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Where the app opens when the platform gives no deep link. Tests override it
/// to simulate a cold start from a link.
final initialLocationProvider = Provider<String>((ref) => Routes.home);

/// Re-runs the redirect whenever the session or lock state changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref
      ..listen(authControllerProvider.select((s) => s.status), (_, _) => notifyListeners())
      ..listen(lockControllerProvider.select((s) => s.locked), (_, _) => notifyListeners());
  }
}

/// `?step=` must be 1–5; anything else starts at step 1.
String? _normalizeStep(BuildContext context, GoRouterState state) {
  final step = int.tryParse(state.uri.queryParameters['step'] ?? '');
  if (step != null && step >= 1 && step <= WizardScreen.stepCount) return null;
  return state.uri.replace(queryParameters: {...state.uri.queryParameters, 'step': '1'}).toString();
}

/// List filters that belong in `/inspections?…`. Popping a detail page keeps
/// its query (e.g. `?tab=photos`), so anything else is dropped from the list URL.
const _listQueryKeys = {'status', 'sort', 'q', 'due', 'from', 'to'};

String? _cleanListQuery(BuildContext context, GoRouterState state) {
  final uri = state.uri;
  if (uri.path != Routes.inspections || uri.queryParameters.keys.every(_listQueryKeys.contains)) return null;
  final kept = {
    for (final e in uri.queryParameters.entries)
      if (_listQueryKeys.contains(e.key)) e.key: e.value,
  };
  return Uri(path: uri.path, queryParameters: kept.isEmpty ? null : kept).toString();
}

/// Browser back, links or code leaving the wizard: ask first unless the user
/// already chose to leave (or submitted), or there is nothing to lose.
Future<bool> _confirmWizardExit(BuildContext context, GoRouterState state) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(wizardExitApprovedProvider)) return true;
  final key = wizardKey(state.pathParameters['id']);
  if (container.read(wizardControllerProvider(key)).draft.isEmpty) return true;
  final choice = await showLeaveDialog(context);
  if (choice == LeaveChoice.discard) await container.read(wizardControllerProvider(key).notifier).discard();
  if (choice == LeaveChoice.leave) await container.read(wizardControllerProvider(key).notifier).saveNow();
  return choice != LeaveChoice.stay;
}

int _step(GoRouterState state) => int.parse(state.uri.queryParameters['step']!);

DetailTab _tab(GoRouterState state) => DetailTab.values.asNameMap()[state.uri.queryParameters['tab']] ?? DetailTab.overview;

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) => resolveRedirect(
      state.uri,
      GuardInput(auth: ref.read(authControllerProvider).status, locked: ref.read(lockControllerProvider).locked),
    ),
    errorBuilder: (context, state) => NotFoundScreen(uri: state.uri),
    routes: [
      GoRoute(path: Routes.root, redirect: (_, _) => Routes.home),
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(path: Routes.forgotPassword, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.unlock, builder: (_, _) => const UnlockScreen()),
      GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen()),
      // Outside the shell: it replaces the wizard and must not push pages into a
      // branch navigator that may never have been laid out (cold-start deep
      // link straight into the wizard). Listed before the shell so it matches first.
      GoRoute(
        path: '/inspections/:id/submitted',
        builder: (_, state) => SubmittedScreen(
          id: state.pathParameters['id']!,
          queued: state.uri.queryParameters['queued'] == '1',
          site: state.uri.queryParameters['site'] ?? '',
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.inspections,
                redirect: _cleanListQuery,
                builder: (_, state) => InspectionsScreen(query: state.uri.queryParameters),
                routes: [
                  // Literal segments first so they win over `:id`.
                  GoRoute(
                    path: 'filter',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (_, state) => BottomSheetPage<void>(
                      key: state.pageKey,
                      name: state.uri.toString(),
                      child: FilterSheet(query: state.uri.queryParameters),
                    ),
                  ),
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    redirect: _normalizeStep,
                    onExit: _confirmWizardExit,
                    pageBuilder: (_, state) => MaterialPage<void>(
                      key: state.pageKey,
                      fullscreenDialog: true,
                      child: WizardScreen(step: _step(state)),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    // From 840 the detail is a pane beside the list: swap it in without a page transition.
                    pageBuilder: (context, state) {
                      final child = InspectionDetailScreen(id: state.pathParameters['id']!, tab: _tab(state));
                      return WindowSize.fromWidth(MediaQuery.sizeOf(context).width).isTwoPane
                          ? NoTransitionPage<void>(key: state.pageKey, child: child)
                          : MaterialPage<void>(key: state.pageKey, child: child);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        redirect: _normalizeStep,
                        onExit: _confirmWizardExit,
                        pageBuilder: (_, state) => MaterialPage<void>(
                          key: state.pageKey,
                          fullscreenDialog: true,
                          child: WizardScreen(step: _step(state), inspectionId: state.pathParameters['id']),
                        ),
                      ),
                      GoRoute(
                        path: 'photos/:photoId',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) =>
                            PhotoViewerScreen(inspectionId: state.pathParameters['id']!, photoId: state.pathParameters['photoId']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.map,
                builder: (_, state) => MapScreen(siteId: state.uri.queryParameters['site']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  GoRoute(path: 'appearance', builder: (_, _) => const AppearanceScreen()),
                  GoRoute(
                    path: 'poc/results',
                    builder: (_, _) => const ResultsScreen(),
                    routes: [
                      GoRoute(
                        path: ':featureId',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (_, state) => BottomSheetPage<void>(
                          key: state.pageKey,
                          name: state.uri.toString(),
                          child: ResultSheet(featureId: state.pathParameters['featureId']!),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(path: 'poc/adaptive', builder: (_, _) => const AdaptiveWidgetsScreen()),
                  GoRoute(path: 'poc/diagnostics', builder: (_, _) => const DiagnosticsScreen()),
                  GoRoute(path: 'poc/deep-links', builder: (_, _) => const DeepLinksScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  // The router widget isn't mounted while the session restores (splash), and
  // go_router only listens for platform links (Android intents, iOS URLs)
  // while something listens to it. Listen for the router's whole lifetime so
  // a link that arrives during the splash isn't dropped.
  void keepPlatformLinks() {}
  router.routeInformationProvider.addListener(keepPlatformLinks);
  ref.onDispose(() {
    router.routeInformationProvider.removeListener(keepPlatformLinks);
    router.dispose();
    refresh.dispose();
  });
  return router;
});
