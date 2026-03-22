/// Photo picker grid widget for memory creation and editing.
///
/// Displays a horizontal row of photo slots with:
/// - Existing photos (shown via thumbnail URLs)
/// - New photos (shown via Uint8List bytes in memory)
/// - An "add" button when under the limit
/// - Remove (X) buttons on each photo
///
/// Cross-platform: uses [Image.memory] instead of [Image.file].
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Default maximum photos per memory (Firebase Storage).
/// Overridden to a higher limit when using Google Drive.
const kMaxMemoryPhotos = 3;

class PhotoPickerGrid extends StatelessWidget {
  const PhotoPickerGrid({
    super.key,
    this.existingThumbUrls = const [],
    this.newPhotos = const [],
    required this.onPickPhotos,
    this.onRemoveExisting,
    this.onRemoveNew,
    this.maxPhotos = kMaxMemoryPhotos,
  });

  final List<String> existingThumbUrls;
  final List<Uint8List> newPhotos;
  final VoidCallback onPickPhotos;
  final ValueChanged<int>? onRemoveExisting;
  final ValueChanged<int>? onRemoveNew;
  final int maxPhotos;

  int get _totalCount => existingThumbUrls.length + newPhotos.length;
  bool get _canAdd => _totalCount < maxPhotos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < existingThumbUrls.length; i++)
            _PhotoTile(
              key: ValueKey('existing_$i'),
              child: Image.network(
                existingThumbUrls[i],
                fit: BoxFit.cover,
                width: 100,
                height: 100,
                errorBuilder: (_, e, st) => _placeholder(),
              ),
              onRemove: onRemoveExisting != null
                  ? () => onRemoveExisting!(i)
                  : null,
            ),
          for (var i = 0; i < newPhotos.length; i++)
            _PhotoTile(
              key: ValueKey('new_$i'),
              child: Image.memory(
                newPhotos[i],
                fit: BoxFit.cover,
                width: 100,
                height: 100,
              ),
              onRemove: onRemoveNew != null ? () => onRemoveNew!(i) : null,
            ),
          if (_canAdd) _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onPickPhotos,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.cardVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.warmMuted.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.warmMuted,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                '$_totalCount/$maxPhotos',
                style: TextStyle(color: AppColors.warmMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _placeholder() {
    return Container(
      width: 100,
      height: 100,
      color: AppColors.cardVariant,
      child: Icon(Icons.broken_image, color: AppColors.warmMuted, size: 24),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({super.key, required this.child, this.onRemove});

  final Widget child;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (onRemove != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
