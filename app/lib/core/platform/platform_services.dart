import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'capabilities.dart';
import 'web_bridge.dart' as web_bridge;

/// A photo or file the user picked, dropped or pasted.
class PickedFile {
  const PickedFile({required this.name, required this.bytes, required this.mime});

  final String name;
  final Uint8List bytes;
  final String mime;

  bool get isImage => mime.startsWith('image/');
}

String mimeFor(String name) => switch (name.split('.').last.toLowerCase()) {
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'heic' => 'image/heic',
  'webp' => 'image/webp',
  'pdf' => 'application/pdf',
  _ => 'application/octet-stream',
};

/// Camera, gallery and file picker. On the web the camera opens the browser's
/// file input with `capture`, which uses the webcam or phone camera.
class MediaService {
  const MediaService();

  /// Null when the user cancelled. Throws [PlatformException] `camera_access_denied`
  /// (iOS) when the camera permission is off.
  Future<PickedFile?> photo({required bool camera}) async {
    final x = await ImagePicker().pickImage(source: camera ? ImageSource.camera : ImageSource.gallery, maxWidth: 2000, imageQuality: 80);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    return PickedFile(name: x.name, bytes: bytes, mime: x.mimeType ?? mimeFor(x.name));
  }

  /// Android can kill the app while the system camera is open; the photo then
  /// arrives on the next start. Null when there's none (and on other platforms).
  Future<PickedFile?> lostPhoto() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final lost = await ImagePicker().retrieveLostData();
      final x = lost.file;
      if (lost.isEmpty || x == null) return null;
      return PickedFile(name: x.name, bytes: await x.readAsBytes(), mime: x.mimeType ?? mimeFor(x.name));
    } on Object {
      return null;
    }
  }

  Future<List<PickedFile>> files() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'heic']);
    return [for (final f in picked) PickedFile(name: f.name, bytes: await f.xFile.readAsBytes(), mime: mimeFor(f.name))];
  }

  /// A JSON file's text (results import), or null when cancelled.
  Future<String?> jsonText() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['json']);
    if (picked.isEmpty) return null;
    return utf8.decode(await picked.first.xFile.readAsBytes());
  }

  /// Web only: images pasted with Ctrl/Cmd+V. Returns a cancel function.
  void Function() onPaste(void Function(PickedFile file) onFile) =>
      web_bridge.listenForPastedImages((bytes, name, mime) => onFile(PickedFile(name: name, bytes: bytes, mime: mime)));
}

enum LocationStatus { ok, serviceOff, denied, deniedForever, unsupported, error }

class LocationFix {
  const LocationFix(this.status, {this.lat, this.lng, this.accuracy});

  final LocationStatus status;
  final double? lat;
  final double? lng;
  final double? accuracy;

  /// Metres to a point, or null without a fix.
  double? distanceTo(double? lat2, double? lng2) =>
      lat == null || lat2 == null || lng2 == null ? null : Geolocator.distanceBetween(lat!, lng!, lat2, lng2);
}

/// Current position with the permission flow. On the web the browser asks;
/// it needs HTTPS (localhost counts as secure).
class LocationService {
  const LocationService({this.useLocationManager = false});

  /// Android only: read Android's LocationManager instead of Google Play
  /// services' fused provider, which ignores test-provider (mock) positions.
  /// Device tests set this so the host can steer the GPS.
  final bool useLocationManager;

  Future<LocationFix> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return const LocationFix(LocationStatus.serviceOff);
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return const LocationFix(LocationStatus.denied);
      if (permission == LocationPermission.deniedForever) return const LocationFix(LocationStatus.deniedForever);
      final p = await Geolocator.getCurrentPosition(
        locationSettings: useLocationManager
            ? AndroidSettings(accuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15), forceLocationManager: true)
            : const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      return LocationFix(LocationStatus.ok, lat: p.latitude, lng: p.longitude, accuracy: p.accuracy);
    } on MissingPluginException {
      return const LocationFix(LocationStatus.unsupported);
    } on Object catch (e) {
      debugPrint('Location failed: $e');
      return const LocationFix(LocationStatus.error);
    }
  }
}

enum ShareOutcome { shared, copied, dismissed }

