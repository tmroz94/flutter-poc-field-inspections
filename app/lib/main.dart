import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/storage/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean web URLs (/inspections/INS-1042) instead of /#/inspections/INS-1042.
  // Hosting must rewrite unknown paths to index.html (docs/deep-links.md).
  usePathUrlStrategy();
  final store = await PrefsStore.create();
  runApp(ProviderScope(overrides: [keyValueStoreProvider.overrideWithValue(store)], child: const FieldInspectionsApp()));
}
