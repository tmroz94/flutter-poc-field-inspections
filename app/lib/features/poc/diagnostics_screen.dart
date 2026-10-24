import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app/code_stats.g.dart';
import '../../core/layout/window_size.dart';
import '../../core/platform/capabilities.dart';
import '../../core/platform/device_summary.dart';
import '../../core/platform/frame_stats.dart';
import '../../core/platform/notification_service.dart';
import '../../core/platform/platform_services.dart';
import '../../data/local/app_database.dart';
import '../../data/local/local_store.dart';
import '../../data/sync/sync_service.dart';
import '../../l10n/l10n.dart';

/// Runtime permission states for the four permissions the app uses.
/// Notifications come from the notification service, which also works on web.
final permissionStatesProvider = FutureProvider.autoDispose<Map<AppPermission, PermissionState>>((ref) async {
  final perms = ref.watch(permissionServiceProvider);
  return {
    for (final p in AppPermission.values)
      p: p == AppPermission.notifications ? await ref.watch(notificationServiceProvider).permission() : await perms.status(p),
  };
});

String get _buildMode => kReleaseMode ? 'Release' : (kProfileMode ? 'Profile' : 'Debug');

String _renderer(bool isWeb) {
  if (!isWeb) return 'Impeller';
  return const bool.fromEnvironment('dart.tool.dart2wasm') ? 'Skwasm (WebAssembly)' : 'CanvasKit (JavaScript)';
}

enum _Tone { normal, good, bad }

typedef _Row = (String key, String value, _Tone tone);

/// P24: app, device, data and permission facts, with Copy report.
class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  (String, _Tone) _permission(PermissionState? s) => switch (s) {
    null => ('…', _Tone.normal),
    PermissionState.granted => ('Granted', _Tone.good),
    PermissionState.limited => ('Limited', _Tone.normal),
    PermissionState.denied => ('Not granted', _Tone.normal),
    PermissionState.permanentlyDenied => ('Denied', _Tone.bad),
    PermissionState.unsupported => ('Handled by the browser', _Tone.normal),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final caps = ref.watch(capabilitiesProvider);
    final summary = ref.watch(deviceSummaryProvider).value;
    final perms = ref.watch(permissionStatesProvider).value;
    final online = ref.watch(connectivityProvider).value ?? true;
    final sync = ref.watch(syncServiceProvider);
    final drafts = ref.watch(draftsProvider).value?.length ?? 0;
    final outbox = ref.watch(outboxProvider).value?.length ?? 0;
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final frames = FrameStats.instance;

    final groups = <(String, IconData, List<_Row>)>[
      (
        'App',
        Symbols.apps,
        [
          ('Version', summary == null ? '…' : '${summary.version} (build ${summary.build})', _Tone.normal),
          (
            'Flutter / Dart',
            '${FlutterVersion.version ?? 'unknown'} / ${FlutterVersion.dartVersion?.split(' ').first ?? 'unknown'}',
            _Tone.normal,
          ),
          ('Build mode', _buildMode, _Tone.normal),
          ('Renderer', _renderer(caps.isWeb), _Tone.normal),
          ('Shared code', '${codeStats.sharedPercent}% (${codeStats.shared} / ${codeStats.platformSpecific} lines)', _Tone.normal),
          (
            'Frames since start',
            frames.frames == 0
                ? 'Not reported'
                : '${frames.frames} · build ${frames.avgBuildMs.toStringAsFixed(1)} ms · raster ${frames.avgRasterMs.toStringAsFixed(1)} ms',
            _Tone.normal,
          ),
          (
            'Over 16 ms',
            frames.frames == 0 ? '–' : '${frames.slowPercent.toStringAsFixed(1)}%',
            frames.slowPercent > 5 ? _Tone.bad : _Tone.normal,
          ),
        ],
      ),
      (
        'Device and display',
        Symbols.smartphone,
        [
          ('Platform', summary?.device ?? '…', _Tone.normal),
          ('Window', '${size.width.round()} × ${size.height.round()} · ${context.windowSize.label}', _Tone.normal),
          (
            'Pixel ratio · text scale',
            '${mq.devicePixelRatio.toStringAsFixed(1)} · ${mq.textScaler.scale(1).toStringAsFixed(2)}',
            _Tone.normal,
          ),
          ('Locale · brightness', '$locale · ${theme.brightness == Brightness.dark ? 'Dark' : 'Light'}', _Tone.normal),
        ],
      ),
      (
        'Data and sync',
        Symbols.cloud_sync,
        [
          ('Connection', online ? 'Online' : 'Offline', online ? _Tone.good : _Tone.bad),
          ('Last sync', sync.lastSyncAt == null ? 'Not yet' : localizedWhen(context, sync.lastSyncAt!, DateTime.now()), _Tone.normal),
          ('Outbox', '$drafts drafts · $outbox waiting', _Tone.normal),
          ('Local database', caps.isWeb ? 'SQLite WASM (${AppDatabase.webStorage ?? 'IndexedDB'})' : 'SQLite', _Tone.normal),
        ],
      ),
      (
        'Permissions',
        Symbols.shield,
        [
          for (final (p, label) in const [
            (AppPermission.camera, 'Camera'),
            (AppPermission.location, 'Location'),
            (AppPermission.photos, 'Photos'),
            (AppPermission.notifications, 'Notifications'),
          ])
            (label, _permission(perms?[p]).$1, _permission(perms?[p]).$2),
        ],
      ),
    ];

    String report() => [
      for (final (name, _, rows) in groups) ...['## $name', for (final (k, v, _) in rows) '$k: $v', ''],
    ].join('\n');

    Color color(_Tone t) => switch (t) {
      _Tone.normal => theme.colorScheme.onSurface,
      _Tone.good => theme.colorScheme.primary,
      _Tone.bad => theme.colorScheme.error,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diagnostics),
        actions: [
          IconButton(
            tooltip: 'Copy report',
            icon: const Icon(Symbols.content_copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report copied to clipboard')));
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final (name, icon, rows) in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Semantics(
                header: true,
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(name, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                    ),
                  ],
                ),
              ),
            ),
            for (final (k, v, tone) in rows)
              MergeSemantics(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(k, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          flex: 2,
                          child: Text(
                            v,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: color(tone)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await ref.read(notificationServiceProvider).requestPermission();
                    ref.invalidate(permissionStatesProvider);
                  },
                  icon: const Icon(Symbols.notifications_active),
                  label: const Text('Ask for notifications'),
                ),
                // Reset, use the screen you want to measure, then come back.
                TextButton(
                  onPressed: () {
                    frames.reset();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Frame stats reset')));
                  },
                  child: const Text('Reset frame stats'),
                ),
                if (caps.openSystemSettings)
                  TextButton(onPressed: () => ref.read(permissionServiceProvider).openSettings(), child: const Text('System settings')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
