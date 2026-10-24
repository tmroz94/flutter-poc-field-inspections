import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/storage/key_value_store.dart';
import 'data/api/backend_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean web URLs (/inspections/INS-1042) instead of /#/inspections/INS-1042.
  // Hosting must rewrite unknown paths to index.html (docs/deep-links.md).
  usePathUrlStrategy();
  // push/replace (photo viewer, detail tabs, sheets) also update the browser URL,
  // so what's on screen can always be shared, bookmarked and refreshed.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final (store, backend) = (await PrefsStore.create(), await BackendConfig.resolve());
  runApp(
    ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(store), backendConfigProvider.overrideWithValue(backend)],
      child: const FieldInspectionsApp(),
    ),
  );
}
