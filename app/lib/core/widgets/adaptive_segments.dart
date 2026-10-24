import 'package:material_ui/material_ui.dart';

/// Single-choice segmented control that survives large text. M3 segments share
/// the width equally and cannot wrap, so above 130% text (or on narrow widths)
/// the same choices are shown as wrapping choice chips instead.
class AdaptiveSegments<T> extends StatelessWidget {
  const AdaptiveSegments({required this.segments, required this.selected, required this.onChanged, super.key});

  final List<(T value, String label)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

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
            selected: {selected},
            onSelectionChanged: (v) => onChanged(v.first),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final (v, l) in segments) ChoiceChip(label: Text(l), selected: v == selected, onSelected: (_) => onChanged(v))],
        );
      },
    );
  }
}
