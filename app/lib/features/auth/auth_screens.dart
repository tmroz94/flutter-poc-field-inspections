import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mock_data/mock_data.dart' show demoEmail, demoPassword;

import '../../core/platform/capabilities.dart';
import '../../core/platform/platform_services.dart';
import '../../core/router/deep_links.dart';
import '../../core/router/routes.dart';
import '../../core/validation/form_support.dart';
import '../../core/validation/validators.dart';
import '../../data/api/api_exception.dart';
import '../../data/api/backend_config.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import 'auth_controller.dart';
import 'auth_layout.dart';
import 'lock_controller.dart';

/// Shown while the stored session is being checked.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: CircularProgressIndicator(semanticsLabel: context.l10n.loading)),
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

/// Form-level message for a failed auth call; anything that isn't an
/// [ApiException] (an unreadable answer) gets the generic one.
String _errorMessage(AppLocalizations l, Object error) => switch (error) {
  ApiException(code: 'invalidCredentials') => l.authErrorCredentials,
  ApiException(code: 'network') => l.authErrorNetwork,
  ApiException(code: 'validation') => l.authErrorValidation,
  _ => l.authErrorUnknown,
};

/// Password field with show/hide toggle and a Caps Lock hint (D01). The hint
/// matters on keyboards (web, desktop, tablets); phones rarely report it.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.focusNode,
    required this.validator,
    this.label,
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

  /// Defaults to "Password".
  final String? label;
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
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(PasswordField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  /// The Caps Lock hint shows only while this field has focus.
  void _onFocus() {
    if (mounted) setState(() {});
  }

  bool _onKey(KeyEvent event) {
    final caps = HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);
    if (caps != _capsLock && mounted) setState(() => _capsLock = caps);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
        labelText: widget.label ?? l.password,
        prefixIcon: const Icon(Symbols.lock),
        helperText: showCaps ? l.capsLockOn : widget.helper,
        helperStyle: showCaps ? TextStyle(color: Theme.of(context).colorScheme.tertiary) : null,
        errorText: widget.errorText,
        suffixIcon: IconButton(
          tooltip: _obscure ? l.showPassword : l.hidePassword,
          icon: Icon(_obscure ? Symbols.visibility : Symbols.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// [path] with this screen's `from`, so where sign-in was going survives
/// moving between sign-in, sign-up and password reset.
String _keepFrom(BuildContext context, String path) {
  final from = GoRouterState.of(context).uri.queryParameters['from'];
  return from == null ? path : Uri(path: path, queryParameters: {'from': from}).toString();
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
    if (_busy) return;
    final t = ValidationText.of(context);
    final l = context.l10n;
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
      // Lets the platform password manager offer to save the credentials
      // (not after the demo account: the typed ones weren't used).
      TextInput.finishAutofillContext(shouldSave: email == null);
      if (mounted) continueToTarget(context);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(l, e);
        _serverFields = e is ApiException ? e.fields : const {};
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
    final l = context.l10n;
    return AuthLayout(
      title: l.signIn,
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
                  labelText: l.email,
                  prefixIcon: const Icon(Symbols.mail),
                  errorText: _serverFields['email'] == null ? null : t.server(_serverFields['email']!),
                ),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                focusNode: _passwordFocus,
                validator: _passwordValidator(t),
                helper: l.passwordHelperSignIn,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                errorText: _serverFields['password'] == null ? null : t.server(_serverFields['password']!),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CheckRow(label: l.keepSignedIn, value: _remember, onChanged: (v) => setState(() => _remember = v)),
                  TextButton(onPressed: () => context.go(_keepFrom(context, Routes.forgotPassword)), child: Text(l.forgotPassword)),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 16)],
              BusyButton(label: l.signIn, busy: _busy, onPressed: _submit),
              const SizedBox(height: 12),
              BusyButton(
                label: l.useDemoAccount,
                outlined: true,
                busy: false,
                onPressed: _busy ? null : () => _submit(email: demoEmail, password: demoPassword),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => context.go(_keepFrom(context, Routes.signUp)), child: Text(l.createAnAccount)),
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
    // The config, not the repository's runtimeType: class names are minified in web release builds.
    final fake = ref.watch(backendConfigProvider).mode == BackendMode.fake;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        fake ? context.l10n.backendOfflineDemo : context.l10n.backendMockServer,
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
  void initState() {
    super.initState();
    _focus[1].addListener(_onEmailFocus);
  }

  void _onEmailFocus() {
    if (!_focus[1].hasFocus) unawaited(_checkEmail());
  }

  @override
  void dispose() {
    _focus[1].removeListener(_onEmailFocus);
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

  /// Async uniqueness check when the email field loses focus. The answer is
  /// dropped if the email was edited meanwhile.
  Future<void> _checkEmail() async {
    final t = ValidationText.of(context);
    final email = _email.text;
    if (_emailV(t)(email) != null) return;
    try {
      final free = await ref.read(authRepositoryProvider).isEmailAvailable(email);
      if (mounted && _email.text == email) setState(() => _emailTaken = free ? null : t.emailTaken);
    } on ApiException {
      // Offline: the server re-checks on submit.
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final t = ValidationText.of(context);
    final l = context.l10n;
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
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(l, e);
        if (e is ApiException && e.fields['email'] == 'taken') _emailTaken = t.emailTaken;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ValidationText.of(context);
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final strengthLabels = [l.strengthTooWeak, l.strengthWeak, l.strengthFair, l.strengthGood, l.strengthStrong];
    final strengthColors = [scheme.error, scheme.error, scheme.tertiary, scheme.primary, scheme.primary];
    return AuthLayout(
      title: l.createAccountTitle,
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
                decoration: InputDecoration(labelText: l.fullName, prefixIcon: const Icon(Symbols.person)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                focusNode: _focus[1],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                autovalidateMode: AutovalidateMode.onUnfocus,
                validator: _emailV(t),
                onChanged: (_) => _emailTaken == null ? null : setState(() => _emailTaken = null),
                decoration: InputDecoration(labelText: l.email, prefixIcon: const Icon(Symbols.mail), errorText: _emailTaken),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                focusNode: _focus[2],
                validator: _passwordV(t),
                helper: l.passwordHelperSignUp,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onChanged: (v) => setState(() {
                  final strength = Validators.passwordStrength(v);
                  _strength = _passwordV(t)(v) == null ? strength : strength.clamp(0, 1);
                }),
              ),
              if (_password.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Semantics(
                  label: l.passwordStrength(strengthLabels[_strength]),
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
                label: l.confirmPassword,
                validator: _confirmV(t),
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              _CheckRow(
                label: l.acceptTerms,
                value: _terms,
                onChanged: (v) => setState(() {
                  _terms = v;
                  _termsError = false;
                }),
              ),
              if (_termsError)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16),
                  // Announced: with every field valid, focus has nowhere to go.
                  child: Semantics(
                    liveRegion: true,
                    child: Text(t.mustAccept, style: TextStyle(color: scheme.error)),
                  ),
                ),
              const SizedBox(height: 16),
              if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 16)],
              BusyButton(label: l.createAccountTitle, busy: _busy, onPressed: _submit),
              const SizedBox(height: 8),
              TextButton(onPressed: () => context.go(_keepFrom(context, Routes.signIn)), child: Text(l.haveAccount)),
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
    if (_busy) return;
    final t = ValidationText.of(context);
    final l = context.l10n;
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
    } on Object catch (e) {
      if (mounted) setState(() => _error = _errorMessage(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ValidationText.of(context);
    final l = context.l10n;
    final theme = Theme.of(context);
    return AuthLayout(
      title: l.resetPasswordTitle,
      child: _sent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  liveRegion: true,
                  // The same message whether or not the account exists.
                  child: Text(l.resetSent(_email.text.trim()), style: theme.textTheme.bodyLarge),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => context.go(_keepFrom(context, Routes.signIn)), child: Text(l.backToSignIn)),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.resetIntro, style: theme.textTheme.bodyMedium),
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
                    decoration: InputDecoration(labelText: l.email, prefixIcon: const Icon(Symbols.mail)),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 16)],
                  BusyButton(label: l.sendResetLink, busy: _busy, onPressed: _submit),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => context.go(_keepFrom(context, Routes.signIn)), child: Text(l.backToSignIn)),
                ],
              ),
            ),
    );
  }
}

