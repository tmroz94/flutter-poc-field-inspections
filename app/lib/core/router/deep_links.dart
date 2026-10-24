import 'routes.dart';

/// Turns external links and notification payloads into in-app locations, and
/// checks `?from=` return targets so they can't redirect off-site.
abstract final class DeepLinks {
  /// Custom scheme: `fieldinspections://app/inspections/INS-1042`. The host is
  /// always `app` so the whole route stays in the URI path.
  static const scheme = 'fieldinspections';
  static const schemeHost = 'app';

  /// Web origin used for iOS universal links and Android app links. Replace
  /// with the real domain when one exists (see docs/deep-links.md).
  static const webHosts = {'fieldinspections.example', 'localhost'};

  /// Accepts `/path?query`, `fieldinspections://app/path?query` or
  /// `https://<webHost>/path?query`. Returns the location, or null when the
  /// link is foreign or malformed. Unknown paths are kept: they show the 404.
  static String? toLocation(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.contains(r'\')) return null;
    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    final bool allowed;
    if (!uri.hasScheme) {
      allowed = text.startsWith('/') && !text.startsWith('//');
    } else if (uri.scheme == scheme) {
      allowed = uri.host == schemeHost;
    } else {
      allowed = (uri.scheme == 'https' || uri.scheme == 'http') && webHosts.contains(uri.host);
    }
    if (!allowed) return null;
    final path = uri.path.isEmpty ? Routes.root : uri.path;
    return Uri(path: path, query: uri.hasQuery ? uri.query : null).toString();
  }

  /// A `from` value is honoured only when it is an in-app path to a known,
  /// non-auth route. Anything else falls back to the default destination.
  static String? sanitizeFrom(String? from) {
    if (from == null || from.isEmpty || !from.startsWith('/') || from.startsWith('//') || from.contains(r'\')) {
      return null;
    }
    final uri = Uri.tryParse(from);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
    final path = uri.path;
    if (!RouteTable.isKnown(path) ||
        Routes.public.contains(path) ||
        path == Routes.splash ||
        path == Routes.unlock ||
        path == Routes.root) {
      return null;
    }
    return uri.toString();
  }
}
