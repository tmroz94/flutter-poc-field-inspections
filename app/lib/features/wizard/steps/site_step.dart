import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/platform/capabilities.dart';
import '../../../core/platform/platform_services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/inspection_widgets.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/inspections_repository.dart';
import '../../../l10n/l10n.dart';
import '../wizard_controller.dart';

// ---------------------------------------------------------------- Step 1: Site

sealed class _SiteChoice {}

class _Existing extends _SiteChoice {
  _Existing(this.site);
  final SiteOption site;
}

class _AddNew extends _SiteChoice {
  _AddNew(this.name);
  final String name;
}

/// P09: site search with inline suggestions, and the optional location check.
class SiteStep extends ConsumerStatefulWidget {
  const SiteStep({required this.wizardKey, required this.errors, super.key});

  final String wizardKey;
  final Map<String, String> errors;

  @override
  ConsumerState<SiteStep> createState() => _SiteStepState();
}

class _SiteStepState extends ConsumerState<SiteStep> {
  late final _controller = TextEditingController(text: ref.read(wizardControllerProvider(widget.wizardKey)).draft.siteName);
  final _focus = FocusNode();
  Timer? _debounce;

  /// Suggestions shown inline under the field (not in an overlay: on the web,
  /// with the accessibility tree on, an overlay opening took focus from the
  /// field and closed itself, so screen-reader users couldn't pick a site).
  List<_SiteChoice> _choices = const [];
  int _highlighted = 0;
  int _lookup = 0;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _choices.isNotEmpty) setState(() => _choices = const []);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Debounced lookup (250 ms): only the last keystroke hits the API.
  void _search(String text) {
    final q = text.trim();
    _debounce?.cancel();
    final lookup = ++_lookup;
    if (q.isEmpty) {
      setState(() => _choices = const []);
      return;
    }
    final repository = ref.read(inspectionsRepositoryProvider);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      List<_SiteChoice> found;
      try {
        final sites = await repository.searchSites(q);
        final exact = sites.any((s) => s.name.toLowerCase() == q.toLowerCase());
        found = [for (final s in sites) _Existing(s), if (!exact && q.length >= 3) _AddNew(q)];
      } on Object {
        // Offline or an unreadable answer: a new site can still be named.
        found = [if (q.length >= 3) _AddNew(q)];
      }
      if (!mounted || lookup != _lookup || !_focus.hasFocus) return;
      setState(() {
        _choices = found;
        _highlighted = 0;
      });
    });
  }

  /// Arrow keys move through the suggestions, Enter picks, Escape closes.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_choices.isEmpty || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      setState(() => _highlighted = (_highlighted + step) % _choices.length);
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _select(_choices[_highlighted]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _choices = const []);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _select(_SiteChoice c) {
    _lookup++;
    _debounce?.cancel();
    setState(() => _choices = const []);
    final wizard = ref.read(wizardControllerProvider(widget.wizardKey).notifier);
    switch (c) {
      case _Existing(:final site):
        _controller.text = site.name;
        wizard.update(
          (d) => d.copyWith(
            siteId: () => site.id,
            siteName: site.name,
            siteAddress: '${site.address}, ${site.city}',
            siteLat: () => site.lat,
            siteLng: () => site.lng,
          ),
        );
      case _AddNew(:final name):
        _controller.text = name;
        wizard.update((d) => d.copyWith(siteId: () => null, siteName: name, siteAddress: ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(wizardControllerProvider(widget.wizardKey)).draft;
    final theme = Theme.of(context);
    final l = context.l10n;
    // One tap region with the field, so tapping a suggestion doesn't count as
    // a tap outside (which would unfocus the field and close the list first).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFieldTapRegion(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                onKeyEvent: _onKey,
                canRequestFocus: false,
                skipTraversal: true,
                child: TextFormField(
                  controller: _controller,
                  focusNode: _focus,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) {
                    if (_choices.isNotEmpty) _select(_choices[_highlighted]);
                  },
                  onChanged: (text) {
                    ref
                        .read(wizardControllerProvider(widget.wizardKey).notifier)
                        .update((d) => d.copyWith(siteId: () => null, siteName: text, siteAddress: ''));
                    _search(text);
                  },
                  decoration: InputDecoration(
                    labelText: l.siteLabel,
                    prefixIcon: const Icon(Symbols.search),
                    helperText: l.siteHelper,
                    errorText: widget.errors['site'],
                    suffixIcon: ListenableBuilder(
                      listenable: _controller,
                      builder: (_, _) => _controller.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: l.clear,
                              icon: const Icon(Symbols.cancel),
                              onPressed: () {
                                _controller.clear();
                                _search('');
                                ref
                                    .read(wizardControllerProvider(widget.wizardKey).notifier)
                                    .update((d) => d.copyWith(siteId: () => null, siteName: '', siteAddress: ''));
                              },
                            ),
                    ),
                  ),
                ),
              ),
              if (_choices.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _SiteOptions(query: _controller.text, options: _choices, highlighted: _highlighted, onSelected: _select),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (draft.siteId != null)
          Card.outlined(
            child: ListTile(
              leading: Icon(Symbols.check_circle, fill: 1, color: theme.colorScheme.primary),
              title: Text(draft.siteName),
              subtitle: Text(draft.siteAddress),
            ),
          )
        else if (draft.hasSite)
          Card.outlined(
            child: ListTile(
              leading: Icon(Symbols.add_location_alt, color: theme.colorScheme.primary),
              title: Text(l.newSite(draft.siteName.trim())),
              subtitle: Text(l.newSiteHint),
            ),
          ),
        const SizedBox(height: 24),
        Text(l.yourLocation, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        _LocationCheck(wizardKey: widget.wizardKey),
      ],
    );
  }
}