/// Share sheet on iOS/Android; the Web Share API where the browser has it,
/// otherwise the link is copied (some desktop browsers lack navigator.share).
class ShareService {
  const ShareService();

  Future<ShareOutcome> shareLink({required String text, required Uri link, String? subject}) async {
    try {
      final r = await SharePlus.instance.share(ShareParams(text: '$text\n$link', subject: subject));
      return r.status == ShareResultStatus.dismissed ? ShareOutcome.dismissed : ShareOutcome.shared;
    } on Object {
      await Clipboard.setData(ClipboardData(text: link.toString()));
      return ShareOutcome.copied;
    }
  }

  /// Mobile: share sheet with the file. Web: the file downloads.
  Future<ShareOutcome> shareFile({required Uint8List bytes, required String fileName, required String mime, required bool isWeb}) async {
    if (isWeb) {
      web_bridge.downloadBytes(bytes, fileName, mime);
      return ShareOutcome.shared;
    }
    final r = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: fileName, mimeType: mime)],
        fileNameOverrides: [fileName],
      ),
    );
    return r.status == ShareResultStatus.dismissed ? ShareOutcome.dismissed : ShareOutcome.shared;
  }
}

/// Opens maps, phone and web links in other apps.
class LauncherService {
  const LauncherService();

  /// Apple Maps on iOS, Google Maps (app or web) elsewhere.
  Uri directionsUri(double lat, double lng, {required Capabilities caps}) => !caps.isWeb && caps.platform == TargetPlatform.iOS
      ? Uri.parse('maps://?daddr=$lat,$lng')
      : Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

  Future<bool> open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Biometric check for the lock screen (P26). Unsupported on the web.
class BiometricService {
  BiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } on Object {
      return false;
    }
  }

  /// True when the user passed biometrics or the device PIN. [reason] is shown
  /// in the system prompt, in the app's language.
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } on Object {
      return false;
    }
  }
}

enum AppPermission { camera, photos, location, notifications }

enum PermissionState { granted, limited, denied, permanentlyDenied, unsupported }

/// Runtime permission status and the jump to system settings (mobile only).
class PermissionService {
  const PermissionService();

  ph.Permission _map(AppPermission p) => switch (p) {
    AppPermission.camera => ph.Permission.camera,
    AppPermission.photos => ph.Permission.photos,
    AppPermission.location => ph.Permission.locationWhenInUse,
    AppPermission.notifications => ph.Permission.notification,
  };

  PermissionState _state(ph.PermissionStatus s) => switch (s) {
    ph.PermissionStatus.granted || ph.PermissionStatus.provisional => PermissionState.granted,
    ph.PermissionStatus.limited => PermissionState.limited,
    ph.PermissionStatus.permanentlyDenied || ph.PermissionStatus.restricted => PermissionState.permanentlyDenied,
    _ => PermissionState.denied,
  };

  Future<PermissionState> status(AppPermission p) async {
    try {
      return _state(await _map(p).status);
    } on Object {
      return PermissionState.unsupported;
    }
  }

  Future<PermissionState> request(AppPermission p) async {
    try {
      return _state(await _map(p).request());
    } on Object {
      return PermissionState.unsupported;
    }
  }

  Future<bool> openSettings() async {
    try {
      return await ph.openAppSettings();
    } on Object {
      return false;
    }
  }
}

/// Haptic feedback; silently does nothing on the web.
class Haptics {
  const Haptics(this._enabled);

  final bool _enabled;

  void selection() => _enabled ? unawaited(HapticFeedback.selectionClick()) : null;
  void success() => _enabled ? unawaited(HapticFeedback.mediumImpact()) : null;
  void warning() => _enabled ? unawaited(HapticFeedback.heavyImpact()) : null;
}

final mediaServiceProvider = Provider<MediaService>((ref) => const MediaService());
final locationServiceProvider = Provider<LocationService>((ref) => const LocationService());
final shareServiceProvider = Provider<ShareService>((ref) => const ShareService());
final launcherServiceProvider = Provider<LauncherService>((ref) => const LauncherService());
final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());
final permissionServiceProvider = Provider<PermissionService>((ref) => const PermissionService());
final hapticsProvider = Provider<Haptics>((ref) => Haptics(ref.watch(capabilitiesProvider).haptics));
