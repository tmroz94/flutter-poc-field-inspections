import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/deep_links.dart';
import 'capabilities.dart';

/// `fieldinspections://` links in the desktop apps, through app_links. Phones
/// get links from Flutter's own deep linking (intent filters, the iOS URL
/// scheme) and the web from the address bar, so this stays off there.
///
/// The link that launched the app becomes the router's initial location (like
/// a notification tap at launch); [routes] then carries the links that arrive
/// while the app runs.
class DesktopLinks {
  DesktopLinks({required this.enabled, Future<String?> Function()? initialLink, Stream<String> Function()? links})
    : _initialLink = initialLink ?? (() => AppLinks().getInitialLinkString()),
      _links = links ?? (() => AppLinks().stringLinkStream);

  factory DesktopLinks.current() => DesktopLinks(enabled: Capabilities.current().isDesktop);

  final bool enabled;
  final Future<String?> Function() _initialLink;
  final Stream<String> Function() _links;
  String? _initial;

  /// The in-app location of the launch link, or null.
  Future<String?> initialRoute() async {
    if (!enabled) return null;
    try {
      _initial = await _initialLink();
    } on Object catch (e) {
      debugPrint('Desktop links unavailable: $e');
    }
    return _initial == null ? null : DeepLinks.toLocation(_initial!);
  }

  /// Locations of links opened while the app runs. app_links replays the
  /// launch link to its first listener; that one is already the initial route.
  Stream<String> routes() {
    if (!enabled) return const Stream.empty();
    var first = true;
    return _links()
        .where((link) {
          final replay = first && link == _initial;
          first = false;
          return !replay;
        })
        .map(DeepLinks.toLocation)
        .where((route) => route != null)
        .cast<String>();
  }
}

/// Overridden in `main` with the instance that read the launch link.
final desktopLinksProvider = Provider<DesktopLinks>((ref) => DesktopLinks(enabled: false));

final desktopLinkRoutesProvider = StreamProvider<RouteRequest>((ref) => ref.watch(desktopLinksProvider).routes().map(RouteRequest.new));
