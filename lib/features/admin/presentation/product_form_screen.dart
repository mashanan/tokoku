import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/images/image_repository.dart';
import '../../../core/widgets/constrained_content.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product_input.dart';
import '../../products/presentation/widgets/product_image.dart';
import 'admin_guard.dart';

/// Adds a product, or edits one when [productId] is given.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  static const _maxImages = 5;

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _brand = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _stock = TextEditingController();

  String? _category;
  List<String> _images = [];
  bool _isUploading = false;
  bool _isSaving = false;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (!_isEditing) return;
    final product = ref.read(productsProvider).value?.where((p) => p.id == widget.productId).firstOrNull;
    if (product == null) return;

    _title.text = product.title;
    _brand.text = product.brand ?? '';
    _description.text = product.description;
    _price.text = product.price.toStringAsFixed(2);
    _discount.text = product.discountPercentage.toStringAsFixed(product.discountPercentage % 1 == 0 ? 0 : 2);
    _stock.text = '${product.stock}';
    _category = product.category;
    _images = product.images.isEmpty && product.thumbnail.isNotEmpty ? [product.thumbnail] : [...product.images];
  }

  @override
  void dispose() {
    for (final controller in [_title, _brand, _description, _price, _discount, _stock]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static double? _parseNumber(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _addPhoto() async {
    // Resizing and compressing here keeps each photo far below Firestore's 1 MiB limit.
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 70,
    );
    if (file == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await file.readAsBytes();
      final reference = await ref.read(imageRepositoryProvider).upload(bytes, contentType: file.mimeType ?? 'image/jpeg');
      if (mounted) setState(() => _images = [..._images, reference]);
    } on ImageTooLargeException catch (error) {
      if (mounted) _showMessage(error.toString());
    } catch (_) {
      if (mounted) _showMessage('Could not upload the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      _showMessage('Add at least one photo.');
      return;
    }

    final brand = _brand.text.trim();
    final input = ProductInput(
      title: _title.text.trim(),
      description: _description.text.trim(),
      category: _category!,
      brand: brand.isEmpty ? null : brand,
      price: _parseNumber(_price.text)!,
      discountPercentage: _parseNumber(_discount.text) ?? 0,
      stock: int.parse(_stock.text.trim()),
      images: _images,
    );

    setState(() => _isSaving = true);
    final repository = ref.read(productRepositoryProvider);
    try {
      if (_isEditing) {
        await repository.updateProduct(widget.productId!, input);
      } else {
        await repository.createProduct(input);
      }
      if (!mounted) return;
      _showMessage(_isEditing ? 'Product updated.' : 'Product added.');
      context.pop();
    } catch (_) {
      if (mounted) {
        _showMessage('Could not save the product. Please try again.');
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    String? required(String? value) => (value == null || value.trim().isEmpty) ? 'Required' : null;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit product' : 'New product')),
      body: AdminGuard(
        child: ConstrainedContent(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Photos', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('The first photo is the cover.', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  _PhotoStrip(
                    images: _images,
                    canAdd: _images.length < _maxImages,
                    isUploading: _isUploading,
                    onAdd: _isSaving ? null : _addPhoto,
                    onRemove: (index) => setState(() => _images = [..._images]..removeAt(index)),
                    onMakeCover: (index) => setState(() {
                      final image = _images[index];
                      _images = [image, ..._images.where((i) => i != image)];
                    }),
                  ),
                  const SizedBox(height: 24),
                  LabeledField(
                    label: 'Product name',
                    child: TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: required,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Brand (optional)',
                    child: TextFormField(
                      controller: _brand,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Category',
                    child: DropdownButtonFormField<String>(
                      initialValue: categories.any((c) => c.slug == _category) ? _category : null,
                      hint: const Text('Choose a category'),
                      items: [
                        for (final category in categories)
                          DropdownMenuItem(value: category.slug, child: Text(category.name)),
                      ],
                      onChanged: (value) => setState(() => _category = value),
                      validator: (value) => value == null ? 'Choose a category' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Description',
                    child: TextFormField(
                      controller: _description,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 3,
                      maxLines: 8,
                      validator: required,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'Price',
                          child: TextFormField(
                            controller: _price,
                            decoration: const InputDecoration(prefixText: '\$ '),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              final price = _parseNumber(value ?? '');
                              return price == null || price <= 0 ? 'Enter a price' : null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: 'Discount',
                          child: TextFormField(
                            controller: _discount,
                            decoration: const InputDecoration(suffixText: '%'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              final discount = _parseNumber(value ?? '0') ?? -1;
                              return discount < 0 || discount > 90 ? '0–90' : null;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Stock',
                    child: TextFormField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.done,
                      validator: (value) => int.tryParse(value?.trim() ?? '') == null ? 'Enter the stock' : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSaving || _isUploading ? null : _save,
                    child: _isSaving
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEditing ? 'Save changes' : 'Add product'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.images,
    required this.canAdd,
    required this.isUploading,
    required this.onAdd,
    required this.onRemove,
    required this.onMakeCover,
  });

  static const _size = 96.0;

  final List<String> images;
  final bool canAdd;
  final bool isUploading;
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onMakeCover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: _size,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (index, image) in images.indexed)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: index == 0 ? null : () => onMakeCover(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: _size,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ProductImage(url: image),
                        if (index == 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: ColoredBox(
                              color: Colors.black54,
                              child: Text(
                                'Cover',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: IconButton.filledTonal(
                            tooltip: 'Remove photo',
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            icon: const Icon(Icons.close),
                            onPressed: () => onRemove(index),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (canAdd)
            SizedBox.square(
              dimension: _size,
              child: OutlinedButton(
                onPressed: isUploading ? null : onAdd,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isUploading
                    ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [Icon(Icons.add_a_photo_outlined), SizedBox(height: 4), Text('Add')],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
