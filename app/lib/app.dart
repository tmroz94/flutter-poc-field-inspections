import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_settings.dart';

class FieldInspectionsApp extends ConsumerWidget {
  const FieldInspectionsApp({super.key});

  static const supportedLocales = [Locale('en'), Locale('pl')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    final router = ref.watch(routerProvider);
    final contrast = settings.contrast ?? AppContrast.standard;

    ThemeData theme(Brightness b, AppContrast c) => buildTheme(colorSchemeFor(b, c), reduceMotion: settings.reduceMotion);

    return MaterialApp.router(
      title: 'Field Inspections',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: settings.mode,
      theme: theme(Brightness.light, contrast),
      darkTheme: theme(Brightness.dark, contrast),
      // Used when the OS asks for high contrast and the app setting follows the system.
      highContrastTheme: theme(Brightness.light, settings.contrast ?? AppContrast.high),
      highContrastDarkTheme: theme(Brightness.dark, settings.contrast ?? AppContrast.high),
      locale: settings.locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: settings.textScale == null ? media.textScaler : TextScaler.linear(settings.textScale!),
            disableAnimations: media.disableAnimations || settings.reduceMotion,
          ),
          child: child!,
        );
      },
    );
  }
}
