import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mock_data/mock_data.dart';

import '../../core/platform/capabilities.dart';
import '../../core/storage/key_value_store.dart';

enum PocPlatform {
  ios('iOS'),
  android('Android', short: 'Andr.'),
  web('Web'),
  macos('macOS'),
  windows('Windows', short: 'Win.'),
  linux('Linux');

  const PocPlatform(this.label, {String? short}) : short = short ?? label;
  final String label;

  /// For the narrow status columns of the phone list.
  final String short;

  /// The platform this app is running on.
  static PocPlatform of(Capabilities caps) => caps.isWeb
      ? web
      : switch (caps.platform) {
          TargetPlatform.iOS => ios,
          TargetPlatform.macOS => macos,
          TargetPlatform.windows => windows,
          TargetPlatform.linux => linux,
          _ => android,
        };
}

/// Pass, partial, fail, not tested, not applicable (codes P/H/F/U/N as on D05).
enum ResultStatus {
  pass('P'),
  partial('H'),
  fail('F'),
  notTested('U'),
  na('N');

  const ResultStatus(this.code);
  final String code;

  static ResultStatus fromCode(String c) => values.firstWhere((s) => s.code == c, orElse: () => notTested);

  bool get isTested => this == pass || this == partial || this == fail;
}

@immutable
class PlatformResult {
  const PlatformResult({this.status = ResultStatus.notTested, this.device = '', this.notes = ''});

  factory PlatformResult.fromJson(Map<String, Object?> j) => PlatformResult(
    status: ResultStatus.fromCode(j['s'] as String? ?? 'U'),
    device: j['device'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
  );

  final ResultStatus status;
  final String device;
  final String notes;

  Map<String, Object?> toJson() => {'s': status.code, 'device': device, 'notes': notes};
}

@immutable
class ScenarioResult {
  const ScenarioResult({required this.id, required this.group, required this.name, required this.byPlatform});

  final String id;
  final String group;
  final String name;
  final Map<PocPlatform, PlatformResult> byPlatform;

  PlatformResult of(PocPlatform p) => byPlatform[p] ?? const PlatformResult();

  bool get failing => byPlatform.values.any((r) => r.status == ResultStatus.fail || r.status == ResultStatus.partial);
  bool get untested => PocPlatform.values.any((p) => of(p).status == ResultStatus.notTested);
}

enum ResultsDataset { findings, sample, blank, custom }

@immutable
class ResultsState {
  const ResultsState({required this.dataset, required this.results});

  final ResultsDataset dataset;
  final List<ScenarioResult> results;

