import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/platform/capabilities.dart';
import '../../core/platform/platform_services.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/inspection_widgets.dart';
import '../../core/widgets/search_field.dart';
import '../../data/models/inspection.dart';
import '../../data/models/list_query.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../inspections/inspection_actions.dart';
import '../inspections/inspections_controller.dart';

/// Off in widget tests so they don't fetch OpenStreetMap tiles.
final mapTilesEnabledProvider = Provider<bool>((ref) => true);

/// Open inspections with a location, for the map pins.
/// No automatic retry (like the other screens): an offline map says so and offers Try again.
final mapInspectionsProvider = FutureProvider.autoDispose<List<InspectionSummary>>((ref) async {
  final page = await ref.watch(inspectionsRepositoryProvider).list(const ListQuery(statuses: openStatuses), pageSize: 100);
  return page.items.where((i) => i.lat != null && i.lng != null).toList();
}, retry: (_, _) => null);

/// P18: OpenStreetMap via flutter_map (no API keys; same code on iOS, Android
/// and web). Pins coloured by status, `?site=` selects one, "my location"
/// uses geolocator.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({this.siteId, super.key});

  final String? siteId;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _warsaw = LatLng(52.2297, 21.0122);
  final _map = MapController();
  final _search = TextEditingController();
  LocationFix? _me;
  bool _locating = false;

  /// Zoom to `?site=` once per site, when its pin is there (a cold-start
  /// link waits for the pins).
  bool _centred = false;

  @override
  void didUpdateWidget(MapScreen old) {
    super.didUpdateWidget(old);
    // The map tab keeps its page: "Show on map" for another site lands here.
    if (old.siteId != widget.siteId) _centred = false;
  }

  @override
  void dispose() {
    _map.dispose();
    _search.dispose();
    super.dispose();
  }

  void _select(InspectionSummary i) {
    GoRouter.of(context).replace<void>(Routes.mapSite(i.siteId));
    _map.move(LatLng(i.lat!, i.lng!), 14);
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final fix = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (fix.status == LocationStatus.ok) _me = fix;
    });
    if (fix.status == LocationStatus.ok) {
      _map.move(LatLng(fix.lat!, fix.lng!), 14);
      return;
    }
    final caps = ref.read(capabilitiesProvider);
    final l = context.l10n;
    final message = switch (fix.status) {
      LocationStatus.serviceOff => l.locationServiceOff,
      LocationStatus.denied => l.mapLocationDenied,
      LocationStatus.deniedForever => l.mapLocationBlocked,
      LocationStatus.unsupported => l.locationUnsupported,
      _ => caps.isWeb ? l.mapLocationErrorWeb : l.mapLocationError,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: fix.status == LocationStatus.deniedForever && caps.openSystemSettings
            ? SnackBarAction(label: l.openSettings, onPressed: () => ref.read(permissionServiceProvider).openSettings())
            : null,
      ),
    );
  }

  void _onSearch(String q, List<InspectionSummary> items) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return;
    final hit = items.where((i) => i.site.toLowerCase().contains(query) || i.address.toLowerCase().contains(query)).firstOrNull;
    if (hit != null) {
      _select(hit);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.noSiteMatches(q))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final pins = ref.watch(mapInspectionsProvider);
    final items = pins.value ?? const <InspectionSummary>[];
    final selected = items.where((i) => i.siteId == widget.siteId).firstOrNull;
    if (selected != null && !_centred) {
      _centred = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _map.move(LatLng(selected.lat!, selected.lng!), 14);
      });
    }
    final now = ref.watch(clockProvider)();
    final tiles = ref.watch(mapTilesEnabledProvider);

    Color pinColor(InspectionSummary i) => switch (i.status) {
      _ when i == selected => scheme.primary,
      InspectionStatus.overdue => scheme.error,
      _ => scheme.secondary,
    };

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            // Labels the map's own (pan, zoom, tap) node; pins and "your
            // location" are containers, so they stay nodes of their own.
            child: Semantics(
              label: l.mapLabel,
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: selected != null ? LatLng(selected.lat!, selected.lng!) : _warsaw,
                  initialZoom: selected != null ? 14 : 11,
                  backgroundColor: scheme.surfaceContainer,
                ),
                children: [
                  if (tiles)
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'dev.flutterpoc.field_inspections',
                    ),
                  MarkerLayer(
                    markers: [
                      // 48 dp tap target for every pin (decision 13); the icon tip stays on the point.
                      for (final i in items)
                        Marker(
                          point: LatLng(i.lat!, i.lng!),
                          width: 48,
                          height: 48,
                          alignment: Alignment.topCenter,
                          child: Semantics(
                            container: true,
                            button: true,
                            label: '${i.site}, ${i.status.localized(l)}',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _select(i),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Icon(Symbols.location_on, fill: 1, size: i == selected ? 48 : 36, color: pinColor(i)),
                              ),
                            ),
                          ),
                        ),
                      if (_me case LocationFix(:final lat?, :final lng?))
                        Marker(
                          point: LatLng(lat, lng),
                          width: 28,
                          height: 28,
                          child: Semantics(
                            container: true,
                            label: l.yourLocation,
                            child: Container(
                              decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary.withValues(alpha: 0.24)),
                              alignment: Alignment.center,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: scheme.primary,
                                  border: Border.all(color: scheme.onPrimary, width: 2),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (tiles)
                    RichAttributionWidget(
                      alignment: AttributionAlignment.bottomLeft,
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => ref.read(launcherServiceProvider).open(Uri.parse('https://openstreetmap.org/copyright')),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SearchField(controller: _search, hintText: l.searchSites, elevation: 2, onSubmitted: (q) => _onSearch(q, items)),
                      // Without this an offline map is just empty.
                      if (pins.hasError && items.isEmpty) ...[
                        const SizedBox(height: 8),
                        Material(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(l.mapLoadFailed, style: TextStyle(color: scheme.onErrorContainer)),
                                ),
                                TextButton(onPressed: () => ref.invalidate(mapInspectionsProvider), child: Text(l.tryAgain)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The FAB sits right above the peek sheet, whatever the sheet's height.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FloatingActionButton.small(
                    heroTag: 'map-locate',
                    tooltip: l.showMyLocation,
                    onPressed: _locating ? null : _locate,
                    child: _locating
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Symbols.my_location),
                  ),
                ),
                if (selected != null)
                  Center(
                    child: _PeekSheet(item: selected, now: now, distance: _me?.distanceTo(selected.lat, selected.lng)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeekSheet extends ConsumerWidget {
  const _PeekSheet({required this.item, required this.now, this.distance});

  final InspectionSummary item;
  final DateTime now;
  final double? distance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final away = switch (distance) {
      null => null,
      final d when d >= 1000 => l.distanceAway('${NumberFormat('0.0', locale).format(d / 1000)} km'),
      final d => l.distanceAway('${d.round()} m'),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        elevation: 1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.extraLarge)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(item.site, style: theme.textTheme.titleLarge),
              Text([item.address, ?away, localizedWhen(context, item.scheduledAt, now)].join(' · '), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(onPressed: () => context.go(Routes.inspection(item.id)), child: Text(l.openInspection)),
                  OutlinedButton.icon(
                    onPressed: () => InspectionActions(ref, context).directions(item),
                    icon: const Icon(Symbols.directions),
                    label: Text(l.directions),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
