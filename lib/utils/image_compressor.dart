/// Cross-platform image compression using the pure-Dart `image` package.
///
/// Works on iOS, Android, Web, and macOS. Uses `compute()` to run
/// decoding and encoding off the main isolate on mobile.
library;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Compresses images to JPEG at specified dimensions.
///
/// All methods return `Uint8List` (raw JPEG bytes) — no `dart:io` dependency.
abstract final class ImageCompressor {
  /// Compresses to max 1920px longest edge, JPEG quality 80.
  static Future<Uint8List> compressFull(Uint8List bytes) {
    return compute(_compressFull, bytes);
  }

  /// Compresses to max 300px longest edge, JPEG quality 80.
  static Future<Uint8List> compressThumb(Uint8List bytes) {
    return compute(_compressThumb, bytes);
  }

  static Uint8List _compressFull(Uint8List bytes) {
    return _resize(bytes, maxDimension: 1920, quality: 80);
  }

  static Uint8List _compressThumb(Uint8List bytes) {
    return _resize(bytes, maxDimension: 300, quality: 80);
  }

  static Uint8List _resize(
    Uint8List bytes, {
    required int maxDimension,
    required int quality,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final needsResize =
        decoded.width > maxDimension || decoded.height > maxDimension;

    final image = needsResize
        ? (decoded.width >= decoded.height
            ? img.copyResize(decoded, width: maxDimension)
            : img.copyResize(decoded, height: maxDimension))
        : decoded;

    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }
}