  int count(PocPlatform p, ResultStatus s) => results.where((r) => r.of(p).status == s).length;
  int tested(PocPlatform p) => results.where((r) => r.of(p).status.isTested).length;
}

/// Evidence gathered while building the PoC (Android emulator API 37,
/// Chrome on Windows). iOS needs the Mac; everything there is "not tested".
/// Format: id -> (android, web, note).
const findings = <String, (String, String, String)>{
  'adaptive-shell': ('P', 'P', 'Bar on phone; rail/extended rail when resizing Chrome'),
  'nested-routes': ('P', 'P', 'Detail tabs in ?tab=; deep links restore the tab'),
  'modals': ('P', 'P', 'Filter and result sheets have URLs; Esc closes them on web'),
  'deep-links': ('P', 'P', 'Custom scheme cold/warm on Android (cold-start drop fixed); web refresh with SPA rewrite'),
  'guards': ('H', 'P', 'Sign-in redirect + return verified; biometric lock not tried on a device (no enrolled fingerprint)'),
  'back-navigation': ('P', 'P', 'System back to list; browser back traps after reload/sign-in fixed'),
  'text-fields': ('P', 'P', 'Validators widget-tested; typed on both'),
  'autocomplete': ('H', 'P', 'Web: arrow keys + Enter verified; Android: typing only'),
  'pickers': ('P', 'P', 'Date, time and dropdown pickers driven on the emulator (wizard step 2). Chrome: same flow via flutter drive'),
  'selection-controls': (
    'P',
    'P',
    'Segmented answers, checkboxes, radios and chips driven on the emulator. Chrome: same flows via flutter drive',
  ),
  'wizard-autosave': ('P', 'P', 'Draft survived app kill (SQLite) and tab reload (SQLite WASM)'),
  'keyboard-focus': (
    'P',
    'P',
    'Android: Next/Done keyboard actions move focus and submit; hardware arrow keys and Enter pick a site since the suggestions moved inline. Chrome: arrows and Enter pick a site; with the accessibility tree on, focus used to drop when suggestions opened (fixed: inline list)',
  ),
  'search-filter-sort': ('P', 'P', 'Filters live in the URL; desktop table sort'),
  'infinite-scroll': (
    'P',
    'P',
    'Fling to page 2 and pull to refresh on the emulator; web desktop uses Load more. Chrome: Load more and the Refresh button via flutter drive',
  ),
  'swipe-actions': (
    'P',
    'P',
    'Swipe to archive and Undo on the emulator (menu on web). Chrome: row menu Archive and Undo via flutter drive',
  ),
  'list-states': ('H', 'H', 'Offline state seen on the emulator, skeleton in Chrome; empty/error in widget tests'),
  'photo-viewer': ('P', 'P', 'Opened from a notification on Android; arrow keys + URL on web'),
  'data-table': ('N', 'P', 'Desktop only (D03)'),
  'hero': ('P', 'P', 'Photo Hero flight on the emulator; removed under reduced motion. Chrome: photo Hero via flutter drive'),
  'page-transitions': ('P', 'P', 'Android transitions on the emulator; none under reduced motion. Chrome: via flutter drive'),
  'animated-list': ('P', 'P', 'Photo grid scales items in and out on the emulator. Chrome: via flutter drive'),
  'implicit-explicit': ('P', 'P', 'Success animation and animated grid on the emulator. Chrome: via flutter drive'),
  'reduced-motion': (
    'P',
    'P',
    'App setting removes page transitions and Hero flights (fixed: Hero still flew before). Chrome: via flutter drive',
  ),
  'rest-json': ('P', 'P', 'Android emulator via 10.0.2.2; Chrome with CORS'),
  'state-management': ('P', 'P', 'Riverpod throughout'),
  'local-storage': ('P', 'P', 'drift: native SQLite / SQLite WASM on IndexedDB'),
  'sync-retry': ('P', 'U', 'Airplane mode on the emulator: submit queued, synced to the mock server when back online'),
  'camera': (
    'P',
    'P',
    'Android: system camera app and photo picker driven with Patrol on the emulator; web uses the file input. Chrome: Use camera opens the browser file input; the picked photo lands in the grid (Playwright)',
  ),
  'files-export': ('P', 'P', 'Android: Export PDF opens the system share sheet (Patrol); web: PDF downloaded'),
  'geolocation': (
    'H',
    'P',
    'Permission, position and distance/warning on the emulator via Android LocationManager; Play services fused provider needs a real-GPS check. Chrome: granted position with distance and warning, and a denied permission (Playwright)',
  ),
  'maps': ('P', 'P', 'flutter_map + OSM tiles, pins, ?site= link (0x0 layout bug fixed)'),
  'notifications': (
    'P',
    'P',
    'Android: notification permission dialog, scheduled notification; tap after the app was killed cold-starts on its route (fixed: the tap was dropped). Chrome: shown via the service worker; a click opens its route, also when the tab was closed (Playwright)',
  ),
  'share-maps': ('U', 'U', 'Launcher widget-tested'),
  'biometrics': (
    'H',
    'N',
    'Android: real system prompt to turn the lock on and to unlock after 5 min in the background, answered with the device PIN; no fingerprint enrolled on the emulator. Not available on web',
  ),
  'permissions': (
    'P',
    'P',
    'Android: location Allow and Deny in the system dialog (Patrol); notification permission granted. Chrome: notification and location permissions granted and denied (Playwright)',
  ),
  'clipboard-haptics': ('U', 'H', 'Copy link on web; haptics widget-tested'),
  'themes': ('P', 'P', 'Dark theme switched live in the Android integration test; light/dark in Chrome; contrast in goldens'),
  'responsive': ('P', 'P', 'Phone on emulator; phone/tablet/desktop widths in Chrome'),
  'l10n': (
    'P',
    'P',
    'EN/PL with gen-l10n; live switch to Polish in the Android integration test. Chrome: live switch to Polish via flutter drive',
  ),
  'a11y': ('H', 'H', 'Tap-target, label and contrast guidelines plus 200% text pass in tests; no TalkBack/screen-reader run yet'),
  'adaptive-widgets': ('P', 'U', 'Material and Cupertino (incl. CupertinoAlertDialog) on the emulator'),
  'diagnostics': ('P', 'P', 'Real device/version/renderer values on the emulator and in the Chrome wasm build'),
  'results-tracker': ('P', 'H', 'Seen on the emulator; export/import widget-tested'),
  'automated-tests': (
    'P',
    'P',
    '270+ unit/widget/a11y/golden tests on the host; 9 device tests on the emulator (incl. airplane mode and GPS via the host helper); Chrome needs chromedriver. Chrome: integration_test via flutter drive; browser prompts and JS vs Wasm timings with Playwright',
  ),
};

class ResultsController extends Notifier<ResultsState> {
  static const _key = 'poc_results';

