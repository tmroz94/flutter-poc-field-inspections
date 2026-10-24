/// Every URL in the app. Screens navigate with these helpers instead of
/// building strings, and the deep-link tester (P-tool) lists [RouteTable.all].
abstract final class Routes {
  static const root = '/';
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const unlock = '/unlock';
  static const home = '/home';
  static const notifications = '/notifications';
  static const inspections = '/inspections';
  static const inspectionsFilter = '/inspections/filter';
  static const newInspection = '/inspections/new';
  static const map = '/map';
  static const settings = '/settings';
  static const appearance = '/settings/appearance';
  static const results = '/settings/poc/results';
  static const adaptive = '/settings/poc/adaptive';
  static const diagnostics = '/settings/poc/diagnostics';
  static const deepLinks = '/settings/poc/deep-links';

  /// Reachable without a session. Signed-in users are sent away from these.
  static const public = {signIn, signUp, forgotPassword};

  static String inspection(String id, {String? tab}) => _withQuery('/inspections/$id', {'tab': tab});

  /// [from]: where closing the wizard returns to, when that isn't the wizard's
  /// parent page (e.g. Home).
  static String editInspection(String id, {int step = 1, String? from}) =>
      Uri(path: '/inspections/$id/edit', queryParameters: {'step': '$step', 'from': ?from}).toString();

  static String newInspectionStep(int step, {String? from}) =>
      Uri(path: newInspection, queryParameters: {'step': '$step', 'from': ?from}).toString();

  static String photo(String inspectionId, String photoId) => '/inspections/$inspectionId/photos/$photoId';

  static String submitted(String id) => '/inspections/$id/submitted';

  static String result(String featureId) => '$results/$featureId';

  static String mapSite(String siteId) => _withQuery(map, {'site': siteId});

  static String _withQuery(String path, Map<String, String?> query) {
    final q = {
      for (final e in query.entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    return q.isEmpty ? path : Uri(path: path, queryParameters: q).toString();
  }
}

/// One routable screen: its path pattern, an example to open, and the design
/// boards it implements.
class RouteInfo {
  RouteInfo(this.pattern, this.title, {required this.example, this.boards = const [], this.public = false});

  final String pattern;
  final String title;
  final String example;
  final List<String> boards;
  final bool public;

  late final RegExp _regex = RegExp('^${pattern.replaceAllMapped(RegExp(r':\w+'), (_) => '[^/]+')}\$');

  bool matches(String path) => _regex.hasMatch(path);
}

abstract final class RouteTable {
  static final all = <RouteInfo>[
    RouteInfo(Routes.signIn, 'Sign in', example: '/sign-in', boards: ['P01', 'D01'], public: true),
    RouteInfo(Routes.signUp, 'Create account', example: '/sign-up', public: true),
    RouteInfo(Routes.forgotPassword, 'Reset password', example: '/forgot-password', public: true),
    RouteInfo(Routes.unlock, 'Biometric unlock', example: '/unlock', boards: ['P26']),
    RouteInfo(Routes.home, 'Home', example: '/home', boards: ['P02', 'D02']),
    RouteInfo(Routes.notifications, 'Notifications', example: '/notifications', boards: ['P17']),
    RouteInfo(
      Routes.inspections,
      'Inspections',
      example: '/inspections?status=overdue,draft&sort=dueAsc',
      boards: ['P03', 'P04', 'T01', 'D03'],
    ),
    RouteInfo(Routes.inspectionsFilter, 'Filter and sort', example: '/inspections/filter?status=scheduled', boards: ['P05']),
    RouteInfo(
      Routes.newInspection,
      'New inspection',
      example: '/inspections/new?step=1',
      boards: ['P09', 'P10', 'P11', 'P12', 'P13', 'T02', 'D04'],
    ),
    RouteInfo(
      '/inspections/:id',
      'Inspection detail',
      example: '/inspections/INS-1042?tab=checklist',
      boards: ['P06', 'P07', 'T04', 'D03'],
    ),
    RouteInfo('/inspections/:id/edit', 'Edit inspection', example: '/inspections/INS-1040/edit?step=2', boards: ['P09']),
    RouteInfo('/inspections/:id/photos/:photoId', 'Photo viewer', example: '/inspections/INS-1042/photos/p3', boards: ['P08']),
    RouteInfo('/inspections/:id/submitted', 'Submitted', example: '/inspections/INS-1042/submitted', boards: ['P16']),
    RouteInfo(Routes.map, 'Map', example: '/map?site=s-riverside-office', boards: ['P18']),
    RouteInfo(Routes.settings, 'Settings', example: '/settings', boards: ['P19', 'T03']),
    RouteInfo(Routes.appearance, 'Appearance and language', example: '/settings/appearance', boards: ['P20', 'T03']),
    RouteInfo(Routes.results, 'PoC results', example: '/settings/poc/results', boards: ['P21', 'D05']),
    RouteInfo('/settings/poc/results/:featureId', 'Edit result', example: '/settings/poc/results/back-navigation', boards: ['P22']),
    RouteInfo(Routes.adaptive, 'Adaptive widgets', example: '/settings/poc/adaptive', boards: ['P23']),
    RouteInfo(Routes.diagnostics, 'Diagnostics', example: '/settings/poc/diagnostics', boards: ['P24']),
    RouteInfo(Routes.deepLinks, 'Deep-link tester', example: '/settings/poc/deep-links'),
  ];

  /// Paths that are routes but not destinations worth listing.
  static const _internal = {Routes.root, Routes.splash};

  static bool isKnown(String path) => _internal.contains(path) || all.any((r) => r.matches(path));
}
