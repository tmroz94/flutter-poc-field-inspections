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

  /// macOS, Windows and Linux apps (not the web build running on them).
  bool get isDesktop =>
      !isWeb && (platform == TargetPlatform.macOS || platform == TargetPlatform.windows || platform == TargetPlatform.linux);

  /// Biometric lock (P26) exists on iOS and Android only; web has no equivalent,
  /// and desktop isn't wired up (Touch ID / Windows Hello would be the next step).
  bool get biometricLock => isMobile;

  /// Taking a photo: the phone camera, or the browser's camera input. Desktop
  /// apps have no camera picker, so they offer files and drag and drop instead.
  bool get camera => !isDesktop;

  /// Reminders need notifications scheduled ahead. Browsers can't, and neither
  /// can Linux's notification plugin; both show test notifications from a timer.
  bool get scheduledNotifications => !isWeb && platform != TargetPlatform.linux;

  /// Haptics are a no-op on web.
  bool get haptics => isMobile;

  /// Opening the app's page in system settings is impossible from a browser.
  bool get openSystemSettings => isMobile;

  /// Pull-to-refresh needs touch; web and desktop also get a Refresh button.
  bool get pullToRefreshOnly => isMobile;
}

/// Overridable in tests to simulate web, iOS or Android.
final capabilitiesProvider = Provider<Capabilities>((ref) => Capabilities.current());
