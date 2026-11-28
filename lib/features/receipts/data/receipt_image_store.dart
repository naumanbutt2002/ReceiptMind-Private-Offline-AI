/// Paths of one stored receipt image, relative to the app support directory.
typedef StoredImage = ({String image, String thumbnail});

/// Keeps receipt photos in `<app support>/receipts/`: a JPEG (quality 80,
/// long edge ≤ 2400 px, no EXIF; very long receipts keep a readable width)
/// and a 360 px wide thumbnail in `thumbs/`.
/// The database stores the relative paths (see PLAN §10).
abstract interface class ReceiptImageStore {
  /// Compresses the scan at [sourcePath] into `receipts/<id>.jpg` plus its
  /// thumbnail. The source file is left alone. On failure nothing is left
  /// behind and a `ReceiptStorageException` says why (e.g. storage full).
  Future<StoredImage> importScan(String sourcePath, {required String id});

  /// Absolute path for a stored relative path.
  Future<String> resolve(String relativePath);

  /// Relative thumbnail path for a relative image path:
  /// `receipts/<id>.jpg` → `receipts/thumbs/<id>.jpg`.
  String thumbnailFor(String relativeImagePath);

  /// Deletes an image and its thumbnail. Missing files are ignored.
  Future<void> delete(String relativeImagePath);

  /// Deletes stored images (and thumbnails) that no receipt references any
  /// more. Returns how many images were removed.
  Future<int> deleteOrphans(Set<String> referencedImagePaths);
}
