import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/demo_accounts.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/labeled_field.dart';
import '../data/auth_repository.dart';
import 'auth_error_message.dart';
import 'auth_form_layout.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // The router redirects to the catalog once the auth state changes.
    } catch (error) {
      if (mounted) _showMessage(authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAsDemo(DemoAccount account) async {
    _emailController.text = account.email;
    _passwordController.text = account.password;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signIn(email: account.email, password: account.password);
    } catch (error) {
      if (mounted) _showMessage(authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Enter your email above, then tap "Forgot password?" again.');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (mounted) _showMessage('Password reset link sent to $email.');
    } catch (error) {
      if (mounted) _showMessage(authErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final signUpLocation = Uri(path: AppRoutes.signUp, queryParameters: from == null ? null : {'from': from});

    return AuthFormLayout(
      title: 'Welcome back',
      subtitle: 'Sign in to continue shopping',
      children: [
        Card(
          margin: EdgeInsets.zero,
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Just looking around?', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text('Try the app with a ready-made demo account.', style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                for (final account in demoAccounts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => _signInAsDemo(account),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account.label),
                          Text(account.description, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Email',
                child: TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) => (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
                ),
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Password',
                child: TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _signIn(),
                  validator: (value) => (value == null || value.isEmpty) ? 'Enter your password' : null,
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _resetPassword, child: const Text('Forgot password?')),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _isLoading ? null : _signIn,
          child: _isLoading
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Sign in'),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Don't have an account?"),
            TextButton(onPressed: () => context.go(signUpLocation.toString()), child: const Text('Sign up')),
          ],
        ),
        TextButton.icon(
          onPressed: () => context.go(AppRoutes.catalog),
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('Browse as guest'),
        ),
      ],
    );
  }
}
