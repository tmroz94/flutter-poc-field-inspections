import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/platform/notification_service.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_settings.dart';
import 'data/sync/sync_service.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_models.dart';
import 'features/auth/auth_screens.dart';
import 'features/notifications/reminders.dart';
import 'l10n/l10n.dart';

class FieldInspectionsApp extends ConsumerWidget {
  const FieldInspectionsApp({super.key});

  /// en-GB: 24-hour time, day-month dates and Monday-first calendars, as on the boards.
  static const supportedLocales = [Locale('en', 'GB'), Locale('pl')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    final router = ref.watch(routerProvider);
    // Keep the outbox sync and the reminder schedule running for the app's lifetime.
    ref
      ..listen(syncServiceProvider, (_, _) {})
      ..listen(remindersProvider, (_, _) {});
    // Notification taps while the app runs open the notification's route.
    ref.listen(notificationTapsProvider, (_, next) {
      if (next.value case final route?) router.go(route);
    });
    final contrast = settings.contrast ?? AppContrast.standard;
    // While the stored session loads, the router isn't built at all: the
    // splash shows at the current URL, and the first route parse happens with
    // the session known (cold-start deep links keep their target, and the
    // browser history gets no intermediate entry).
    final restoring = ref.watch(authControllerProvider.select((s) => s.status == AuthStatus.restoring));

    ThemeData theme(Brightness b, AppContrast c) => buildTheme(colorSchemeFor(b, c), reduceMotion: settings.reduceMotion);

    return MaterialApp.router(
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
      // App strings (gen-l10n) plus material_ui's Material/Cupertino/widgets
      // localizations. Not AppLocalizations.localizationsDelegates: that list
      // uses the framework's older flutter_localizations classes.
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      onGenerateTitle: (context) => context.l10n.appName,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: settings.textScale == null ? media.textScaler : TextScaler.linear(settings.textScale!),
            disableAnimations: media.disableAnimations || settings.reduceMotion,
          ),
          child: restoring ? const SplashScreen() : child!,
        );
      },
    );
  }
}
