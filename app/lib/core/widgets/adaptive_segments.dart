import 'package:material_ui/material_ui.dart';

/// Single-choice segmented control that survives large text. M3 segments share
/// the width equally and cannot wrap, so above 130% text (or on narrow widths)
/// the same choices are shown as wrapping choice chips instead.
class AdaptiveSegments<T> extends StatelessWidget {
  const AdaptiveSegments({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.onCleared,
    this.showSelectedIcon = true,
    super.key,
  });

  final List<(T value, String label)> segments;

  /// With [onCleared], null means nothing is chosen yet.
  final T? selected;
  final ValueChanged<T> onChanged;

  /// Set when a choice can be taken back: tapping the chosen one again clears it.
  final VoidCallback? onCleared;
  final bool showSelectedIcon;

  bool get _none => onCleared != null && selected == null;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, c) {
        // Rough fit check: ~7 dp per character at 100% plus segment padding.
        final longest = segments.map((s) => s.$2.length).fold(0, (a, b) => a > b ? a : b);
        final fits = scale <= 1.3 && (longest * 7 * scale + 40) * segments.length <= c.maxWidth;
        if (fits) {
          return SegmentedButton<T>(
            segments: [for (final (v, l) in segments) ButtonSegment(value: v, label: Text(l))],
            selected: _none ? <T>{} : {selected as T},
            emptySelectionAllowed: onCleared != null,
            showSelectedIcon: showSelectedIcon,
            onSelectionChanged: (v) => v.isEmpty ? onCleared?.call() : onChanged(v.first),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (v, l) in segments)
              ChoiceChip(
                label: Text(l),
                selected: !_none && v == selected,
                onSelected: (on) => !on && onCleared != null ? onCleared!() : onChanged(v),
              ),
          ],
        );
      },
    );
  }
}
