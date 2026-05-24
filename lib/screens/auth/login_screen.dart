import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/providers/auth_provider.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/utils/legal_urls.dart';

/// SCR-02 — Login / Sign-Up (tabbed).
/// Email+password, Google OAuth, Apple Sign-In.
/// Register tab captures GDPR Art. 6 consent with timestamp.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.appTitle),
          centerTitle: true,
          bottom: TabBar(
            tabs: [Tab(text: l.loginTabLogin), Tab(text: l.loginTabRegister)],
          ),
        ),
        body: const TabBarView(
          children: [LoginTab(), RegisterTab()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Login tab
// ---------------------------------------------------------------------------

class LoginTab extends ConsumerStatefulWidget {
  const LoginTab({super.key});

  @override
  ConsumerState<LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends ConsumerState<LoginTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authActionsProvider.notifier).signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
    _showErrorIfAny();
  }

  Future<void> _signInWithGoogle() async {
    final confirmed = await _showGoogleConsentSheet(context);
    if (!confirmed || !mounted) return;
    await ref.read(authActionsProvider.notifier).signInWithGoogle();
    _showErrorIfAny();
  }

  Future<void> _signInWithApple() async {
    await ref.read(authActionsProvider.notifier).signInWithApple();
    _showErrorIfAny();
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final emailController = TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.forgotPasswordDialogTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.forgotPasswordDialogBody),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(labelText: l.loginEmailLabel),
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.actionCancel),
          ),
          Consumer(
            builder: (_, ref, _) {
              final isLoading = ref.watch(authActionsProvider).isLoading;
              return FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        await ref
                            .read(authActionsProvider.notifier)
                            .resetPassword(emailController.text.trim());
                        if (!ctx.mounted) return;
                        final state = ref.read(authActionsProvider);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              state is AsyncError
                                  ? _friendlyError(state.error)
                                  : l.forgotPasswordSuccess,
                            ),
                            backgroundColor: state is AsyncError
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        );
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.forgotPasswordSend),
              );
            },
          ),
        ],
      ),
    );

    emailController.dispose();
  }

  void _showErrorIfAny() {
    final state = ref.read(authActionsProvider);
    if (state is AsyncError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(state.error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isLoading = ref.watch(authActionsProvider).isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(labelText: l.loginEmailLabel),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
              enabled: !isLoading,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: l.loginPasswordLabel,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _signIn(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your password' : null,
              enabled: !isLoading,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading ? null : () => _showForgotPasswordDialog(context),
                child: Text(l.loginForgotPassword),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: isLoading ? null : _signIn,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.actionSignIn),
            ),
            const SizedBox(height: 16),
            const _Divider(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: isLoading ? null : _signInWithGoogle,
              icon: const Icon(Icons.login),
              label: Text(l.loginContinueGoogle),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isLoading ? null : _signInWithApple,
                icon: const Icon(Icons.apple),
                label: Text(l.loginContinueApple),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Register tab
// ---------------------------------------------------------------------------

class RegisterTab extends ConsumerStatefulWidget {
  const RegisterTab({super.key});

  @override
  ConsumerState<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends ConsumerState<RegisterTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _gdprConsent = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_gdprConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorAcceptPrivacy),
        ),
      );
      return;
    }

    await ref.read(authActionsProvider.notifier).signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
          DateTime.now().toUtc(),
        );
    _showResultMessage();
  }

  void _showResultMessage() {
    if (!mounted) return;
    final state = ref.read(authActionsProvider);
    if (state is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(state.error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.loginEmailConfirmation),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isLoading = ref.watch(authActionsProvider).isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l.loginDisplayNameLabel),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
              enabled: !isLoading,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(labelText: l.loginEmailLabel),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
              enabled: !isLoading,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: l.loginPasswordLabel,
                helperText: 'Min 8 characters, 1 uppercase, 1 number',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _register(),
              validator: _validatePassword,
              enabled: !isLoading,
            ),
            const SizedBox(height: 20),
            // GDPR Art. 6 — consent checkbox with timestamp stored on submit
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _gdprConsent,
                  onChanged: isLoading
                      ? null
                      : (v) => setState(() => _gdprConsent = v ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _LegalConsentText(enabled: !isLoading),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isLoading ? null : _register,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.actionCreateAccount),
            ),
            const SizedBox(height: 16),
            const _Divider(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: isLoading ? null : _registerWithGoogle,
              icon: const Icon(Icons.login),
              label: Text(l.loginContinueGoogle),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isLoading ? null : _registerWithApple,
                icon: const Icon(Icons.apple),
                label: Text(l.loginContinueApple),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _registerWithGoogle() async {
    final confirmed = await _showGoogleConsentSheet(context);
    if (!confirmed || !mounted) return;
    await ref.read(authActionsProvider.notifier).signInWithGoogle();
    _showResultMessage();
  }

  Future<void> _registerWithApple() async {
    await ref.read(authActionsProvider.notifier).signInWithApple();
    _showResultMessage();
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

String? _validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Enter your email';
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email address';
  return null;
}

String? _validatePassword(String? v) {
  if (v == null || v.isEmpty) return 'Enter a password';
  if (v.length < 8) return 'Password must be at least 8 characters';
  if (!v.contains(RegExp(r'[A-Z]'))) {
    return 'Password must contain at least one uppercase letter';
  }
  if (!v.contains(RegExp(r'[0-9]'))) {
    return 'Password must contain at least one number';
  }
  return null;
}

// ── Google consent sheet ──────────────────────────────────────────────────────

/// Shows a bottom sheet disclosing what RATED receives from Google before
/// the OAuth flow starts. Returns true if the user confirms, false if cancelled.
Future<bool> _showGoogleConsentSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _GoogleConsentSheet(),
  );
  return result ?? false;
}

