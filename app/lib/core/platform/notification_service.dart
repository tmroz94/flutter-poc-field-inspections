import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/l10n.dart';
import '../router/deep_links.dart';
import 'platform_services.dart';

/// Local notifications on iOS, Android, macOS, Windows, Linux and the web.
/// Every notification's payload is an in-app route; tapping it opens that page
/// (P17, deep links).
///
/// The web shows notifications only while a tab is open and cannot schedule
/// them (browser limitation); Linux's plugin can't schedule either. [schedule]
/// returns false on both.
class NotificationService {
  NotificationService({this.isWeb = kIsWeb, bool? canSchedule, this._permissions = const PermissionService()})
    : canSchedule = canSchedule ?? (!isWeb && defaultTargetPlatform != TargetPlatform.linux);

  final bool isWeb;
  final bool canSchedule;
  final PermissionService _permissions;
  final _plugin = FlutterLocalNotificationsPlugin();
  late final _taps = StreamController<String>.broadcast(onListen: _flushPending);
  bool _ready = false;

  /// A tap that arrived before anything listened. On Android a tap that
  /// relaunches a killed app comes in as a new intent during start-up, before
  /// the app subscribes; a broadcast stream would drop it.
  String? _pendingTap;

  /// Routes from notification taps while the app runs (foreground or background).
  Stream<String> get taps => _taps.stream;

  void _emit(String route) {
    debugPrint('Notification tap → $route');
    if (_taps.hasListener) {
      _taps.add(route);
    } else {
      _pendingTap = route;
    }
  }

  void _flushPending() {
    final route = _pendingTap;
    _pendingTap = null;
    if (route != null) scheduleMicrotask(() => _taps.add(route));
  }

  /// Simulates a tap on a notification carrying [payload].
  @visibleForTesting
  void debugTap(String payload) {
    final route = DeepLinks.toLocation(payload);
    if (route != null) _emit(route);
  }

  /// [channelName] and [channelDescription] show in Android's notification
  /// settings; callers pass them in the app's language. Every notification
  /// uses the one channel, so each call renames it.
  static NotificationDetails _details({required String channelName, required String channelDescription}) => NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: const DarwinNotificationDetails(),
    macOS: const DarwinNotificationDetails(),
  );

  // Ask for permission from the UI (P17 "Turn on"), not at start-up.
  static const _darwin = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  /// Initialises the plugin. Returns the route of the notification that
  /// launched the app (cold start from a tap), if any.
  Future<String?> init() async {
    // Linux's label for a click on the notification. The app's language
    // setting is still loading here, so the device's language.
    final strings = lookupAppLocalizations(
      PlatformDispatcher.instance.locale.languageCode == 'pl' ? const Locale('pl') : const Locale('en'),
    );
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: _darwin,
          macOS: _darwin,
          linux: LinuxInitializationSettings(defaultActionName: strings.notificationOpenAction),
          windows: const WindowsInitializationSettings(
            appName: 'Field Inspections',
            appUserModelId: 'dev.flutterpoc.FieldInspections',
            guid: '019f31a2-22eb-49e8-b857-c3967afcdfae',
          ),
          web: const WebInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (r) {
          final route = DeepLinks.toLocation(r.payload ?? '');
          if (route != null) _emit(route);
        },
      );
      _ready = true;
      // Linux's plugin can't tell whether a notification launched the app.
      if (!isWeb && defaultTargetPlatform == TargetPlatform.linux) return null;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) return DeepLinks.toLocation(launch!.notificationResponse?.payload ?? '');
    } on Object catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
    return null;
  }

  Future<PermissionState> permission() async {
    if (!_ready) return PermissionState.unsupported;
    try {
      if (isWeb) {
        final web = _plugin.resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>();
        return switch (web?.permissionStatus) {
          WebNotificationPermission.granted => PermissionState.granted,
          WebNotificationPermission.denied => PermissionState.permanentlyDenied,
          _ => PermissionState.denied,
        };
      }
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final macos = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      // Windows and Linux have no permission prompt for app notifications.
      if (android == null && ios == null && macos == null) return PermissionState.granted;
      final enabled = android != null
          ? await android.areNotificationsEnabled()
          : (await (ios?.checkPermissions() ?? macos!.checkPermissions()))?.isEnabled;
      if (enabled ?? false) return PermissionState.granted;
      // The plugin can't tell "ask again" from "only in system settings" (after
      // two denials on Android 13+, one on iOS); permission_handler can.
      return await _permissions.status(AppPermission.notifications) == PermissionState.permanentlyDenied
          ? PermissionState.permanentlyDenied
          : PermissionState.denied;
    } on Object {
      return PermissionState.unsupported;
    }
  }

  /// Shows the OS prompt. On the web, call only from a button press.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (isWeb) {
        return await _plugin
                .resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? false;
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      final macos = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      if (macos != null) return await macos.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      return true; // Windows, Linux: nothing to ask.
    } on Object {
      return false;
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String route,
    required String channelName,
    required String channelDescription,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details(channelName: channelName, channelDescription: channelDescription),
      payload: route,
    );
  }

  /// Schedules a notification at [at]; false where scheduling isn't possible (web, Linux).
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String route,
    required String channelName,
    required String channelDescription,
  }) async {
    if (!_ready || !canSchedule) return false;
    await _plugin.zonedSchedule(
      id: id,
      // An absolute instant: no time-zone database lookup needed for one-off reminders.
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: _details(channelName: channelName, channelDescription: channelDescription),
      // Inexact: no exact-alarm permission needed; Android may delay a few minutes.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: route,
    );
    return true;
  }

  Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }
}

/// Overridden in `main` with the initialised instance.
final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

final notificationTapsProvider = StreamProvider<RouteRequest>((ref) => ref.watch(notificationServiceProvider).taps.map(RouteRequest.new));
