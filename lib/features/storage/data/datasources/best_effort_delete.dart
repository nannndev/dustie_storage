import 'dart:io';

import '../../domain/entities/delete_result.dart';
import '../../domain/entities/protected_paths.dart';

/// Sync, isolate-only helpers: they block on IO and must never run on the UI thread.
class BestEffortDelete {
  static DeleteResult _refuse(String path) => DeleteResult(
    skippedPaths: [path],
    skipReasons: {path: SkipReason.protected},
  );

  static DeleteResult file(String path) {
    if (ProtectedPaths.isProtected(path)) return _refuse(path);
    final file = File(path);
    if (!file.existsSync()) return DeleteResult(removedPaths: {path});
    final size = _safeLength(file);
    final reason = _tryDeleteFile(file);
    return reason == null
        ? DeleteResult(removedPaths: {path}, freedBytes: size)
        : DeleteResult(skippedPaths: [path], skipReasons: {path: reason});
  }

  /// Removes everything it can under [root]; locked files (and the folders holding them) stay.
  ///
  /// [keepRoot] empties the folder but leaves it in place (Temp, caches).
  /// [olderThan] only touches files last modified before that moment.
  static DeleteResult tree(
    String root, {
    bool keepRoot = false,
    DateTime? olderThan,
  }) {
    if (ProtectedPaths.isProtected(root)) return _refuse(root);
    final rootDir = Directory(root);
    if (!rootDir.existsSync()) {
      return keepRoot
          ? const DeleteResult()
          : DeleteResult(removedPaths: {root});
    }

    final removed = <String>{};
    final skipped = <String>[];
    final reasons = <String, SkipReason>{};
    final dirs = <String>[];
    var freed = 0;

    try {
      for (final entity in rootDir.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is Directory) {
          dirs.add(entity.path);
        } else if (entity is File) {
          if (olderThan != null && !_isOlder(entity, olderThan)) continue;
          // Deleting e.g. a home folder must still leave toolchains nested inside it alone.
          if (ProtectedPaths.isProtected(entity.path)) {
            skipped.add(entity.path);
            reasons[entity.path] = SkipReason.protected;
            continue;
          }
          final size = _safeLength(entity);
          final reason = _tryDeleteFile(entity);
          if (reason == null) {
            removed.add(entity.path);
            freed += size;
          } else {
            skipped.add(entity.path);
            reasons[entity.path] = reason;
          }
        } else if (entity is Link) {
          // Never follow links out of the tree; just drop the link itself.
          try {
            entity.deleteSync();
          } catch (_) {}
        }
      }
    } on FileSystemException catch (e) {
      // Listing can fail partway (permission on a subfolder); keep what we already removed.
      final path = e.path ?? root;
      skipped.add(path);
      reasons[path] = classify(e);
    }

    // Deepest first, so parents are empty by the time we reach them. Non-empty ones just fail.
    dirs.sort((a, b) => b.length.compareTo(a.length));
    for (final d in [...dirs, if (!keepRoot) root]) {
      try {
        Directory(d).deleteSync();
        if (keepRoot) removed.add(d);
      } catch (_) {}
    }

    if (!keepRoot && !rootDir.existsSync()) {
      return DeleteResult(removedPaths: {root}, freedBytes: freed);
    }
    return DeleteResult(
      removedPaths: removed,
      freedBytes: freed,
      skippedPaths: skipped,
      skipReasons: reasons,
    );
  }

  static bool _isOlder(File f, DateTime cutoff) {
    try {
      return f.lastModifiedSync().isBefore(cutoff);
    } catch (_) {
      return false;
    }
  }

  static int _safeLength(File f) {
    try {
      return f.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  /// Lock policy: Windows locks are often momentary (AV scan, indexer), so retry once after a short pause.
  /// Returns null on success, otherwise why the file stayed.
  static SkipReason? _tryDeleteFile(File file) {
    SkipReason reason = SkipReason.other;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        file.deleteSync();
        return null;
      } on FileSystemException catch (e) {
        if (!file.existsSync()) return null;
        reason = classify(e);
        // Permission errors never clear by themselves; only retry locks.
        if (reason != SkipReason.inUse) break;
        if (attempt == 0) sleep(const Duration(milliseconds: 50));
      }
    }
    return reason;
  }

  /// Maps OS error codes: Windows 32/33 = sharing/lock violation, 5 = access denied;
  /// POSIX EACCES(13)/EPERM(1) = permission, EBUSY(16)/ETXTBSY(26) = in use.
  static SkipReason classify(FileSystemException e) {
    final code = e.osError?.errorCode;
    if (Platform.isWindows) {
      return switch (code) {
        32 || 33 => SkipReason.inUse,
        5 => SkipReason.accessDenied,
        _ => SkipReason.other,
      };
    }
    return switch (code) {
      13 || 1 => SkipReason.accessDenied,
      16 || 26 => SkipReason.inUse,
      _ => SkipReason.other,
    };
  }
}
