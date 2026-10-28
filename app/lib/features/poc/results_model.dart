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
  macos('macOS', short: 'Mac'),
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

  /// Tolerates wrong types (imported files): they read as empty.
  factory PlatformResult.fromJson(Map<String, Object?> j) {
    String text(Object? v) => v is String ? v : '';
    final notes = text(j['notes']);
    return PlatformResult(
      status: ResultStatus.fromCode(text(j['s'])),
      device: text(j['device']),
      notes: notes.length > maxNotes ? notes.substring(0, maxNotes) : notes,
    );
  }

  /// Notes limit from the result sheet (decision 58), also applied to imports.
  static const maxNotes = 1000;

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
/// Chrome on Windows). iOS is in [iosFindings], the desktop apps in
/// [desktopFindings].
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

/// The iPhone and iPad simulators (docs/platform-setup.md): the 7 shared flows
/// and the platform probe on each, plus prompts, notifications, Face ID, links
/// and the tablet layouts driven by hand with simctl. The PoC has no physical
/// devices (decision 117), so the camera, real GPS, real Face ID and the app's
/// page in Settings stay partial. "Flows" below means the shared flows.
/// Format: id -> (status, note).
const iosFindings = <String, (String, String)>{
  'adaptive-shell': (
    'P',
    'Bottom bar on the iPhone; rail on the iPad Pro 13" in portrait (1032 pt), extended rail with New inspection in landscape (1376 pt); flows on the iPhone, iPad mini and iPad Pro',
  ),
  'nested-routes': ('P', 'Detail tabs in ?tab= after a deep link (flows)'),
  'modals': ('H', 'Filter sheet (flows) and the Cupertino alert dialog; other sheets not checked'),
  'deep-links': (
    'P',
    'fieldinspections:// (simctl openurl) while running, after sign-in and from a cold start, ?site= included; on the iPad a detail link with ?tab= opens beside the list. Universal links need a developer team',
  ),
  'guards': ('P', 'Sign-in redirect and return; simulated Face ID: a cold start locks, no match stays locked, a match opens Home'),
  'back-navigation': ('P', 'Edge swipe back follows the finger; back from a deep-linked detail to the list (flows)'),
  'text-fields': ('P', 'Typed in the flows; validators widget-tested'),
  'autocomplete': ('P', 'Site suggestions picked in the wizard (flows)'),
  'pickers': ('P', 'Date, time and dropdown pickers in the wizard (flows)'),
  'selection-controls': ('P', 'Segmented answers, checkboxes, radios and chips (flows)'),
  'wizard-autosave': ('P', 'Draft survives an app restart (native SQLite)'),
  'keyboard-focus': ('P', 'Next/Done on the software keyboard move focus and submit (flows)'),
  'search-filter-sort': ('P', 'Filter sheet selection lands in the URL (flows)'),
  'infinite-scroll': ('P', 'Fling to the next page and pull to refresh (flows)'),
  'swipe-actions': ('P', 'Swipe to archive and Undo (flows)'),
  'list-states': (
    'P',
    'Against the mock API: the loading skeleton (server slowed to 3 s), an empty search, and with the server stopped the offline banner and error with Try again, which recovers once it is back',
  ),
  'photo-viewer': ('P', "Opened from the detail's photos (flows)"),
  'data-table': (
    'P',
    'iPad Pro 13" in landscape (1376 pt): the sortable table beside the detail, selected row outlined. Phones and portrait iPads use the list',
  ),
  'hero': ('P', 'Photo Hero flight; removed under reduced motion (flows)'),
  'page-transitions': ('P', 'Cupertino transitions animate; none under reduced motion (flows)'),
  'animated-list': ('P', 'Photo grid scales items in and out (flows)'),
  'implicit-explicit': ('P', 'Success animation and animated grid (flows)'),
  'reduced-motion': ('P', 'App setting removes page transitions and Hero flights (flows)'),
  'rest-json': (
    'P',
    'iPhone and iPad Pro against the mock API (BACKEND=auto found it): sign-in, lists and paging, detail, notifications, reference data; the flows use the in-app fake',
  ),
  'state-management': ('P', 'Riverpod throughout'),
  'local-storage': ('P', 'drift on native SQLite; a draft survives a restart (flows)'),
  'sync-retry': ('U', ''),
  'camera': (
    'H',
    'Camera prompt, then "Camera not available" (the simulator has none); gallery through the system picker and a PDF from Files work',
  ),
  'files-export': ('P', 'Export PDF opens the iOS share sheet; Save to Files gives inspection-INS-1042.pdf (2 pages)'),
  'geolocation': ('H', 'Location prompt, then my location on the map from a simulated position; real GPS needs a phone'),
  'maps': ('P', 'OSM tiles, pins and my location; ?site= link from a cold start (probe and by hand)'),
  'notifications': (
    'P',
    'Banner over the open app; opened from Notification Center onto its route, in the background and after the app was killed',
  ),
  'share-maps': ('U', ''),
  'biometrics': (
    'H',
    'Simulated Face ID: turning the lock on asks once, no match shows "Face Not Recognised", a match unlocks; real Face ID needs a phone',
  ),
  'permissions': (
    'H',
    'Location, camera and notification prompts with the Info.plist texts; denied camera/location show the banner and snackbar, but "Open settings" lands on the top of Settings, not the app\'s page',
  ),
  'clipboard-haptics': ('U', ''),
  'themes': ('P', 'Dark theme switched live (flows)'),
  'responsive': (
    'P',
    'iPhone, iPad mini and iPad Pro 13" (portrait and landscape): list and detail side by side, Settings with Appearance beside it, the two-pane sign-in card, the wizard step bar',
  ),
  'l10n': ('P', 'Live switch to Polish (flows)'),
  'a11y': ('H', 'Guideline and 200% text tests on the host; no VoiceOver run'),
  'adaptive-widgets': ('P', 'Cupertino by default on iOS: switch, slider, activity indicator, date picker, CupertinoAlertDialog'),
  'diagnostics': ('P', 'Real device and permission values; permission states update on return from Settings'),
  'results-tracker': ('H', 'Opened from a link: summaries and the per-platform grid; editing and export not tried on iOS'),
  'automated-tests': (
    'P',
    'The 7 shared flows and the platform probe on the iPhone 18 Pro (iOS 27.0), iPad mini and iPad Pro 13" (iPadOS 26.5) simulators, one file per run',
  ),
};

