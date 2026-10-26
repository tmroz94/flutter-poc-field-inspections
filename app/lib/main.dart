import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/platform/desktop_links.dart';
import 'core/platform/frame_stats.dart';
import 'core/platform/notification_service.dart';
import 'core/router/router.dart';
import 'core/router/routes.dart';
import 'core/storage/key_value_store.dart';
import 'data/api/backend_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FrameStats.instance.start();
  // Clean web URLs (/inspections/INS-1042) instead of /#/inspections/INS-1042.
  // Hosting must rewrite unknown paths to index.html (docs/deep-links.md).
  usePathUrlStrategy();
  // push/replace (photo viewer, detail tabs, sheets) also update the browser URL,
  // so what's on screen can always be shared, bookmarked and refreshed.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final notifications = NotificationService();
  final links = DesktopLinks.current();
  final (store, backend, launchRoute, linkRoute) = (
    await PrefsStore.create(),
    await BackendConfig.resolve(),
    await notifications.init(),
    await links.initialRoute(),
  );
  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        backendConfigProvider.overrideWithValue(backend),
        notificationServiceProvider.overrideWithValue(notifications),
        desktopLinksProvider.overrideWithValue(links),
        // A tap on a notification, or a link (desktop), that started the app opens its route.
        initialLocationProvider.overrideWithValue(launchRoute ?? linkRoute ?? Routes.home),
      ],
      child: const FieldInspectionsApp(),
    ),
  );
}
