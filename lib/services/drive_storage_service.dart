/// Google Drive storage service for Kairos app.
///
/// Uploads memory photos to the user's own Google Drive instead of
/// Firebase Storage. Photos are made shareable ("anyone with link")
/// so the partner can view them without their own Drive auth.
///
/// Folder structure: `Kairos / {spaceName} / {memoryId} /`
///
/// Uses the `drive.file` scope — only accesses files the app creates.
library;

import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Max photos per memory when using Drive (no Firebase cost constraint).
const kMaxDrivePhotos = 10;

class DriveStorageService {
  static final _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.file'],
  );

  final _urlCache = <String, String>{};

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  Future<drive.DriveApi?> _getDriveApi() async {
    var account = await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    if (account == null) return null;

    final authHeaders = await account.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    return drive.DriveApi(client);
  }

  // ---------------------------------------------------------------------------
  // Folders
  // ---------------------------------------------------------------------------

  /// Ensures the folder hierarchy `Kairos / {spaceName} / {memoryId}` exists.
  /// Returns the leaf folder ID.
  Future<String?> ensureFolder(
    drive.DriveApi api,
    String spaceName,
    String memoryId,
  ) async {
    final rootId = await _findOrCreateFolder(api, 'Kairos', 'root');
    if (rootId == null) return null;

    final spaceId = await _findOrCreateFolder(api, spaceName, rootId);
    if (spaceId == null) return null;

    return _findOrCreateFolder(api, memoryId, spaceId);
  }

  Future<String?> _findOrCreateFolder(
    drive.DriveApi api,
    String name,
    String parentId,
  ) async {
    final query = "name = '$name' and mimeType = 'application/vnd.google-apps.folder' "
        "and '$parentId' in parents and trashed = false";
    final result = await api.files.list(q: query, spaces: 'drive');
    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id;
    }

    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [parentId];
    final created = await api.files.create(folder);
    return created.id;
  }

  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------

  /// Uploads full-size + thumbnail photo pairs to Google Drive.
  ///
  /// Returns file IDs (not URLs). Use [resolveUrl] to get viewable links.
  Future<({List<String> photoIds, List<String> thumbIds})?> uploadPhotos({
    required String spaceName,
    required String memoryId,
    required List<Uint8List> fullPhotos,
    required List<Uint8List> thumbPhotos,
    int startIndex = 0,
  }) async {
    assert(fullPhotos.length == thumbPhotos.length);

    final api = await _getDriveApi();
    if (api == null) return null;

    final folderId = await ensureFolder(api, spaceName, memoryId);
    if (folderId == null) return null;

    final photoIds = <String>[];
    final thumbIds = <String>[];

    for (var i = 0; i < fullPhotos.length; i++) {
      final idx = startIndex + i;
      final fullId = await _uploadFile(
        api,
        folderId,
        'photo_$idx.jpg',
        fullPhotos[i],
      );
      final thumbId = await _uploadFile(
        api,
        folderId,
        'photo_${idx}_thumb.jpg',
        thumbPhotos[i],
      );
      if (fullId != null) photoIds.add(fullId);
      if (thumbId != null) thumbIds.add(thumbId);
    }

    return (photoIds: photoIds, thumbIds: thumbIds);
  }

  Future<String?> _uploadFile(
    drive.DriveApi api,
    String folderId,
    String fileName,
    Uint8List bytes,
  ) async {
    final file = drive.File()
      ..name = fileName
      ..parents = [folderId]
      ..mimeType = 'image/jpeg';

    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'image/jpeg',
    );

    final created = await api.files.create(file, uploadMedia: media);
    final fileId = created.id;
    if (fileId == null) return null;

    // Make shareable: anyone with the link can view
    await api.permissions.create(
      drive.Permission()
        ..type = 'anyone'
        ..role = 'reader',
      fileId,
    );

    return fileId;
  }

  // ---------------------------------------------------------------------------
  // URL Resolution
  // ---------------------------------------------------------------------------

  /// Resolves a Drive file ID to a direct viewable URL.
  Future<String> resolveUrl(String fileId) async {
    final cached = _urlCache[fileId];
    if (cached != null) return cached;

    final api = await _getDriveApi();
    if (api == null) {
      return 'https://drive.google.com/uc?id=$fileId';
    }

    final file = await api.files.get(
      fileId,
      $fields: 'webContentLink,thumbnailLink',
    ) as drive.File;

    final url = file.webContentLink ??
        'https://drive.google.com/uc?id=$fileId';
    _urlCache[fileId] = url;
    return url;
  }

  /// Resolves multiple file IDs in parallel.
  Future<List<String>> resolveUrls(List<String> fileIds) {
    return Future.wait(fileIds.map(resolveUrl));
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  Future<void> deleteFiles(List<String> fileIds) async {
    final api = await _getDriveApi();
    if (api == null) return;

    for (final id in fileIds) {
      try {
        await api.files.delete(id);
        _urlCache.remove(id);
      } catch (_) {
        // File may already be deleted
      }
    }
  }

  void evictFromCache(String fileId) => _urlCache.remove(fileId);
  void clearCache() => _urlCache.clear();
}

/// Minimal HTTP client that injects Google auth headers.
class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
