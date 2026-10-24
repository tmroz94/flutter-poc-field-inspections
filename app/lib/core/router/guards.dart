import '../../features/auth/auth_models.dart';
import 'deep_links.dart';
import 'routes.dart';

/// Inputs the top-level redirect needs, kept apart from Riverpod so the rules
/// can be unit-tested as a pure function.
class GuardInput {
  const GuardInput({required this.auth, this.locked = false});

  final AuthStatus auth;

  /// True only on iOS and Android with biometric lock on and the timeout hit.
  final bool locked;
}

/// The app's single redirect. Returns the new location, or null to stay.
///
/// 1. Session still restoring → `/splash?from=` so a cold-start deep link isn't lost.
/// 2. Signed out on a guarded path → `/sign-in?from=`.
/// 3. Signed in but locked → `/unlock?from=`.
/// 4. Signed in on sign-in/up/forgot or unlock → back to `from`, else home.
/// Unknown paths are left alone so the router shows the 404 screen.
String? resolveRedirect(Uri uri, GuardInput input) {
  // Platform deep links (Android/iOS) arrive with their scheme and host, e.g.
  // fieldinspections://app/inspections/INS-1042. Rewrite them to the in-app
  // location first; foreign links go home.
  if (uri.hasScheme) {
    final location = DeepLinks.toLocation(uri.toString()) ?? Routes.home;
    return resolveRedirect(Uri.parse(location), input) ?? location;
  }
  final path = uri.path.isEmpty ? Routes.root : uri.path;
  if (!RouteTable.isKnown(path)) return null;
  final here = uri.toString();

  if (input.auth == AuthStatus.restoring) {
    return path == Routes.splash ? null : _withFrom(Routes.splash, here);
  }

  if (path == Routes.splash || path == Routes.root) {
    final target = DeepLinks.sanitizeFrom(uri.queryParameters['from']) ?? Routes.home;
    return resolveRedirect(Uri.parse(target), input) ?? target;
  }

  final isPublic = Routes.public.contains(path);
  if (input.auth == AuthStatus.signedOut) {
    if (isPublic) return null;
    if (path == Routes.unlock) return Routes.signIn;
    return _withFrom(Routes.signIn, here);
  }

  // Signed in.
  final returnTo = DeepLinks.sanitizeFrom(uri.queryParameters['from']);
  if (input.locked) {
    if (path == Routes.unlock) return null;
    return _withFrom(Routes.unlock, isPublic ? returnTo : here);
  }
  if (isPublic || path == Routes.unlock) return returnTo ?? Routes.home;
  return null;
}

String _withFrom(String base, String? from) {
  if (from == null || from == Routes.home || from == Routes.root) return base;
  return Uri(path: base, queryParameters: {'from': from}).toString();
}
