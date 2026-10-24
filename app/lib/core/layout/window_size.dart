import 'package:material_ui/material_ui.dart';

/// Material 3 window size classes, as used on the "Screen map" board:
/// compact < 600, medium 600–839, expanded 840–1199, large 1200+.
enum WindowSize {
  compact,
  medium,
  expanded,
  large;

  static WindowSize fromWidth(double width) => switch (width) {
    < 600 => compact,
    < 840 => medium,
    < 1200 => expanded,
    _ => large,
  };

  /// "Compact", "Medium", … as on the boards.
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';

  /// Two panes (list-detail) from 840 up.
  bool get isTwoPane => index >= expanded.index;

  /// Navigation rail instead of the bottom bar from 600 up.
  bool get usesRail => index >= medium.index;
}

extension WindowSizeContext on BuildContext {
  WindowSize get windowSize => WindowSize.fromWidth(MediaQuery.sizeOf(this).width);
}
