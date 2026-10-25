import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../router/deep_links.dart';
import 'platform_services.dart';

/// Local notifications on iOS, Android and the web. Every notification's
/// payload is an in-app route; tapping it opens that page (P17, deep links).
///
/// The web shows notifications only while a tab is open and cannot schedule
/// them (browser limitation), so [schedule] returns false there.
class NotificationService {
  NotificationService({this.isWeb = kIsWeb});

  final bool isWeb;
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

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Inspection reminders',
      channelDescription: 'Alerts before inspections start',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Initialises the plugin. Returns the route of the notification that
  /// launched the app (cold start from a tap), if any.
  Future<String?> init() async {
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Ask for permission from the UI (P17 "Turn on"), not at start-up.
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
          web: WebInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (r) {
          final route = DeepLinks.toLocation(r.payload ?? '');
          if (route != null) _emit(route);
        },
      );
      _ready = true;
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
      if (android != null) return (await android.areNotificationsEnabled() ?? false) ? PermissionState.granted : PermissionState.denied;
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final perms = await ios?.checkPermissions();
      return (perms?.isEnabled ?? false) ? PermissionState.granted : PermissionState.denied;
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
      return await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } on Object {
      return false;
    }
  }

  Future<void> show({required int id, required String title, required String body, required String route}) async {
    if (!_ready) return;
    await _plugin.show(id: id, title: title, body: body, notificationDetails: _details, payload: route);
  }

  /// Schedules a notification at [at]; false where scheduling isn't possible (web).
  Future<bool> schedule({required int id, required DateTime at, required String title, required String body, required String route}) async {
    if (!_ready || isWeb) return false;
    await _plugin.zonedSchedule(
      id: id,
      // An absolute instant: no time-zone database lookup needed for one-off reminders.
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: _details,
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

final notificationTapsProvider = StreamProvider<String>((ref) => ref.watch(notificationServiceProvider).taps);
