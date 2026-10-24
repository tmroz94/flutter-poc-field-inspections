import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mock_data/mock_data.dart' show demoEmail, demoPassword;

import '../../core/router/deep_links.dart';
import '../../core/router/routes.dart';
import '../../core/validation/form_support.dart';
import '../../core/validation/validators.dart';
import '../../data/api/api_exception.dart';
import '../../data/providers.dart';
import 'auth_controller.dart';
import 'auth_layout.dart';
import 'lock_controller.dart';

/// Shown while the stored session is being checked.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')),
  );
}

/// After sign-in, sign-up or unlock: go to the original target *replacing*
/// the sign-in/unlock history entry, so browser back doesn't land on a page
/// that immediately redirects forward again (a back-button trap).
void continueToTarget(BuildContext context) {
  if (!context.mounted) return;
  final target = DeepLinks.sanitizeFrom(GoRouterState.of(context).uri.queryParameters['from']) ?? Routes.home;
  Router.neglect(context, () => context.go(target));
}

String _apiMessage(ApiException e) => switch (e.code) {
  'invalidCredentials' => 'Email or password is incorrect.',
  'network' => "Can't reach the server. Check your connection and try again.",
  'validation' => 'Check the highlighted fields.',
  _ => 'Something went wrong. Try again.',
};

