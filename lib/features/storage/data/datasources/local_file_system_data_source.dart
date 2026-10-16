import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../domain/entities/file_category.dart';
import '../../domain/entities/storage_item.dart';
import '../../domain/entities/storage_summary.dart';

abstract class LocalFileSystemDataSource {
  Stream<String> scanDirectory(
    String dirPath, {
    required Function(StorageSummary summary) onCompleted,
    required Function(String error) onError,
  });

  void cancelScan();

  Future<bool> deleteItem(StorageItem item);

  Future<int> deleteItems(List<StorageItem> items);

  Future<bool> deleteDirectory(String dirPath);
}

class LocalFileSystemDataSourceImpl implements LocalFileSystemDataSource {
  bool _isCancelled = false;

  @override
  void cancelScan() {
    _isCancelled = true;
  }

  @override
  Stream<String> scanDirectory(
    String dirPath, {
    required Function(StorageSummary summary) onCompleted,
    required Function(String error) onError,
  }) async* {
    _isCancelled = false;

    final rootDir = Directory(dirPath);
    if (!await rootDir.exists()) {
      onError('Directory does not exist');
      return;
    }

    final List<StorageItem> files = [];
    final List<String> allDirs = [];
    final Set<String> nonEmptyDirs = {};

    int scannedCount = 0;
    DateTime lastYield = DateTime.now();

    try {
      final lister = rootDir
          .list(recursive: true, followLinks: false)
          .handleError((error) {
            // Silently continue scanning across protected system directories
          });

      await for (final entity in lister) {
        if (_isCancelled) break;

        scannedCount++;
        final now = DateTime.now();

        // Throttle progress updates to ~15fps for ultra-smooth UI
        if (now.difference(lastYield).inMilliseconds > 70) {
          lastYield = now;
          yield entity.path;
        }

        nonEmptyDirs.add(p.dirname(entity.path));

        try {
          if (entity is File) {
            // Sync stat avoids an IO-thread round trip per file (async stat was the main bottleneck)
            final stat = entity.statSync();
            final ext = p.extension(entity.path);
            final name = p.basename(entity.path);
            final category = FileCategoryExt.fromExtension(ext);

            final item = StorageItem(
              path: entity.path,
              name: name,
              size: stat.size,
              isDirectory: false,
              modified: stat.modified,
              extension: ext,
              category: category,
            );

            files.add(item);
          } else if (entity is Directory) {
            allDirs.add(entity.path);
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      debugPrint('LocalFileSystemDataSource scan error: $e');
    }

    // shortcut: unreadable (permission-denied) dirs also look empty here, same as before since list() failed silently
    final emptyFolders = _isCancelled ? <String>[] : allDirs.where((d) => !nonEmptyDirs.contains(d)).toList();

    final summary = StorageSummary.fromFiles(dirPath, files, emptyFolders);

    yield 'Scan completed ($scannedCount items)';
    onCompleted(summary);
  }

  @override
  Future<bool> deleteItem(StorageItem item) async {
    try {
      if (item.isDirectory) {
        final dir = Directory(item.path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          return true;
        }
      } else {
        final file = File(item.path);
        if (await file.exists()) {
          await file.delete();
          return true;
        }
      }
    } catch (e) {
      debugPrint('Delete error: $e');
    }
    return false;
  }

  @override
  Future<int> deleteItems(List<StorageItem> items) async {
    int totalFreed = 0;
    for (final item in items) {
      if (await deleteItem(item)) {
        totalFreed += item.size;
      }
    }
    return totalFreed;
  }

  @override
  Future<bool> deleteDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
