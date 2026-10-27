import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/labeled_field.dart';
import '../data/review_repository.dart';

/// Opens a bottom sheet to rate and review a product from a delivered order.
/// Returns true once the review is saved.
Future<bool> showWriteReviewSheet(
  BuildContext context, {
  required String productId,
  required String productTitle,
  required String orderId,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _WriteReviewSheet(productId: productId, productTitle: productTitle, orderId: orderId),
  );
  return saved ?? false;
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  const _WriteReviewSheet({required this.productId, required this.productTitle, required this.orderId});

  final String productId;
  final String productTitle;
  final String orderId;

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  static const _ratingLabels = ['Poor', 'Fair', 'Good', 'Very good', 'Excellent'];
  static const _maxCommentLength = 1000;

  final _comment = TextEditingController();
  int _rating = 0;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(reviewRepositoryProvider).submit(
            productId: widget.productId,
            orderId: widget.orderId,
            rating: _rating,
            comment: _comment.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } on AlreadyReviewedException catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not post your review. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      // Keeps the form above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Rate this product', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(widget.productTitle, style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      tooltip: '$star ${star == 1 ? 'star' : 'stars'}',
                      iconSize: 40,
                      icon: Icon(
                        star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                      ),
                      onPressed: _isSaving ? null : () => setState(() => _rating = star),
                    ),
                ],
              ),
              Text(
                _rating == 0 ? 'Tap a star to rate' : _ratingLabels[_rating - 1],
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Your review (optional)',
                child: TextField(
                  controller: _comment,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(hintText: 'What did you like or dislike?'),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: _maxCommentLength,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              Text(
                'Reviews are public and can’t be edited after posting.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _rating == 0 || _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Post review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