/// Password field with show/hide toggle and a Caps Lock hint (D01). The hint
/// matters on keyboards (web, desktop, tablets); phones rarely report it.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.focusNode,
    required this.validator,
    this.label = 'Password',
    this.helper,
    this.autofillHints = const [AutofillHints.password],
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.onChanged,
    this.errorText,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final StringValidator validator;
  final String label;
  final String? helper;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? errorText;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;
  bool _capsLock = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    final caps = HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);
    if (caps != _capsLock && mounted) setState(() => _capsLock = caps);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final showCaps = _capsLock && widget.focusNode.hasFocus;
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscure,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      autovalidateMode: AutovalidateMode.onUnfocus,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Symbols.lock),
        helperText: showCaps ? 'Caps Lock is on' : widget.helper,
        helperStyle: showCaps ? TextStyle(color: Theme.of(context).colorScheme.tertiary) : null,
        errorText: widget.errorText,
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(_obscure ? Symbols.visibility : Symbols.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _remember = true;
  bool _busy = false;
  String? _error;
  Map<String, String> _serverFields = const {};

  @override
  void dispose() {
    for (final d in [_email, _password]) {
      d.dispose();
    }
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit({String? email, String? password}) async {
    final t = ValidationText.of(context);
    setState(() {
      _error = null;
      _serverFields = const {};
    });
    if (email == null && !_formKey.currentState!.validate()) {
      focusFirstInvalid(context, [
        FieldCheck(_emailFocus, () => _emailValidator(t)(_email.text)),
        FieldCheck(_passwordFocus, () => _passwordValidator(t)(_password.text)),
      ]);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).signIn(email ?? _email.text, password ?? _password.text, remember: _remember);
      // Lets the platform password manager offer to save the credentials.
      TextInput.finishAutofillContext();
      if (mounted) continueToTarget(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _apiMessage(e);
        _serverFields = e.fields;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  StringValidator _emailValidator(ValidationText t) => Validators.all([Validators.required(t), Validators.email(t)]);
  StringValidator _passwordValidator(ValidationText t) => Validators.all([Validators.required(t), Validators.minLength(t, 8)]);

  @override
  Widget build(BuildContext context) {
    final t = ValidationText.of(context);
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    return AuthLayout(
      title: 'Sign in',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                autocorrect: false,
                autovalidateMode: AutovalidateMode.onUnfocus,
                validator: _emailValidator(t),
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Symbols.mail),
                  errorText: _serverFields['email'] == null ? null : t.server(_serverFields['email']!),
                ),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                focusNode: _passwordFocus,
                validator: _passwordValidator(t),
                helper: 'Use 8 or more characters',
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                errorText: _serverFields['password'] == null ? null : t.server(_serverFields['password']!),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CheckRow(label: 'Keep me signed in', value: _remember, onChanged: (v) => setState(() => _remember = v)),
                  TextButton(onPressed: () => context.go(Routes.forgotPassword), child: const Text('Forgot password?')),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 16)],
              BusyButton(label: 'Sign in', busy: _busy, onPressed: _submit),
              const SizedBox(height: 12),
              BusyButton(
                label: 'Use demo account',
                outlined: true,
                busy: false,
                onPressed: _busy ? null : () => _submit(email: demoEmail, password: demoPassword),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    context.go(from == null ? Routes.signUp : Uri(path: Routes.signUp, queryParameters: {'from': from}).toString()),
                child: const Text('Create an account'),
              ),
              const _BackendNote(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tells the tester which backend answered: the mock server or the in-app fake.
class _BackendNote extends ConsumerWidget {
  const _BackendNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fake = ref.watch(authRepositoryProvider).runtimeType.toString().startsWith('Fake');
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        fake ? 'Offline demo data (mock server not reachable)' : 'Connected to the mock server',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            Flexible(child: Text(label)),
          ],
        ),
      ),
    ),
  );
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _focus = List.generate(4, (_) => FocusNode());
  bool _terms = false;
  bool _termsError = false;
  bool _busy = false;
  String? _error;
  String? _emailTaken;
  int _strength = 0;
  AutovalidateMode _mode = AutovalidateMode.disabled;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  StringValidator _nameV(ValidationText t) => Validators.all([Validators.required(t), Validators.maxLength(t, 80)]);
  StringValidator _emailV(ValidationText t) => Validators.all([Validators.required(t), Validators.email(t)]);
  StringValidator _passwordV(ValidationText t) => Validators.all([Validators.required(t), Validators.password(t)]);
  StringValidator _confirmV(ValidationText t) => Validators.all([Validators.required(t), Validators.matches(t, () => _password.text)]);

  /// Async uniqueness check when the email field loses focus.
  Future<void> _checkEmail() async {
    final t = ValidationText.of(context);
    if (_emailV(t)(_email.text) != null) return;
    try {
      final free = await ref.read(authRepositoryProvider).isEmailAvailable(_email.text);
      if (mounted) setState(() => _emailTaken = free ? null : t.emailTaken);
    } on ApiException {
      // Offline: the server re-checks on submit.
    }
  }

  Future<void> _submit() async {
    final t = ValidationText.of(context);
    setState(() {
      _mode = AutovalidateMode.onUserInteraction;
      _error = null;
      _termsError = !_terms;
    });
    final valid = _formKey.currentState!.validate() && _terms && _emailTaken == null;
    if (!valid) {
      focusFirstInvalid(context, [
        FieldCheck(_focus[0], () => _nameV(t)(_name.text)),
        FieldCheck(_focus[1], () => _emailTaken ?? _emailV(t)(_email.text)),
        FieldCheck(_focus[2], () => _passwordV(t)(_password.text)),
        FieldCheck(_focus[3], () => _confirmV(t)(_confirm.text)),
      ]);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).signUp(name: _name.text, email: _email.text, password: _password.text);
      TextInput.finishAutofillContext();
      if (mounted) continueToTarget(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _apiMessage(e);
        if (e.fields['email'] == 'taken') _emailTaken = t.emailTaken;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ValidationText.of(context);
    final scheme = Theme.of(context).colorScheme;
    const strengthLabels = ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'];
    final strengthColors = [scheme.error, scheme.error, scheme.tertiary, scheme.primary, scheme.primary];
    return AuthLayout(
      title: 'Create account',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _mode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                focusNode: _focus[0],
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                autovalidateMode: AutovalidateMode.onUnfocus,
                validator: _nameV(t),
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Symbols.person)),
              ),
              const SizedBox(height: 16),
              Focus(
                onFocusChange: (has) => has ? null : unawaited(_checkEmail()),
                child: TextFormField(
                  controller: _email,
                  focusNode: _focus[1],
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  validator: _emailV(t),
                  onChanged: (_) => _emailTaken == null ? null : setState(() => _emailTaken = null),
                  decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Symbols.mail), errorText: _emailTaken),
                ),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                focusNode: _focus[2],
                validator: _passwordV(t),
                helper: '8+ characters with a letter and a digit',
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onChanged: (v) => setState(() => _strength = Validators.passwordStrength(v)),
              ),
              if (_password.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Semantics(
                  label: 'Password strength: ${strengthLabels[_strength]}',
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (_strength + 1) / 5,
                            color: strengthColors[_strength],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(strengthLabels[_strength], style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                focusNode: _focus[3],
                label: 'Confirm password',
                validator: _confirmV(t),
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              _CheckRow(
                label: 'I accept the terms of use',
                value: _terms,
                onChanged: (v) => setState(() {
                  _terms = v;
                  _termsError = false;
                }),
              ),
              if (_termsError)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16),
                  child: Text(t.mustAccept, style: TextStyle(color: scheme.error)),
                ),
              const SizedBox(height: 16),
              if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 16)],
              BusyButton(label: 'Create account', busy: _busy, onPressed: _submit),
              const SizedBox(height: 8),
              TextButton(onPressed: () => context.go(Routes.signIn), child: const Text('I already have an account')),
            ],
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _focus.dispose();
    super.dispose();
  }

  StringValidator _v(ValidationText t) => Validators.all([Validators.required(t), Validators.email(t)]);

  Future<void> _submit() async {
    final t = ValidationText.of(context);
    if (!_formKey.currentState!.validate()) {
      focusFirstInvalid(context, [FieldCheck(_focus, () => _v(t)(_email.text))]);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _apiMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ValidationText.of(context);
    final theme = Theme.of(context);
    return AuthLayout(
      title: 'Reset password',
      child: _sent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  liveRegion: true,
                  // The same message whether or not the account exists.
                  child: Text(
                    'If an account exists for ${_email.text.trim()}, we sent a link to reset the password. Check your inbox.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => context.go(Routes.signIn), child: const Text('Back to sign in')),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Enter your account's email and we'll send a reset link.", style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    focusNode: _focus,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.send,
                    autovalidateMode: AutovalidateMode.onUnfocus,
                    validator: _v(t),
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Symbols.mail)),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 16)],
                  BusyButton(label: 'Send reset link', busy: _busy, onPressed: _submit),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => context.go(Routes.signIn), child: const Text('Back to sign in')),
                ],
              ),
            ),
    );
  }
}

/// P26: shown when the app was in the background too long with biometric lock on.
class UnlockScreen extends ConsumerWidget {
  const UnlockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(user?.initials ?? '', style: theme.textTheme.titleLarge),
                ),
                const SizedBox(height: 16),
                Text('Welcome back, ${user?.firstName ?? ''}', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('The app locked after 5 minutes in the background.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const Spacer(),
                FloatingActionButton.large(
                  tooltip: 'Unlock with biometrics',
                  // M3 calls local_auth here; until then it unlocks directly.
                  onPressed: () {
                    ref.read(lockControllerProvider.notifier).unlock();
                    continueToTarget(context);
                  },
                  child: const Icon(Symbols.fingerprint),
                ),
                const SizedBox(height: 16),
                const Text('Use your fingerprint or face to unlock'),
                const Spacer(),
                TextButton(onPressed: () => ref.read(authControllerProvider.notifier).signOut(), child: const Text('Use password instead')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
