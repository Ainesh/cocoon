/// Storage service for Kairos app.
///
/// Handles Firebase Storage operations for memory photos:
/// - Upload full-size + thumbnail pairs (from Uint8List bytes)
/// - Delete individual or all photos for a memory
/// - Resolve storage paths to download URLs with caching
///
/// Cross-platform: uses `putData()` (Uint8List) instead of `putFile()` (File),
/// so it works on web, iOS, Android, and macOS.
library;

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'drive_storage_service.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  final _driveService = DriveStorageService();

  final _urlCache = <String, String>{};

  // ---------------------------------------------------------------------------
  // URL Resolution (routes between Firebase and Drive)
  // ---------------------------------------------------------------------------

  /// Resolves a storage path/ID to a download URL.
  ///
  /// Routes based on [storageProvider]:
  /// - `'firebase'` (default): Firebase Storage path → `getDownloadURL()`
  /// - `'drive'`: Google Drive file ID → `webContentLink`
  Future<String> resolveUrl(
    String pathOrId, {
    String storageProvider = 'firebase',
  }) async {
    final cached = _urlCache[pathOrId];
    if (cached != null) return cached;

    final String url;
    if (storageProvider == 'drive') {
      url = await _driveService.resolveUrl(pathOrId);
    } else {
      url = await _storage.ref(pathOrId).getDownloadURL();
    }
    _urlCache[pathOrId] = url;
    return url;
  }

  /// Resolves multiple paths/IDs in parallel.
  Future<List<String>> resolveUrls(
    List<String> paths, {
    String storageProvider = 'firebase',
  }) {
    return Future.wait(
      paths.map((p) => resolveUrl(p, storageProvider: storageProvider)),
    );
  }

  void evictFromCache(String pathOrId) => _urlCache.remove(pathOrId);

  void clearCache() {
    _urlCache.clear();
    _driveService.clearCache();
  }

  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------

  /// Uploads full-size + thumbnail photo pairs for a memory.
  ///
  /// Accepts raw JPEG bytes ([Uint8List]) — no `dart:io` dependency.
  /// [startIndex] allows appending to existing photos during edits.
  Future<({List<String> photoPaths, List<String> thumbPaths})>
      uploadMemoryPhotos({
    required String spaceId,
    required String memoryId,
    required List<Uint8List> fullPhotos,
    required List<Uint8List> thumbPhotos,
    int startIndex = 0,
  }) async {
    assert(
      fullPhotos.length == thumbPhotos.length,
      'Full photos and thumbnails must be paired',
    );

    final photoPaths = <String>[];
    final thumbPaths = <String>[];
    final basePath = 'spaces/$spaceId/memories/$memoryId';
    final metadata = SettableMetadata(contentType: 'image/jpeg');

    for (var i = 0; i < fullPhotos.length; i++) {
      final idx = startIndex + i;
      final fullPath = '$basePath/photo_$idx.jpg';
      final thumbPath = '$basePath/photo_${idx}_thumb.jpg';

      await _storage.ref(fullPath).putData(fullPhotos[i], metadata);
      await _storage.ref(thumbPath).putData(thumbPhotos[i], metadata);

      photoPaths.add(fullPath);
      thumbPaths.add(thumbPath);
    }

    return (photoPaths: photoPaths, thumbPaths: thumbPaths);
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

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

  Future<void> deleteFiles(List<String> paths) async {
    for (final path in paths) {
      await _storage.ref(path).delete();
      _urlCache.remove(path);
    }
  }
}
