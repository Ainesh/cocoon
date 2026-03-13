/// Storage service for Kairos app.
///
/// Handles Firebase Storage operations for memory photos:
/// - Upload full-size + thumbnail pairs
/// - Delete individual or all photos for a memory
/// - Resolve storage paths to download URLs with caching
library;

import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Service for Firebase Storage operations related to memory photos.
///
/// Photo files follow the naming convention:
/// ```
/// spaces/{spaceId}/memories/{memoryId}/photo_{index}.jpg       (full-size)
/// spaces/{spaceId}/memories/{memoryId}/photo_{index}_thumb.jpg  (thumbnail)
/// ```
class StorageService {
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Download URL cache: storage path → URL.
  /// Avoids repeated getDownloadURL() calls for the same path.
  final _urlCache = <String, String>{};

  // ---------------------------------------------------------------------------
  // URL Resolution
  // ---------------------------------------------------------------------------

  /// Resolves a storage path to a download URL, using an in-memory cache.
  Future<String> resolveUrl(String storagePath) async {
    final cached = _urlCache[storagePath];
    if (cached != null) return cached;

    final url = await _storage.ref(storagePath).getDownloadURL();
    _urlCache[storagePath] = url;
    return url;
  }

  /// Resolves multiple storage paths in parallel.
  Future<List<String>> resolveUrls(List<String> paths) {
    return Future.wait(paths.map(resolveUrl));
  }

  /// Evicts a specific path from the URL cache.
  void evictFromCache(String storagePath) => _urlCache.remove(storagePath);

  /// Clears the entire URL cache.
  void clearCache() => _urlCache.clear();

  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------

  /// Uploads full-size + thumbnail photo pairs for a memory.
  ///
  /// [fullPhotos] and [thumbPhotos] must be the same length.
  /// [startIndex] allows appending to existing photos during edits.
  ///
  /// Returns a record of (photoPaths, thumbPaths) as Firebase Storage paths.
  Future<({List<String> photoPaths, List<String> thumbPaths})>
      uploadMemoryPhotos({
    required String spaceId,
    required String memoryId,
    required List<File> fullPhotos,
    required List<File> thumbPhotos,
    int startIndex = 0,
  }) async {
    assert(
      fullPhotos.length == thumbPhotos.length,
      'Full photos and thumbnails must be paired',
    );

    final photoPaths = <String>[];
    final thumbPaths = <String>[];
    final basePath = 'spaces/$spaceId/memories/$memoryId';

    for (var i = 0; i < fullPhotos.length; i++) {
      final idx = startIndex + i;
      final fullPath = '$basePath/photo_$idx.jpg';
      final thumbPath = '$basePath/photo_${idx}_thumb.jpg';

      await _storage.ref(fullPath).putFile(
        fullPhotos[i],
        SettableMetadata(contentType: 'image/jpeg'),
      );
      await _storage.ref(thumbPath).putFile(
        thumbPhotos[i],
        SettableMetadata(contentType: 'image/jpeg'),
      );

      photoPaths.add(fullPath);
      thumbPaths.add(thumbPath);
    }

    return (photoPaths: photoPaths, thumbPaths: thumbPaths);
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Deletes all photos (full + thumb) under a memory's storage folder.
  Future<void> deleteAllMemoryPhotos({
    required String spaceId,
    required String memoryId,
  }) async {
    final ref = _storage.ref('spaces/$spaceId/memories/$memoryId');
    final listResult = await ref.listAll();
    for (final item in listResult.items) {
      await item.delete();
      _urlCache.remove(item.fullPath);
    }
  }

  /// Deletes specific files by their storage paths.
  Future<void> deleteFiles(List<String> paths) async {
    for (final path in paths) {
      await _storage.ref(path).delete();
      _urlCache.remove(path);
    }
  }
}
