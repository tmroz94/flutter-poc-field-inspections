import 'package:flutter/foundation.dart';

/// A notification (P17). [route] is the deep link it opens.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.at,
    required this.read,
    required this.route,
  });

  factory AppNotification.fromJson(Map<String, Object?> j) => AppNotification(
    id: j['id']! as String,
    icon: j['icon'] as String? ?? 'notifications',
    title: j['title']! as String,
    body: j['body'] as String? ?? '',
    at: DateTime.parse(j['at']! as String),
    read: j['read'] == true,
    route: j['route'] as String? ?? '/notifications',
  );

  final String id;
  final String icon;
  final String title;
  final String body;
  final DateTime at;
  final bool read;
  final String route;
}
