import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/constrained_content.dart';
import '../../../core/widgets/demo_data_notice.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../auth/data/user_repository.dart';
import '../data/address_repository.dart';
import '../domain/address.dart';

/// Adds a new address, or edits one when [addressId] is given. Pops with the
/// saved address id.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.addressId});

  final String? addressId;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  static const _labelSuggestions = ['Home', 'Work', 'Other'];

  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController(text: 'Home');
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _postalCode = TextEditingController();
  final _country = TextEditingController();

  bool _makeDefault = false;
  bool _isSaving = false;

  bool get _isEditing => widget.addressId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final existing =
          ref.read(addressesProvider).value?.where((a) => a.id == widget.addressId).firstOrNull;
      if (existing != null) {
        final details = existing.address;
        _label.text = existing.label;
        _fullName.text = details.fullName;
        _phone.text = details.phone;
        _street.text = details.street;
        _city.text = details.city;
        _postalCode.text = details.postalCode;
        _country.text = details.country;
      }
      _makeDefault = ref.read(defaultAddressProvider)?.id == widget.addressId;
    } else {
      // Start from the profile so most users only type the location.
      final user = ref.read(currentUserProvider).value;
      _fullName.text = user?.displayName ?? '';
      _phone.text = user?.phone ?? '';
      // The first address becomes the default automatically.
      _makeDefault = ref.read(addressesProvider).value?.isEmpty ?? true;
    }
  }

  @override
  void dispose() {
    for (final controller in [_label, _fullName, _phone, _street, _city, _postalCode, _country]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final repository = ref.read(addressRepositoryProvider);
    final label = _label.text.trim();
    final address = ShippingAddress(
      fullName: _fullName.text.trim(),
      phone: _phone.text.trim(),
      street: _street.text.trim(),
      city: _city.text.trim(),
      postalCode: _postalCode.text.trim(),
      country: _country.text.trim(),
    );

    try {
      final String id;
      if (_isEditing) {
        id = widget.addressId!;
        await repository.update(id, label: label, address: address, makeDefault: _makeDefault);
      } else {
        id = await repository.add(label: label, address: address, makeDefault: _makeDefault);
      }
      if (mounted) context.pop(id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Could not save the address. Please try again.')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? value) => (value == null || value.trim().isEmpty) ? 'Required' : null;
    final isAlreadyDefault = _isEditing && ref.read(defaultAddressProvider)?.id == widget.addressId;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit address' : 'New address')),
      body: ConstrainedContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DemoDataNotice(),
                const SizedBox(height: 16),
                LabeledField(
                  label: 'Label',
                  child: TextFormField(
                    controller: _label,
                    decoration: const InputDecoration(hintText: 'e.g. Home, Work'),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    validator: required,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final suggestion in _labelSuggestions)
                      ChoiceChip(
                        label: Text(suggestion),
                        selected: _label.text.trim() == suggestion,
                        onSelected: (_) => setState(() => _label.text = suggestion),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: 'Recipient name',
                  child: TextFormField(
                    controller: _fullName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: required,
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: 'Phone number',
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: (value) {
                      final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                      return digits.length < 7 ? 'Enter a valid phone number' : null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: 'Street address',
                  child: TextFormField(
                    controller: _street,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.streetAddressLine1],
                    validator: required,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: LabeledField(
                        label: 'City',
                        child: TextFormField(
                          controller: _city,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.addressCity],
                          validator: required,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: LabeledField(
                        label: 'Postal code',
                        child: TextFormField(
                          controller: _postalCode,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.postalCode],
                          validator: required,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: 'Country',
                  child: TextFormField(
                    controller: _country,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.countryName],
                    validator: required,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Set as default address'),
                  subtitle: isAlreadyDefault ? const Text('Choose another address as default to change this.') : null,
                  value: _makeDefault,
                  // A default can only be replaced, not switched off, so there's always one.
                  onChanged: isAlreadyDefault ? null : (value) => setState(() => _makeDefault = value),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save address'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
