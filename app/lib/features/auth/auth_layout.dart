import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app/app_info.dart';
import '../../core/layout/window_size.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_settings.dart';
import '../../l10n/l10n.dart';

/// Shared frame for sign-in, sign-up and reset (P01 on phones, D01 from 840):
/// a single column on phones, a card with a brand panel on wide screens.
class AuthLayout extends StatelessWidget {
  const AuthLayout({required this.title, required this.child, this.subtitle, super.key});

  final String title;

  /// Defaults to the app name.
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = context.windowSize.isTwoPane;

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!wide) ...[const _LogoTile(), const SizedBox(height: 16)],
        Semantics(header: true, child: Text(title, style: wide ? theme.textTheme.headlineSmall : theme.textTheme.headlineMedium)),
        if (!wide) ...[
          const SizedBox(height: 4),
          Text(subtitle ?? context.l10n.appName, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 32),
        child,
        const SizedBox(height: 24),
        const _Footer(),
      ],
    );

    if (!wide) {
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 48, 24, 24), child: form),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Card(
              elevation: 1,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.extraLarge)),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Expanded(child: _BrandPanel()),
                    Expanded(
                      child: Padding(padding: const EdgeInsets.all(48), child: form),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(AppRadii.large)),
        child: Icon(Symbols.fact_check, size: 32, color: scheme.onPrimaryContainer),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = theme.colorScheme.onPrimaryContainer;
    return ColoredBox(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Symbols.fact_check, size: 32, color: on),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(context.l10n.appName, style: theme.textTheme.titleLarge?.copyWith(color: on)),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.authTagline, style: theme.textTheme.headlineLarge?.copyWith(color: on)),
                const SizedBox(height: 12),
                Text(context.l10n.authTaglineSub, style: theme.textTheme.bodyLarge?.copyWith(color: on)),
              ],
            ),
            const SizedBox(height: 48),
            Text(context.l10n.pocBuild(AppInfo.version), style: theme.textTheme.bodySmall?.copyWith(color: on)),
          ],
        ),
      ),
    );
  }
}

/// Language switch (EN ⇄ PL) and build info.
class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPolish = Localizations.localeOf(context).languageCode == 'pl';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () => ref.read(themeSettingsProvider.notifier).update((s) => s.copyWith(locale: () => Locale(isPolish ? 'en' : 'pl'))),
          icon: const Icon(Symbols.language),
          label: Text(isPolish ? 'English' : 'Polski'),
        ),
        Text(context.l10n.pocBuild(AppInfo.version), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
