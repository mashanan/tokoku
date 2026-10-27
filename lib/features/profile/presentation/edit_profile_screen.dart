import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/constrained_content.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/user_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    _name.text = user?.displayName ?? '';
    _phone.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    try {
      await ref.read(userRepositoryProvider).updateProfile(uid, displayName: name, phone: _phone.text.trim());
      await ref.read(authRepositoryProvider).updateDisplayName(name);
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated.'), duration: Duration(seconds: 2)));
      if (mounted) context.pop();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not update your profile. Please try again.')));
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserProvider).value?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ConstrainedContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledField(
                  label: 'Full name',
                  child: TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline)),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: 'Phone number (optional)',
                  child: TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined)),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: (value) {
                      final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                      return digits.isNotEmpty && digits.length < 7 ? 'Enter a valid phone number' : null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: 'Email',
                  child: TextFormField(
                    initialValue: email,
                    enabled: false,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined),
                      helperText: 'Email can’t be changed here.',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
