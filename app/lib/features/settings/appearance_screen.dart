import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_settings.dart';
import '../../core/widgets/adaptive_segments.dart';
import '../../core/widgets/inspection_widgets.dart';
import '../../data/models/inspection.dart';
import '../../l10n/l10n.dart';

/// P20 (phone page) and the right pane of T03: everything re-themes live.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.appearanceAndLanguage)),
    body: const SingleChildScrollView(padding: EdgeInsets.fromLTRB(16, 8, 16, 32), child: AppearanceView()),
  );
}

class AppearanceView extends ConsumerStatefulWidget {
  const AppearanceView({this.twoColumns = false, super.key});

  /// T03 lays the controls out in two columns.
  final bool twoColumns;

  @override
  ConsumerState<AppearanceView> createState() => _AppearanceViewState();
}

class _AppearanceViewState extends ConsumerState<AppearanceView> {
  /// Text size while the slider moves. Saving it on every tick re-laid out
  /// the whole app under the finger and wrote to storage each time.
  double? _dragScale;
  Timer? _commit;

  @override
  void dispose() {
    _commit?.cancel();
    super.dispose();
  }

  void _setScale(double percent) {
    final scale = (percent / 5).round() * 5 / 100;
    setState(() => _dragScale = scale);
    // Keyboard and screen-reader steps don't always end with onChangeEnd.
    _commit?.cancel();
    _commit = Timer(const Duration(milliseconds: 600), _saveScale);
  }

  void _saveScale() {
    _commit?.cancel();
    final scale = _dragScale;
    if (scale == null || !mounted) return;
    ref.read(themeSettingsProvider.notifier).update((x) => x.copyWith(textScale: () => scale));
    setState(() => _dragScale = null);
  }

  @override
  Widget build(BuildContext context) {
    final twoColumns = widget.twoColumns;
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = ref.watch(themeSettingsProvider);
    final controller = ref.read(themeSettingsProvider.notifier);
    final systemScale = MediaQuery.of(context).textScaler.scale(1);
    final scale = _dragScale ?? s.textScale ?? systemScale.clamp(ThemeSettings.minTextScale, ThemeSettings.maxTextScale);
    final locale = s.locale?.languageCode;
    final label = theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    Widget section(String title, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title, style: label),
        ),
        child,
      ],
    );

    // Segments that turn into wrapping chips at large text sizes (decision 64).
    final themeMode = section(
      l.theme,
      AdaptiveSegments<ThemeMode>(
        segments: [(ThemeMode.system, l.themeSystem), (ThemeMode.light, l.themeLight), (ThemeMode.dark, l.themeDark)],
        selected: s.mode,
        onChanged: (v) => controller.update((x) => x.copyWith(mode: v)),
      ),
    );

    // System follows the OS high-contrast setting (null in the settings).
    final contrast = section(
      l.contrast,
      AdaptiveSegments<AppContrast?>(
        segments: [
          (null, l.themeSystem),
          (AppContrast.standard, l.contrastStandard),
          (AppContrast.medium, l.contrastMedium),
          (AppContrast.high, l.contrastHigh),
        ],
        selected: s.contrast,
        onChanged: (v) => controller.update((x) => x.copyWith(contrast: () => v)),
      ),
    );

    final textSize = section(
      l.textSize,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.textSizeHint, style: theme.textTheme.bodySmall)),
              Text('${(scale * 100).round()}%', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
          Slider(
            value: (scale * 100).roundToDouble(),
            min: ThemeSettings.minTextScale * 100,
            max: ThemeSettings.maxTextScale * 100,
            divisions: 23,
            label: '${(scale * 100).round()}%',
            semanticFormatterCallback: (v) => '${v.round()}%',
            onChanged: _setScale,
            onChangeEnd: (_) => _saveScale(),
          ),
          if (s.textScale != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => controller.update((x) => x.copyWith(textScale: () => null)),
                child: Text(l.useSystemSize),
              ),
            ),
        ],
      ),
    );

    final motion = SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l.reduceMotion),
      subtitle: Text(l.reduceMotionHint),
      value: s.reduceMotion,
      onChanged: (v) => controller.update((x) => x.copyWith(reduceMotion: v)),
    );

    final language = section(
      l.language,
      RadioGroup<String?>(
        groupValue: locale,
        onChanged: (v) => controller.update((x) => x.copyWith(locale: () => v == null ? null : Locale(v))),
        child: Column(
          children: [
            RadioListTile<String?>(value: null, title: Text(l.languageSystem), contentPadding: EdgeInsets.zero),
            const RadioListTile<String?>(value: 'en', title: Text('English'), contentPadding: EdgeInsets.zero),
            const RadioListTile<String?>(value: 'pl', title: Text('Polski'), contentPadding: EdgeInsets.zero),
          ],
        ),
      ),
    );

    final controls = twoColumns
        ? Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: themeMode),
                  const SizedBox(width: 24),
                  Expanded(child: contrast),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: textSize),
                  const SizedBox(width: 24),
                  Expanded(child: motion),
                ],
              ),
              const SizedBox(height: 24),
              language,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              themeMode,
              const SizedBox(height: 24),
              contrast,
              const SizedBox(height: 24),
              textSize,
              const SizedBox(height: 8),
              motion,
              const SizedBox(height: 16),
              language,
            ],
          );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const _Preview(), const SizedBox(height: 24), controls]);
  }
}

/// Live preview: localized strings, Polish plural forms, the overdue chip.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.preview, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(l.previewSite, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              [
                for (final n in const [1, 3, 5, 22]) l.inspectionsCount(n),
              ].join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            const StatusChip(InspectionStatus.overdue),
          ],
        ),
      ),
    );
  }
}