/// P09 "Your location": optional on-site check with accuracy and the
/// distance to the site; warns when more than 200 m away.
class _LocationCheck extends ConsumerStatefulWidget {
  const _LocationCheck({required this.wizardKey});

  final String wizardKey;

  @override
  ConsumerState<_LocationCheck> createState() => _LocationCheckState();
}

class _LocationCheckState extends ConsumerState<_LocationCheck> {
  bool _busy = false;
  LocationStatus? _problem;
  bool _canOpenSettings = false;

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final wizard = ref.read(wizardControllerProvider(widget.wizardKey).notifier);
    final canOpenSettings = ref.read(capabilitiesProvider).openSystemSettings;
    final fix = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _canOpenSettings = fix.status == LocationStatus.deniedForever && canOpenSettings;
      _problem = fix.status == LocationStatus.ok ? null : fix.status;
    });
    if (fix.status == LocationStatus.ok) {
      wizard.update((d) => d.copyWith(myLocation: () => (lat: fix.lat!, lng: fix.lng!, accuracy: fix.accuracy ?? 0)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(wizardControllerProvider(widget.wizardKey)).draft;
    final theme = Theme.of(context);
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fix = d.myLat == null ? null : LocationFix(LocationStatus.ok, lat: d.myLat, lng: d.myLng, accuracy: d.myAccuracy);
    final distance = fix?.distanceTo(d.siteLat, d.siteLng);
    final far = distance != null && distance > 200;
    final problem = switch (_problem) {
      null || LocationStatus.ok => null,
      LocationStatus.serviceOff => l.locationServiceOff,
      LocationStatus.denied => l.locationDenied,
      LocationStatus.deniedForever => l.locationBlocked,
      LocationStatus.unsupported => l.locationUnsupported,
      LocationStatus.error => l.locationError,
    };
    String distanceText(double m) => m >= 1000 ? '${NumberFormat('0.0', locale).format(m / 1000)} km' : '${m.round()} m';
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Symbols.my_location, color: theme.colorScheme.primary),
              title: Text(fix == null ? l.locationNotChecked : coordinatesText(context, fix.lat!, fix.lng!)),
              subtitle: Text(
                fix == null
                    ? l.locationOptional
                    : [
                        l.locationAccuracy('${fix.accuracy?.round() ?? '?'}'),
                        if (distance != null) l.locationFromSite(distanceText(distance)),
                      ].join(' · '),
              ),
            ),
            if (far) Text(l.locationFar, style: TextStyle(color: theme.colorScheme.tertiary)),
            if (problem != null) Text(problem, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _update,
                  icon: _busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Symbols.refresh),
                  label: Text(fix == null ? l.checkLocation : l.updateLocation),
                ),
                if (_canOpenSettings)
                  TextButton(onPressed: () => ref.read(permissionServiceProvider).openSettings(), child: Text(l.openSettings)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteOptions extends StatelessWidget {
  const _SiteOptions({required this.query, required this.options, required this.highlighted, required this.onSelected});

  final String query;
  final List<_SiteChoice> options;
  final int highlighted;
  final ValueChanged<_SiteChoice> onSelected;

  /// Bold the typed text inside a suggestion, as on P09.
  Widget _highlight(BuildContext context, String text) {
    final q = query.trim().toLowerCase();
    final i = text.toLowerCase().indexOf(q);
    if (q.isEmpty || i < 0) return Text(text);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, i)),
          TextSpan(
            text: text.substring(i, i + q.length),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: text.substring(i + q.length)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(AppRadii.extraSmall),
        color: theme.colorScheme.surfaceContainer,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320, maxWidth: 560),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, i) {
              final o = options[i];
              return ListTile(
                selected: i == highlighted,
                selectedTileColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                onTap: () => onSelected(o),
                leading: switch (o) {
                  _Existing(:final site) => Icon(siteIcon(site.icon)),
                  _AddNew() => Icon(Symbols.add_location_alt, color: theme.colorScheme.primary),
                },
                title: switch (o) {
                  _Existing(:final site) => _highlight(context, site.name),
                  _AddNew(:final name) => Text(context.l10n.addNewSite(name), style: TextStyle(color: theme.colorScheme.primary)),
                },
                subtitle: switch (o) {
                  _Existing(:final site) => Text('${site.address}, ${site.city}'),
                  _AddNew() => null,
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
