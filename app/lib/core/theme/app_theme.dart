import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

import 'color_schemes.dart';

enum AppContrast { standard, medium, high }

/// Corner radii from the canvas tokens (`--corner-*`).
abstract final class AppRadii {
  static const extraSmall = 4.0;
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const extraLarge = 28.0;
}

ColorScheme colorSchemeFor(Brightness brightness, AppContrast contrast) => switch ((brightness, contrast)) {
  (Brightness.light, AppContrast.standard) => AppColorSchemes.light,
  (Brightness.light, AppContrast.medium) => AppColorSchemes.lightMediumContrast,
  (Brightness.light, AppContrast.high) => AppColorSchemes.lightHighContrast,
  (Brightness.dark, AppContrast.standard) => AppColorSchemes.dark,
  (Brightness.dark, AppContrast.medium) => AppColorSchemes.darkMediumContrast,
  (Brightness.dark, AppContrast.high) => AppColorSchemes.darkHighContrast,
};

const _platformTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
  },
);

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Reduced motion (app setting or OS setting): pages switch without movement.
final _reducedMotionTransitions = PageTransitionsTheme(builders: {for (final p in TargetPlatform.values) p: const _NoTransitionsBuilder()});

/// Builds the app theme from a canvas color scheme. Typography is the M3 type
/// scale on the platform font (Roboto on Android and web, SF on iOS), which
/// follows each platform's guidelines. See docs/decisions.md.
ThemeData buildTheme(ColorScheme scheme, {bool reduceMotion = false}) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    pageTransitionsTheme: reduceMotion ? _reducedMotionTransitions : _platformTransitions,
    // Keep 48dp touch targets on desktop and web too (the default is compact there).
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.small))),
    cardTheme: base.cardTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.medium))),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(border: const OutlineInputBorder()),
    snackBarTheme: base.snackBarTheme.copyWith(behavior: SnackBarBehavior.floating),
  );
}
