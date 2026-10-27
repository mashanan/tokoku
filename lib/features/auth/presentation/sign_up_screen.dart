import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/widgets/demo_data_notice.dart';
import '../../../core/widgets/labeled_field.dart';
import '../data/auth_repository.dart';
import 'auth_error_message.dart';
import 'auth_form_layout.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signUp(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // The router redirects to the catalog once the auth state changes.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final signInLocation = Uri(path: AppRoutes.signIn, queryParameters: from == null ? null : {'from': from});

    return AuthFormLayout(
      title: 'Create account',
      subtitle: 'Join to start buying and selling',
      children: [
        const DemoDataNotice(),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Full name',
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline)),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
                ),
              ),
              const SizedBox(height: 16),
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
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) =>
                      (value == null || value.length < 6) ? 'Password must be at least 6 characters' : null,
                ),
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Confirm password',
                child: TextFormField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline)),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signUp(),
                  validator: (value) => value != _passwordController.text ? 'Passwords do not match' : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isLoading ? null : _signUp,
          child: _isLoading
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create account'),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Already have an account?'),
            TextButton(onPressed: () => context.go(signInLocation.toString()), child: const Text('Sign in')),
          ],
        ),
      ],
    );
  }
}
