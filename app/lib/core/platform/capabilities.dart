import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the current platform can do. Screens ask this instead of checking
/// `kIsWeb` / `defaultTargetPlatform` themselves, so platform differences live
/// in one place and show up on the Diagnostics screen.
class Capabilities {
  const Capabilities({required this.isWeb, required this.platform});

  factory Capabilities.current() => Capabilities(isWeb: kIsWeb, platform: defaultTargetPlatform);

  final bool isWeb;
  final TargetPlatform platform;

  bool get isMobile => !isWeb && (platform == TargetPlatform.iOS || platform == TargetPlatform.android);

  /// Biometric lock (P26) exists on iOS and Android only; web has no equivalent.
  bool get biometricLock => isMobile;

  /// Haptics are a no-op on web.
  bool get haptics => isMobile;

  /// Opening the app's page in system settings is impossible from a browser.
  bool get openSystemSettings => isMobile;

  /// Pull-to-refresh needs touch; web and desktop also get a Refresh button.
  bool get pullToRefreshOnly => isMobile;
}

/// Overridable in tests to simulate web, iOS or Android.
final capabilitiesProvider = Provider<Capabilities>((ref) => Capabilities.current());