/// P26: shown on a cold start with biometric unlock on, or after the app was
/// in the background too long. Prompts for biometrics on open; the device PIN
/// is the fallback.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await ref.read(biometricServiceProvider).authenticate(reason: context.l10n.biometricReason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.read(hapticsProvider).success();
      ref.read(lockControllerProvider.notifier).unlock();
      continueToTarget(context);
    } else {
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final user = ref.watch(authControllerProvider).user;
    final timedOut = ref.watch(lockControllerProvider.select((s) => s.timedOut));
    // Name what this device uses: Face ID / Touch ID on Apple devices.
    final kind = ref.watch(biometricKindProvider).value ?? BiometricKind.other;
    final platform = ref.watch(capabilitiesProvider).platform;
    final apple = platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final prompt = switch (kind) {
      BiometricKind.face => apple ? l.unlockPromptFaceId : l.unlockPromptFace,
      BiometricKind.fingerprint => apple ? l.unlockPromptTouchId : l.unlockPromptFingerprint,
      BiometricKind.other => l.unlockPrompt,
    };
    // Scrolls when the window is too short (landscape phone, large text):
    // "Use password instead" is the way out when biometrics fail.
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
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
                      Text(l.unlockWelcome(user?.firstName ?? ''), style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(timedOut ? l.unlockTimedOut : l.unlockOnStart, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      FloatingActionButton.large(
                        tooltip: l.unlockButton,
                        onPressed: _busy ? null : _unlock,
                        child: Icon(kind == BiometricKind.face ? Symbols.face : Symbols.fingerprint),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _failed ? l.unlockFailed : prompt,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _failed ? theme.colorScheme.error : null),
                        ),
                      ),
                      const Spacer(),
                      // The same user signs in again, so the device's drafts and outbox stay.
                      TextButton(onPressed: () => ref.read(authControllerProvider.notifier).signOut(), child: Text(l.usePasswordInstead)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
