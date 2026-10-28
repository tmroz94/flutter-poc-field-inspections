import 'dart:async';

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
    builder: (context) => _TakeFocus(child: child),
  );
}

/// Opened from a link (cold start, `go`, the return after sign-in), the
/// sheet and the page under it are built together, and the page's route asked
/// for focus too, sometimes after the sheet. Tab and Esc then went to the page
/// behind the sheet. While the sheet is the top route it keeps the keyboard:
/// focus that lands behind it comes back.
class _TakeFocus extends StatefulWidget {
  const _TakeFocus({required this.child});

  final Widget child;

  @override
  State<_TakeFocus> createState() => _TakeFocusState();
}

class _TakeFocusState extends State<_TakeFocus> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFocusChange());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  // Focus changes are applied in a microtask; claim in the next one, after
  // the change that moved focus away.
  void _onFocusChange() => scheduleMicrotask(_claim);

  void _claim() {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final scope = FocusScope.of(context);
    if (!scope.hasFocus) scope.requestFocus();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
