import 'package:field_inspections/core/platform/capabilities.dart';
import 'package:field_inspections/core/platform/notification_service.dart';
import 'package:field_inspections/core/platform/platform_services.dart';
import 'package:flutter/services.dart';

/// 1×1 transparent PNG.
final tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class FakeBiometrics extends BiometricService {
  FakeBiometrics({this.ok = true, this.isAvailable = true});

  bool ok;
  bool isAvailable;
  int calls = 0;

  @override
  Future<bool> available() async => isAvailable;

  String? lastReason;

  @override
  Future<bool> authenticate({required String reason}) async {
    calls++;
    lastReason = reason;
    return ok;
  }
}

class FakeLocation extends LocationService {
  FakeLocation([this.fix = const LocationFix(LocationStatus.ok, lat: 52.2401, lng: 21.0301, accuracy: 8)]);

  LocationFix fix;

  @override
  Future<LocationFix> current() async => fix;
}

class FakeMedia extends MediaService {
  FakeMedia({this.deniedCamera = false});

  bool deniedCamera;
  List<PickedFile> nextFiles = [];
  int photos = 0;

  @override
  Future<PickedFile?> photo({required bool camera}) async {
    if (camera && deniedCamera) throw PlatformException(code: 'camera_access_denied');
    photos++;
    return PickedFile(name: 'IMG_${photos.toString().padLeft(4, '0')}.png', bytes: tinyPng, mime: 'image/png');
  }

  @override
  Future<List<PickedFile>> files() async => nextFiles;

  /// A camera photo that Android delivered after restarting the app.
  PickedFile? lost;

  @override
  Future<PickedFile?> lostPhoto() async {
    final file = lost;
    lost = null;
    return file;
  }

  String? nextJson;

  @override
  Future<String?> jsonText() async => nextJson;

  @override
  void Function() onPaste(void Function(PickedFile file) onFile) => () {};
}

class FakeShare extends ShareService {
  final links = <Uri>[];
  final files = <String>[];
  final contents = <String, Uint8List>{};

  @override
  Future<ShareOutcome> shareLink({required String text, required Uri link, String? subject}) async {
    links.add(link);
    return ShareOutcome.shared;
  }

  @override
  Future<ShareOutcome> shareFile({required Uint8List bytes, required String fileName, required String mime, required bool isWeb}) async {
    files.add(fileName);
    contents[fileName] = bytes;
    return ShareOutcome.shared;
  }
}

class FakeLauncher extends LauncherService {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

class FakePermissions extends PermissionService {
  int settingsOpened = 0;

  @override
  Future<PermissionState> status(AppPermission p) async => PermissionState.granted;

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

/// Records notifications instead of showing them.
class FakeNotifications extends NotificationService {
  FakeNotifications({this.granted = true, super.isWeb = false});

  bool granted;
  final shown = <String>[];
  final scheduled = <(DateTime, String)>[];
  final scheduledTitles = <String>[];

  @override
  Future<String?> init() async => null;

  @override
  Future<PermissionState> permission() async => granted ? PermissionState.granted : PermissionState.denied;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> show({required int id, required String title, required String body, required String route}) async => shown.add(route);

  @override
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String route,
    String? channelName,
    String? channelDescription,
  }) async {
    if (isWeb) return false;
    scheduled.add((at, route));
    scheduledTitles.add(title);
    return true;
  }

  @override
  Future<void> cancelAll() async {
    scheduled.clear();
    scheduledTitles.clear();
  }
}

/// Bundle of fakes a test can inspect after pumping the app.
class Fakes {
  Fakes({Capabilities capabilities = const Capabilities(isWeb: false, platform: TargetPlatform.android)})
    : notifications = FakeNotifications(isWeb: capabilities.isWeb);

  final biometrics = FakeBiometrics();
  final location = FakeLocation();
  final media = FakeMedia();
  final share = FakeShare();
  final launcher = FakeLauncher();
  final permissions = FakePermissions();
  final FakeNotifications notifications;
}
