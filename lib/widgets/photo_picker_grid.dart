/// Photo picker grid widget for memory creation and editing.
///
/// Displays a horizontal row of photo slots (max 3) with:
/// - Existing photos (shown via thumbnail URLs or File previews)
/// - An "add" button when under the limit
/// - Remove (X) buttons on each photo
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Maximum number of photos per memory.
const kMaxMemoryPhotos = 3;

/// A horizontal row of photo slots for picking, previewing, and removing photos.
///
/// Supports two types of photos:
/// - [existingThumbUrls]: Already-uploaded photos shown via network URL
/// - [newPhotos]: Freshly picked [File]s shown via file preview
class PhotoPickerGrid extends StatelessWidget {
  const PhotoPickerGrid({
    super.key,
    this.existingThumbUrls = const [],
    this.newPhotos = const [],
    required this.onPickPhotos,
    this.onRemoveExisting,
    this.onRemoveNew,
  });

  /// Thumbnail URLs for already-uploaded photos.
  final List<String> existingThumbUrls;

  /// Freshly picked photo files (not yet uploaded).
  final List<File> newPhotos;

  /// Called when the user taps the add button.
  final VoidCallback onPickPhotos;

  /// Called when the user removes an existing (uploaded) photo by index.
  final ValueChanged<int>? onRemoveExisting;

  /// Called when the user removes a new (not yet uploaded) photo by index.
  final ValueChanged<int>? onRemoveNew;

  int get _totalCount => existingThumbUrls.length + newPhotos.length;
  bool get _canAdd => _totalCount < kMaxMemoryPhotos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Existing photos (from URLs)
          for (var i = 0; i < existingThumbUrls.length; i++)
            _PhotoTile(
              key: ValueKey('existing_$i'),
              child: Image.network(
                existingThumbUrls[i],
                fit: BoxFit.cover,
                width: 100,
                height: 100,
                errorBuilder: (_, __, ___) => _placeholder(),
              ),
              onRemove: onRemoveExisting != null ? () => onRemoveExisting!(i) : null,
            ),

          // New photos (from Files)
          for (var i = 0; i < newPhotos.length; i++)
            _PhotoTile(
              key: ValueKey('new_$i'),
              child: Image.file(
                newPhotos[i],
                fit: BoxFit.cover,
                width: 100,
                height: 100,
              ),
              onRemove: onRemoveNew != null ? () => onRemoveNew!(i) : null,
            ),

          // Add button
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
                '$_totalCount/$kMaxMemoryPhotos',
                style: TextStyle(
                  color: AppColors.warmMuted,
                  fontSize: 11,
                ),
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

/// A single photo tile with a remove button overlay.
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
