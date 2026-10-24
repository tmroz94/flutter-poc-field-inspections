/// Browser-only helpers behind a conditional import, so the rest of the app
/// stays free of `dart:js_interop` and compiles for iOS and Android.
library;

export 'web_bridge_stub.dart' if (dart.library.js_interop) 'web_bridge_web.dart';
