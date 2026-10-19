import 'file_category.dart';

/// Live totals while a scan runs, summed across all worker isolates.
class ScanProgress {
  final int fileCount;
  final int bytes;

  /// Bytes per [FileCategory], indexed by `FileCategory.index`.
  final List<int> categoryBytes;
  final String currentPath;

  const ScanProgress({
    required this.fileCount,
    required this.bytes,
    required this.categoryBytes,
    required this.currentPath,
  });

  factory ScanProgress.empty(String path) => ScanProgress(
    fileCount: 0,
    bytes: 0,
    categoryBytes: List.filled(FileCategory.values.length, 0),
    currentPath: path,
  );

  int bytesOf(FileCategory c) => categoryBytes[c.index];
}
