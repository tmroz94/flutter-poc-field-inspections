import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mock_data/mock_data.dart' show demoEmail, demoPassword;

import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_view.dart';
import 'auth_controller.dart';
import 'lock_controller.dart';

/// Shown while the stored session is being checked.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')),
  );
}

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Stack(
      children: [
        const PlaceholderView(
          title: 'Sign in',
          boards: ['P01', 'D01'],
          showAppBar: false,
          links: {'Create account': Routes.signUp, 'Forgot password?': Routes.forgotPassword},
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: FilledButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signIn(demoEmail, demoPassword),
            child: const Text('Use demo account'),
          ),
        ),
      ],
    ),
  );
}

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderView(title: 'Create account', links: {'Sign in': Routes.signIn});
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderView(title: 'Reset password', links: {'Sign in': Routes.signIn});
}

class UnlockScreen extends ConsumerWidget {
  const UnlockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Unlock (P26)'),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => ref.read(lockControllerProvider.notifier).unlock(), child: const Text('Unlock')),
        ],
      ),
    ),
  );
}