/// The desktop apps (docs/platform-setup.md): the 7 shared flows and the
/// platform probe on each, deep links by hand; nothing that needs a click in
/// system UI (prompts, file dialogs) was tried. "Flows" below means those.
/// Format: id -> (macOS, Windows, Linux, note).
const desktopFindings = <String, (String, String, String, String)>{
  'adaptive-shell': (
    'H',
    'P',
    'H',
    'Windows: flows at 500, 700, 1000 and 1280 px windows (bar, rail, extended rail); macOS and Linux: 1280 px only',
  ),
  'nested-routes': ('P', 'P', 'P', 'Detail tabs in ?tab= after a deep link (flows)'),
  'modals': ('H', 'H', 'H', 'Filter sheet opened and applied in the flows; Esc and the focus trap not checked'),
  'deep-links': (
    'P',
    'P',
    'P',
    'fieldinspections:// opens its page in the running app and from a cold start (release); Windows and Linux pass a second process\'s link to the open window',
  ),
  'guards': (
    'H',
    'H',
    'P',
    'Sign-in redirect and return in the flows; the Touch ID / Windows Hello lock prompt not tried (Linux has no lock)',
  ),
  'back-navigation': ('P', 'P', 'P', 'Back from a deep-linked detail to the list (flows)'),
  'text-fields': ('P', 'P', 'P', 'Typed in the flows; validators widget-tested'),
  'autocomplete': ('P', 'P', 'P', 'Arrow keys and Enter pick a site (flows)'),
  'pickers': ('P', 'P', 'P', 'Date, time and dropdown pickers in the wizard (flows)'),
  'selection-controls': ('P', 'P', 'P', 'Segmented answers, checkboxes, radios and chips (flows)'),
  'wizard-autosave': ('P', 'P', 'P', 'Draft survives an app restart (native SQLite)'),
  'keyboard-focus': ('P', 'P', 'P', 'Next/Done move focus and submit; arrow keys and Enter in the site suggestions (flows)'),
  'search-filter-sort': ('P', 'P', 'P', 'Filter sheet and sort land in the URL (flows); table sort widget-tested'),
  'infinite-scroll': ('P', 'P', 'P', 'Load more in the desktop table and the Refresh button (flows)'),
  'swipe-actions': ('P', 'P', 'P', 'Row menu Archive and Undo; no swipe with a mouse (flows)'),
  'list-states': (
    'P',
    'U',
    'U',
    'macOS against the mock API: the table-shaped loading skeleton, an empty search, and with the server stopped the offline banner and error with Try again; Windows and Linux: widget tests only',
  ),
  'photo-viewer': ('P', 'P', 'P', "Opened from the detail's photos (flows)"),
  'data-table': ('P', 'P', 'P', 'Desktop table (D03) at 1280 px: Load more and the row menu (flows)'),
  'hero': ('P', 'P', 'P', 'Photo Hero flight; removed under reduced motion (flows)'),
  'page-transitions': ('P', 'P', 'P', 'Transitions animate; none under reduced motion (flows)'),
  'animated-list': ('P', 'P', 'P', 'Photo grid scales items in and out (flows)'),
  'implicit-explicit': ('P', 'P', 'P', 'Success animation and animated grid (flows)'),
  'reduced-motion': ('P', 'P', 'P', 'App setting removes page transitions and Hero flights (flows)'),
  'rest-json': (
    'P',
    'U',
    'U',
    "macOS against the mock API (BACKEND=auto found it): a restored session, lists, search and filters, notifications, reference data. The flows use the in-app fake; Windows and Linux weren't run against it",
  ),
  'state-management': ('P', 'P', 'P', 'Riverpod throughout'),
  'local-storage': ('P', 'P', 'P', "drift on native SQLite in the app's support folder; a draft survives a restart (flows)"),
  'sync-retry': ('U', 'U', 'U', ''),
  'camera': (
    'H',
    'H',
    'H',
    'No camera on desktop: Gallery and the photo grid with a fake picker (flows); the real file dialog and drag and drop not tried',
  ),
  'files-export': ('U', 'U', 'U', 'Export PDF opens a Save dialog; not tried'),
  'geolocation': ('H', 'H', 'N', 'Service and permission state read by the probe (no prompt, no position); Linux has no geolocator plugin'),
  'maps': ('H', 'H', 'H', 'OSM tiles load on /map (probe); pins and ?site= not checked'),
  'notifications': (
    'H',
    'H',
    'H',
    "The plugin starts and reports its permission (probe); a shown notification and its tap not tried. Linux can't schedule",
  ),
  'share-maps': ('U', 'U', 'U', ''),
  'biometrics': (
    'H',
    'H',
    'N',
    'Touch ID / Windows Hello available with biometrics enrolled (probe); the prompt not tried. Not offered on Linux',
  ),
  'permissions': ('H', 'H', 'H', 'States read by the probe; the system prompts not tried'),
  'clipboard-haptics': ('U', 'U', 'U', ''),
  'themes': ('P', 'P', 'P', 'Dark theme switched live (flows)'),
  'responsive': ('H', 'P', 'H', 'Windows: flows at 500, 700, 1000 and 1280 px windows; macOS and Linux: 1280 px only'),
  'l10n': ('P', 'P', 'P', 'Live switch to Polish (flows)'),
  'a11y': ('H', 'H', 'H', 'Guideline and 200% text tests on the host; no VoiceOver, Narrator or Orca run'),
  'adaptive-widgets': ('U', 'U', 'U', ''),
  'diagnostics': ('H', 'H', 'H', 'Device and app info read by the probe; the Diagnostics screen not checked'),
  'results-tracker': ('U', 'U', 'U', ''),
  'automated-tests': (
    'P',
    'P',
    'P',
    'The 7 shared flows and the platform probe, one file per run; Linux on every push in CI (xvfb), Windows and macOS by hand; Windows also at 4 window widths',
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
        final i = iosFindings[s.id] ?? ('U', '');
        final f = findings[s.id] ?? ('U', 'U', '');
        final d = desktopFindings[s.id] ?? ('U', 'U', 'U', '');
        return ScenarioResult(
          id: s.id,
          group: s.group,
          name: s.name,
          byPlatform: {
            PocPlatform.ios: PlatformResult(
              status: ResultStatus.fromCode(i.$1),
              device: 'iPhone 18 Pro (iOS 27.0), iPad mini and iPad Pro 13" (iPadOS 26.5) simulators',
              notes: i.$2,
            ),
            PocPlatform.android: PlatformResult(status: ResultStatus.fromCode(f.$1), device: 'Android emulator, API 37', notes: f.$3),
            PocPlatform.web: PlatformResult(status: ResultStatus.fromCode(f.$2), device: 'Chrome, Windows 11', notes: f.$3),
            PocPlatform.macos: PlatformResult(status: ResultStatus.fromCode(d.$1), device: 'macOS 27, Apple silicon', notes: d.$4),
            PocPlatform.windows: PlatformResult(status: ResultStatus.fromCode(d.$2), device: 'Windows 11, x64', notes: d.$4),
            PocPlatform.linux: PlatformResult(
              status: ResultStatus.fromCode(d.$3),
              device: 'Ubuntu 26.04 in WSL 2 (x64), Ubuntu 24.04 container (arm64)',
              notes: d.$4,
            ),
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
    final rows = {
      for (final r in switch (j['results']) {
        final List<Object?> list => list,
        _ => const <Object?>[],
      })
        if (r is Map) r['id']: r.cast<String, Object?>(),
    };
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

  /// Imports a JSON export. Throws [FormatException] for other files,
  /// including ones with the right format tag but the wrong shape.
  void importJson(String text) {
    final j = jsonDecode(text);
    if (j is! Map<String, Object?> || j['format'] != 'field-inspections-poc-results/1') {
      throw const FormatException('Not a PoC results export');
    }
    final results = j['results'];
    final shapeOk =
        results is List &&
        results.every((r) => r is Map && r['id'] is String && PocPlatform.values.every((p) => r[p.name] == null || r[p.name] is Map));
    if (!shapeOk) throw const FormatException('Results have the wrong shape');
    final imported = _fromJson(j);
    final next = ResultsState(dataset: ResultsDataset.custom, results: imported.results);
    _save(next);
    state = next;
  }

  /// CSV per RFC 4180 (CRLF lines) with a UTF-8 byte order mark, so Excel
  /// opens Polish letters correctly. Cells starting with = + - @ are prefixed
  /// with ' so spreadsheets don't run them as formulas.
  static String toCsv(ResultsState s) {
    String cell(String raw) {
      final v = raw.startsWith(RegExp(r'[=+\-@\t\r]')) ? "'$raw" : raw;
      return v.contains(RegExp(r'[",\r\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
    }

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
    return '\uFEFF${lines.join('\r\n')}\r\n';
  }
}

final resultsProvider = NotifierProvider<ResultsController, ResultsState>(ResultsController.new);