  @override
  ResultsState build() {
    final raw = ref.watch(keyValueStoreProvider).getString(_key);
    if (raw != null) {
      try {
        return _fromJson(jsonDecode(raw) as Map<String, Object?>);
      } on Object {
        // Fall through to the default dataset.
      }
    }
    return load(ResultsDataset.findings, persist: false);
  }

  static ScenarioResult _seedRow(ScenarioSeed s, ResultsDataset dataset) {
    PlatformResult r(String code, String note) => PlatformResult(status: ResultStatus.fromCode(code), notes: note);
    return switch (dataset) {
      ResultsDataset.sample => ScenarioResult(
        id: s.id,
        group: s.group,
        name: s.name,
        byPlatform: {PocPlatform.ios: r(s.ios, ''), PocPlatform.android: r(s.android, ''), PocPlatform.web: r(s.web, s.note)},
      ),
      ResultsDataset.findings => () {
        final f = findings[s.id] ?? ('U', 'U', '');
        return ScenarioResult(
          id: s.id,
          group: s.group,
          name: s.name,
          byPlatform: {
            PocPlatform.ios: const PlatformResult(),
            PocPlatform.android: PlatformResult(status: ResultStatus.fromCode(f.$1), device: 'Android emulator, API 37', notes: f.$3),
            PocPlatform.web: PlatformResult(status: ResultStatus.fromCode(f.$2), device: 'Chrome, Windows 11', notes: f.$3),
          },
        );
      }(),
      _ => ScenarioResult(id: s.id, group: s.group, name: s.name, byPlatform: const {}),
    };
  }

  ResultsState load(ResultsDataset dataset, {bool persist = true}) {
    final next = ResultsState(dataset: dataset, results: [for (final s in scenarioSeed) _seedRow(s, dataset)]);
    if (persist) _save(next);
    return state = next;
  }

  void setResult(String id, PocPlatform p, PlatformResult r) {
    final next = ResultsState(
      dataset: ResultsDataset.custom,
      results: [
        for (final s in state.results)
          s.id == id ? ScenarioResult(id: s.id, group: s.group, name: s.name, byPlatform: {...s.byPlatform, p: r}) : s,
      ],
    );
    _save(next);
    state = next;
  }

  void _save(ResultsState s) => ref.read(keyValueStoreProvider).setString(_key, jsonEncode(toJson(s)));

  static Map<String, Object?> toJson(ResultsState s) => {
    'format': 'field-inspections-poc-results/1',
    'dataset': s.dataset.name,
    'results': [
      for (final r in s.results)
        {'id': r.id, 'group': r.group, 'name': r.name, for (final p in PocPlatform.values) p.name: r.of(p).toJson()},
    ],
  };

  static ResultsState _fromJson(Map<String, Object?> j) {
    final rows = {for (final r in (j['results'] as List?) ?? const []) (r as Map)['id']: r.cast<String, Object?>()};
    return ResultsState(
      dataset: ResultsDataset.values.asNameMap()[j['dataset']] ?? ResultsDataset.custom,
      results: [
        for (final s in scenarioSeed)
          ScenarioResult(
            id: s.id,
            group: s.group,
            name: s.name,
            byPlatform: {
              for (final p in PocPlatform.values)
                if (rows[s.id]?[p.name] case final Map<Object?, Object?> m) p: PlatformResult.fromJson(m.cast<String, Object?>()),
            },
          ),
      ],
    );
  }

  /// Imports a JSON export. Throws [FormatException] for other files.
  void importJson(String text) {
    final j = jsonDecode(text);
    if (j is! Map<String, Object?> || j['format'] != 'field-inspections-poc-results/1') {
      throw const FormatException('Not a PoC results export');
    }
    final imported = _fromJson(j);
    final next = ResultsState(dataset: ResultsDataset.custom, results: imported.results);
    _save(next);
    state = next;
  }

  static String toCsv(ResultsState s) {
    String cell(String v) => v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
    final header = [
      'group',
      'scenario',
      for (final p in PocPlatform.values) ...['${p.name}_status', '${p.name}_device', '${p.name}_notes'],
    ];
    final lines = [
      header.join(','),
      for (final r in s.results)
        [
          r.group,
          r.name,
          for (final p in PocPlatform.values) ...[r.of(p).status.name, r.of(p).device, r.of(p).notes],
        ].map(cell).join(','),
    ];
    return '${lines.join('\n')}\n';
  }
}

final resultsProvider = NotifierProvider<ResultsController, ResultsState>(ResultsController.new);
