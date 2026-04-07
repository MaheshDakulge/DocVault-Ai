import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Manages the local file system for document images and exports.
///
/// Storage layout (Android):
///   /data/user/0/com.docsvaultai.digisafe/
///     files/
///       docs/
///         {uuid}.jpg           ← full-resolution scanned image
///         {uuid}_thumb.jpg     ← 200×200 thumbnail for list view
///         {uuid}_p2.jpg        ← page 2 of multi-page document
///       exports/
///         bundle_{timestamp}.zip   ← temporary export bundles
///
/// iOS equivalent: <Documents>/docsvault/
class FileSystemService {
  static const _uuid = Uuid();

  // ── Base Directories ──────────────────────────────────────────────────────

  static Future<Directory> get _docsDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'docsvault', 'docs'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> get _exportsDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'docsvault', 'exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Save Scanned Image ────────────────────────────────────────────────────

  /// Save [imageBytes] to disk and return [SavedImageResult] containing
  /// paths + a freshly generated UUID for the document.
  static Future<SavedImageResult> saveScannedImage(Uint8List imageBytes) async {
    final docId = _uuid.v4();
    final dir   = await _docsDir;

    // Full-res image
    final imagePath = p.join(dir.path, '$docId.jpg');
    await File(imagePath).writeAsBytes(imageBytes);

    // Generate 200×200 thumbnail in an isolate (non-blocking)
    final thumbPath = p.join(dir.path, '${docId}_thumb.jpg');
    await compute(_generateThumbnail, _ThumbnailTask(imageBytes, thumbPath));

    return SavedImageResult(docId: docId, imagePath: imagePath, thumbPath: thumbPath);
  }

  /// Read raw bytes of a saved image by its [path]
  static Future<Uint8List?> readImageBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// Delete all files for a given document UUID
  static Future<void> deleteDocumentFiles(String docId) async {
    final dir = await _docsDir;
    for (final suffix in ['', '_thumb', '_p2', '_p3']) {
      final f = File(p.join(dir.path, '$docId$suffix.jpg'));
      if (await f.exists()) await f.delete();
    }
  }

  /// Check if the image file still exists on disk (tamper / deletion check)
  static Future<bool> fileExists(String path) => File(path).exists();

  // ── Thumbnail generation (runs in isolate) ────────────────────────────────
  static Future<void> _generateThumbnail(_ThumbnailTask task) async {
    final decoded = img.decodeImage(task.bytes);
    if (decoded == null) return;
    final thumb = img.copyResize(decoded, width: 200, height: 200);
    await File(task.outputPath).writeAsBytes(img.encodeJpg(thumb, quality: 80));
  }

  // ── Export helpers ────────────────────────────────────────────────────────
  static Future<String> getExportBundlePath() async {
    final dir = await _exportsDir;
    final ts  = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, 'bundle_$ts.zip');
  }
}

class _ThumbnailTask {
  final Uint8List bytes;
  final String outputPath;
  _ThumbnailTask(this.bytes, this.outputPath);
}

class SavedImageResult {
  final String docId;
  final String imagePath;
  final String thumbPath;
  const SavedImageResult({
    required this.docId,
    required this.imagePath,
    required this.thumbPath,
  });
}
