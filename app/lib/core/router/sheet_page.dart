import 'package:material_ui/material_ui.dart';

/// A modal bottom sheet as a router page, so sheets like the filter (P05) and
/// result editor (P22) have their own URL: they can be deep-linked, survive a
/// web refresh, and close with browser back, system back or Esc.
class BottomSheetPage<T> extends Page<T> {
  const BottomSheetPage({required this.child, super.key, super.name, super.arguments, super.restorationId});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
    settings: this,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => child,
  );
}
