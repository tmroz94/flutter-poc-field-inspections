import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models/inspection.dart';
import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// "Now" for relative dates; tests pin it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Material Symbols for the backend's icon names.
IconData siteIcon(String name) => switch (name) {
  'warehouse' => Symbols.warehouse,
  'apartment' => Symbols.apartment,
  'bolt' => Symbols.bolt,
  'ac_unit' => Symbols.ac_unit,
  'local_parking' => Symbols.local_parking,
  'solar_power' => Symbols.solar_power,
  'roofing' => Symbols.roofing,
  'water_pump' => Symbols.water_pump,
  'cloud_done' => Symbols.cloud_done,
  'save' => Symbols.save,
  'play_circle' => Symbols.play_circle,
  'assignment_ind' => Symbols.assignment_ind,
  'error' => Symbols.error,
  'alarm' => Symbols.alarm,
  'task_alt' => Symbols.task_alt,
  _ => Symbols.location_on,
};

/// Status pill from the boards: container colour + icon + label.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {this.outlined = false, super.key});

  final InspectionStatus status;

  /// For a selected row: its highlight (secondaryContainer) is Scheduled's
  /// fill and close to In progress's, so the chip drops the fill and draws an
  /// outline, icon and label in onSecondaryContainer, the one colour that reads
  /// on the highlight in every scheme (the status colours don't in the medium
  /// and high contrast ones). The icon and label still tell the statuses apart.
  /// Same size either way.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, statusFg, icon) = switch (status) {
      InspectionStatus.scheduled => (scheme.secondaryContainer, scheme.onSecondaryContainer, Symbols.schedule),
      InspectionStatus.inProgress => (scheme.primaryContainer, scheme.onPrimaryContainer, Symbols.pending),
      InspectionStatus.draft => (scheme.tertiaryContainer, scheme.onTertiaryContainer, Symbols.edit_note),
      InspectionStatus.overdue => (scheme.errorContainer, scheme.onErrorContainer, Symbols.error),
      InspectionStatus.submitted => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, Symbols.task_alt),
    };
    final fg = outlined ? scheme.onSecondaryContainer : statusFg;
    return Semantics(
      label: '${context.l10n.status}: ${status.localized(context.l10n)}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 24),
        // The 1 px border adds to the padding, so the outlined chip takes 1 less.
        padding: outlined ? const EdgeInsets.symmetric(horizontal: 7, vertical: 1) : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: outlined ? null : bg,
          border: outlined ? Border.all(color: fg) : null,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                status.localized(context.l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded square with the site's icon; a Hero so it flies into the detail.
class SiteThumb extends StatelessWidget {
  const SiteThumb({required this.inspection, this.size = 56, this.heroTag, super.key});

  final InspectionSummary inspection;
  final double size;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(AppRadii.medium)),
      child: Icon(siteIcon(inspection.icon), color: scheme.onSecondaryContainer, size: size * 0.45),
    );
    return heroTag == null ? box : Hero(tag: heroTag!, child: box);
  }
}

/// Grey placeholder rows while the list loads (P04 left).
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.rows = 7, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bar(double w, double h, Color c) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(h)),
    );
    const widths = [(0.72, 0.44), (0.58, 0.38), (0.8, 0.5), (0.64, 0.3), (0.7, 0.46), (0.52, 0.4), (0.76, 0.34)];
    return Semantics(
      label: context.l10n.loadingInspections,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, c) {
            final textWidth = c.maxWidth - 16 - 56 - 16 - 72 - 16 - 16;
            return Column(
              children: [
                for (var i = 0; i < rows; i++)
                  SizedBox(
                    height: 72,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppRadii.medium),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                bar(textWidth * widths[i % 7].$1, 14, scheme.surfaceContainerHighest),
                                const SizedBox(height: 8),
                                bar(textWidth * widths[i % 7].$2, 12, scheme.surfaceContainerHigh),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          bar(72, 24, scheme.surfaceContainerHigh),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Grey placeholder rows shaped like the desktop table (D03): ID, site, due
/// and status columns, so the page doesn't jump from list rows to a table
/// when the data arrives.
class SkeletonTable extends StatelessWidget {
  const SkeletonTable({this.rows = 10, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bar(double w, double h, Color c) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(h)),
    );
    const siteWidths = [0.62, 0.48, 0.7, 0.54, 0.66, 0.42, 0.58];
    return Semantics(
      label: context.l10n.loadingInspections,
      child: ExcludeSemantics(
        child: Column(
          children: [
            Container(height: 44, color: scheme.surfaceContainerLow),
            for (var i = 0; i < rows; i++)
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Align(alignment: AlignmentDirectional.centerStart, child: bar(64, 12, scheme.surfaceContainerHigh)),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: bar(c.maxWidth * siteWidths[i % siteWidths.length], 14, scheme.surfaceContainerHighest),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: Align(alignment: AlignmentDirectional.centerStart, child: bar(96, 12, scheme.surfaceContainerHigh)),
                    ),
                    SizedBox(
                      width: 140,
                      child: Align(alignment: AlignmentDirectional.centerStart, child: bar(88, 24, scheme.surfaceContainerHigh)),
                    ),
                    const SizedBox(width: 56),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Centered icon + title + text + action, for empty and error states (P04).
class MessageState extends StatelessWidget {
  const MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.detail,
    this.isError = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final String? detail;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 24, 40, 64),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: isError ? theme.colorScheme.error : muted),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[const SizedBox(height: 16), action!],
              if (detail != null) ...[const SizedBox(height: 8), Text(detail!, style: theme.textTheme.bodySmall?.copyWith(color: muted))],
            ],
          ),
        ),
      ),
    );
  }
}

/// "You're offline" strip (P02, P04) with a retry action.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.onRetry, required this.message, this.strong = false, super.key});

  final VoidCallback onRetry;
  final String message;

  /// Error-coloured variant used when nothing could be loaded.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = strong ? theme.colorScheme.errorContainer : theme.colorScheme.surfaceContainerHigh;
    final fg = strong ? theme.colorScheme.onErrorContainer : theme.colorScheme.onSurface;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.medium)),
        child: Row(
          children: [
            Icon(Symbols.cloud_off, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.offlineTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w500),
                  ),
                  Text(message, style: theme.textTheme.bodySmall?.copyWith(color: fg)),
                ],
              ),
            ),
            // The banner's text colour: the default (primary) fails contrast on errorContainer.
            TextButton(
              style: TextButton.styleFrom(foregroundColor: fg),
              onPressed: onRetry,
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
