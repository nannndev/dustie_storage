import '../../../../core/utils/file_size_formatter.dart';

enum SkipReason {
  /// Another process holds the file open (Windows sharing violation).
  inUse,

  /// The OS refused: needs admin rights or the file is read-only/protected.
  accessDenied,

  /// Dustie refused on purpose: toolchain, package cache or OS folder.
  protected,
  other,
}

/// Outcome of a best-effort delete: some paths may be removed while locked ones are skipped.
class DeleteResult {
  /// Paths that no longer exist on disk. A fully removed folder is listed once instead of per file.
  final Set<String> removedPaths;
  final int freedBytes;

  /// Files that could not be removed (in use, permission denied).
  final List<String> skippedPaths;

  /// Why each skipped path stayed; paths without an entry count as [SkipReason.other].
  final Map<String, SkipReason> skipReasons;

  const DeleteResult({
    this.removedPaths = const {},
    this.freedBytes = 0,
    this.skippedPaths = const [],
    this.skipReasons = const {},
  });

  bool get isComplete => skippedPaths.isEmpty;

  int countSkipped(SkipReason reason) => skippedPaths
      .where((p) => (skipReasons[p] ?? SkipReason.other) == reason)
      .length;

  /// e.g. "37 in use, 120 need admin" — empty when nothing was skipped.
  String get skipSummary {
    final parts = [
      if (countSkipped(SkipReason.inUse) case final n when n > 0) '$n in use',
      if (countSkipped(SkipReason.accessDenied) case final n when n > 0)
        '$n need admin',
      if (countSkipped(SkipReason.protected) case final n when n > 0)
        '$n protected',
      if (countSkipped(SkipReason.other) case final n when n > 0) '$n other',
    ];
    return parts.join(', ');
  }

  bool get removedAnything => removedPaths.isNotEmpty || freedBytes > 0;

  String get formattedFreed => FileSizeFormatter.format(freedBytes);

  DeleteResult merge(DeleteResult other) => DeleteResult(
    removedPaths: {...removedPaths, ...other.removedPaths},
    freedBytes: freedBytes + other.freedBytes,
    skippedPaths: [...skippedPaths, ...other.skippedPaths],
    skipReasons: {...skipReasons, ...other.skipReasons},
  );
}
