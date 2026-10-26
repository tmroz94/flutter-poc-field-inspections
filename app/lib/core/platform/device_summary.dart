import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App version and a one-line device description for Diagnostics (P24).
@immutable
class DeviceSummary {
  const DeviceSummary({required this.version, required this.build, required this.device});

  final String version;
  final String build;

  /// e.g. "Android 16 (API 37) · sdk_gphone64_x86_64", "iOS 26.0 · iPhone 16", "Chrome · Win32".
  final String device;
}

Future<String> _device() async {
  final info = DeviceInfoPlugin();
  try {
    if (kIsWeb) {
      final w = await info.webBrowserInfo;
      return [w.browserName.name, if (w.platform case final p? when p.isNotEmpty) p].join(' · ');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final a = await info.androidInfo;
        return 'Android ${a.version.release} (API ${a.version.sdkInt}) · ${a.model}';
      case TargetPlatform.iOS:
        final i = await info.iosInfo;
        return '${i.systemName} ${i.systemVersion} · ${i.modelName}';
      case TargetPlatform.macOS:
        final m = await info.macOsInfo;
        return 'macOS ${m.majorVersion}.${m.minorVersion}.${m.patchVersion} · ${m.modelName}';
      case TargetPlatform.windows:
        final w = await info.windowsInfo;
        return '${w.productName} ${w.displayVersion}';
      case TargetPlatform.linux:
        return (await info.linuxInfo).prettyName;
      default:
        return defaultTargetPlatform.name;
    }
  } on Object {
    return 'Unknown';
  }
}

final deviceSummaryProvider = FutureProvider<DeviceSummary>((ref) async {
  final pkg = await PackageInfo.fromPlatform();
  return DeviceSummary(version: pkg.version, build: pkg.buildNumber, device: await _device());
});
