import 'package:flutter/foundation.dart';

@immutable
class AppUser {
  const AppUser({required this.id, required this.name, required this.email, required this.initials});

  factory AppUser.fromJson(Map<String, Object?> json) => AppUser(
    id: json['id']! as String,
    name: json['name']! as String,
    email: json['email']! as String,
    initials: json['initials'] as String? ?? '',
  );

  final String id;
  final String name;
  final String email;
  final String initials;

  String get firstName => name.split(' ').first;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'email': email, 'initials': initials};
}

@immutable
class Session {
  const Session({required this.token, required this.user});

  factory Session.fromJson(Map<String, Object?> json) =>
      Session(token: json['token']! as String, user: AppUser.fromJson(json['user']! as Map<String, Object?>));

  final String token;
  final AppUser user;

  Map<String, Object?> toJson() => {'token': token, 'user': user.toJson()};
}

/// Auth failure with a machine-readable [code] and optional per-field error
/// codes from the server (HTTP 422), which forms map back onto their fields.
class AuthException implements Exception {
  const AuthException(this.code, {this.fields = const {}});

  /// invalidCredentials | validation | network | unauthorized | unknown
  final String code;
  final Map<String, String> fields;

  @override
  String toString() => 'AuthException($code, $fields)';
}

enum AuthStatus { restoring, signedOut, signedIn }

@immutable
class AuthState {
  const AuthState._(this.status, this.session);

  const AuthState.restoring() : this._(AuthStatus.restoring, null);
  const AuthState.signedOut() : this._(AuthStatus.signedOut, null);
  const AuthState.signedIn(Session session) : this._(AuthStatus.signedIn, session);

  final AuthStatus status;
  final Session? session;

  AppUser? get user => session?.user;
}