class _GoogleConsentSheet extends StatelessWidget {
  const _GoogleConsentSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.outline.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.login, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text('Signing in with Google',
                  style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'RATED will receive the following from your Google account:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text('• Your name\n• Your email address\n• Your profile photo',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'This data is used to create and identify your RATED profile. '
              'You can update your display name and photo at any time in Settings.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Continue with Google'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Legal consent text (register tab) ────────────────────────────────────────

class _LegalConsentText extends StatelessWidget {
  const _LegalConsentText({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkStyle = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.primary,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
    );
    final plainStyle = theme.textTheme.bodyMedium;

    return RichText(
      text: TextSpan(
        style: plainStyle,
        children: [
          const TextSpan(text: 'I agree to the '),
          TextSpan(
            text: 'Privacy Policy',
            style: enabled ? linkStyle : linkStyle?.copyWith(color: AppColors.outline),
            recognizer: enabled
                ? (TapGestureRecognizer()
                  ..onTap = () => LegalUrls.open(LegalUrls.privacyPolicy))
                : null,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Terms of Use',
            style: enabled ? linkStyle : linkStyle?.copyWith(color: AppColors.outline),
            recognizer: enabled
                ? (TapGestureRecognizer()
                  ..onTap = () => LegalUrls.open(LegalUrls.termsOfUse))
                : null,
          ),
        ],
      ),
    );
  }
}

/// Maps Supabase/auth errors to user-friendly messages.
String _friendlyError(Object error) {
  final msg = error.toString().toLowerCase();
  if (msg.contains('invalid login credentials') ||
      msg.contains('invalid_credentials')) {
    return 'Incorrect email or password.';
  }
  if (msg.contains('email already registered') ||
      msg.contains('user already registered') ||
      msg.contains('already been registered')) {
    return 'An account with this email already exists.';
  }
  if (msg.contains('email not confirmed')) {
    return 'Please confirm your email address before signing in.';
  }
  if (msg.contains('network') || msg.contains('socketexception')) {
    return 'No internet connection. Please try again.';
  }
  if (msg.contains('too many requests') || msg.contains('rate limit')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  if (msg.contains('invalid api key') || msg.contains('invalid_api_key') ||
      msg.contains('no api key') || msg.contains('supabaseurl')) {
    return 'App configuration error — contact support.';
  }
  // In debug mode show the raw error so issues are visible during development
  assert(() {
    debugPrint('[Auth error] $error');
    return true;
  }());
  return 'Something went wrong. Please try again.';
}
