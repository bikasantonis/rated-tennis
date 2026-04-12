import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/providers/auth_provider.dart';

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
    await ref.read(authActionsProvider.notifier).signInWithGoogle();
    _showErrorIfAny();
  }

  Future<void> _signInWithApple() async {
    await ref.read(authActionsProvider.notifier).signInWithApple();
    _showErrorIfAny();
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
            const SizedBox(height: 24),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: _gdprConsent,
                  onChanged: isLoading
                      ? null
                      : (v) => setState(() => _gdprConsent = v ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: isLoading
                        ? null
                        : () => setState(() => _gdprConsent = !_gdprConsent),
                    child: Text(
                      l.loginPrivacyConsent,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
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
