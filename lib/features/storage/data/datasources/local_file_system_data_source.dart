import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/delete_result.dart';
import '../../domain/entities/file_category.dart';
import '../../domain/entities/scan_progress.dart';
import '../../domain/entities/storage_item.dart';
import '../../domain/entities/storage_summary.dart';
import '../../domain/entities/protected_paths.dart';
import 'best_effort_delete.dart';

abstract class LocalFileSystemDataSource {
  Stream<ScanProgress> scanDirectory(
    String dirPath, {
    required Function(StorageSummary summary) onCompleted,
    required Function(String error) onError,
  });

  void cancelScan([String? dirPath]);

  Future<DeleteResult> deleteItem(StorageItem item);

  Future<DeleteResult> deleteItems(List<StorageItem> items);

  Future<bool> deleteDirectory(String dirPath);
}

class _ScanSession {
  final List<Isolate> isolates;
  final ReceivePort port;
  final StreamController<ScanProgress> progress;

  _ScanSession(this.isolates, this.port, this.progress);

  void cancel() {
    for (final iso in isolates) {
      iso.kill(priority: Isolate.immediate);
    }
    port.close();
    progress.close();
  }
}

class LocalFileSystemDataSourceImpl implements LocalFileSystemDataSource {
  final Map<String, _ScanSession> _sessions = {};

  @override
  void cancelScan([String? dirPath]) {
    if (dirPath != null) {
      _sessions.remove(dirPath)?.cancel();
    } else {
      for (final session in _sessions.values) {
        session.cancel();
      }
      _sessions.clear();
    }
  }

  @override
  Stream<ScanProgress> scanDirectory(
    String dirPath, {
    required Function(StorageSummary summary) onCompleted,
    required Function(String error) onError,
  }) {
    cancelScan(dirPath);

    final progress = StreamController<ScanProgress>.broadcast();
    final port = ReceivePort();
    final session = _ScanSession([], port, progress);
    _sessions[dirPath] = session;

    () async {
      final rootDir = Directory(dirPath);
      if (!await rootDir.exists()) {
        onError('Directory does not exist');
        cancelScan(dirPath);
        return;
      }

      final rootFiles = <StorageItem>[];
      final emptyFolders = <String>[];
      final topSubDirs = <String>[];

      try {
        final entries = rootDir.listSync(followLinks: false);
        if (entries.isEmpty) {
          emptyFolders.add(dirPath);
        }
        for (final entry in entries) {
          if (entry is Link) {
            continue;
          } else if (entry is Directory) {
            if (!_shouldSkip(entry.path)) {
              topSubDirs.add(entry.path);
            }
          } else if (entry is File) {
            try {
              final stat = entry.statSync();
              final ext = p.extension(entry.path);
              rootFiles.add(
                StorageItem(
                  path: entry.path,
                  name: p.basename(entry.path),
                  size: stat.size,
                  isDirectory: false,
                  modified: stat.modified,
                  extension: ext,
                  category: FileCategoryExt.fromExtension(ext),
                ),
              );
            } catch (_) {}
          }
        }
      } catch (e) {
        onError('Failed to access directory: $e');
        cancelScan(dirPath);
        return;
      }

      if (topSubDirs.isEmpty) {
        final summary = StorageSummary.fromFiles(
          dirPath,
          rootFiles,
          emptyFolders,
        );
        onCompleted(summary);
        cancelScan(dirPath);
        return;
      }

      // Parallel workers across top-level subdirectories
      final maxWorkers = (Platform.numberOfProcessors / 2).clamp(2, 4).toInt();
      final numWorkers = topSubDirs.length.clamp(1, maxWorkers);

      final workerDirs = List.generate(numWorkers, (_) => <String>[]);
      for (var i = 0; i < topSubDirs.length; i++) {
        workerDirs[i % numWorkers].add(topSubDirs[i]);
      }

      final allFiles = List<StorageItem>.from(rootFiles);
      final allEmptyFolders = List<String>.from(emptyFolders);
      var completedWorkers = 0;
      // Latest cumulative totals per worker; summed so the UI sees one running total.
      final rootCategoryBytes = List.filled(FileCategory.values.length, 0);
      for (final f in rootFiles) {
        rootCategoryBytes[f.category.index] += f.size;
      }
      final workerCounts = List.filled(numWorkers, 0);
      final workerCategoryBytes = List.generate(
        numWorkers,
        (_) => List.filled(FileCategory.values.length, 0),
      );

      port.listen((msg) {
        if (!_sessions.containsKey(dirPath)) return;

        if (msg is Map) {
          final type = msg['type'];
          if (type == 'progress') {
            final w = msg['worker'] as int;
            workerCounts[w] = msg['count'] as int;
            workerCategoryBytes[w] = msg['categoryBytes'] as List<int>;
            final cats = List<int>.from(rootCategoryBytes);
            for (final wc in workerCategoryBytes) {
              for (var i = 0; i < cats.length; i++) {
                cats[i] += wc[i];
              }
            }
            progress.add(
              ScanProgress(
                fileCount:
                    rootFiles.length + workerCounts.fold(0, (a, b) => a + b),
                bytes: cats.fold(0, (a, b) => a + b),
                categoryBytes: cats,
                currentPath: msg['path'] as String,
              ),
            );
          } else if (type == 'done') {
            final f = msg['files'] as List<StorageItem>;
            final e = msg['emptyFolders'] as List<String>;
            allFiles.addAll(f);
            allEmptyFolders.addAll(e);
            completedWorkers++;

            if (completedWorkers >= numWorkers) {
              final summary = StorageSummary.fromFiles(
                dirPath,
                allFiles,
                allEmptyFolders,
              );
              onCompleted(summary);
              cancelScan(dirPath);
            }
          }
        } else {
          debugPrint('LocalFileSystemDataSource isolate message: $msg');
          completedWorkers++;
          if (completedWorkers >= numWorkers) {
            final summary = StorageSummary.fromFiles(
              dirPath,
              allFiles,
              allEmptyFolders,
            );
            onCompleted(summary);
            cancelScan(dirPath);
          }
        }
      });

      for (var i = 0; i < numWorkers; i++) {
        try {
          final isolate = await Isolate.spawn(_scanWorker, (
            port.sendPort,
            workerDirs[i],
            dirPath,
            i,
          ), onError: port.sendPort);
          if (_sessions.containsKey(dirPath)) {
            session.isolates.add(isolate);
          } else {
            isolate.kill(priority: Isolate.immediate);
          }
        } catch (e) {
          debugPrint('Failed to spawn worker isolate: $e');
        }
      }
    }();

    return progress.stream;
  }

  static void _scanWorker((SendPort, List<String>, String, int) args) {
    final (send, targetDirs, rootPath, workerId) = args;
    final files = <StorageItem>[];
    final emptyFolders = <String>[];
    final clock = Stopwatch()..start();
    var lastProgress = -1000;
    final categoryBytes = List.filled(FileCategory.values.length, 0);

    for (final startDir in targetDirs) {
      final stack = [startDir];

      while (stack.isNotEmpty) {
        final currentDir = stack.removeLast();
        final List<FileSystemEntity> children;
        try {
          children = Directory(currentDir).listSync(followLinks: false);
        } catch (_) {
          continue;
        }

        if (children.isEmpty && currentDir != rootPath) {
          emptyFolders.add(currentDir);
          continue;
        }

        for (final entity in children) {
          if (entity is Link) {
            continue;
          } else if (entity is Directory) {
            if (!_shouldSkip(entity.path)) {
              stack.add(entity.path);
            }
          } else if (entity is File) {
            try {
              final stat = entity.statSync();
              final ext = p.extension(entity.path);
              final size = stat.size;
              final category = FileCategoryExt.fromExtension(ext);
              categoryBytes[category.index] += size;
              files.add(
                StorageItem(
                  path: entity.path,
                  name: p.basename(entity.path),
                  size: size,
                  isDirectory: false,
                  modified: stat.modified,
                  extension: ext,
                  category: category,
                ),
              );
            } catch (_) {}
          }
        }

        if (clock.elapsedMilliseconds - lastProgress > 120) {
          lastProgress = clock.elapsedMilliseconds;
          send.send({
            'type': 'progress',
            'worker': workerId,
            'path': currentDir,
            'count': files.length,
            'categoryBytes': List<int>.of(categoryBytes),
          });
        }
      }
    }

    send.send({'type': 'done', 'files': files, 'emptyFolders': emptyFolders});
  }

  static bool _shouldSkip(String path) {
    final base = p.basename(path).toLowerCase();
    if (base.startsWith(r'$') || base == 'system volume information') {
      return true;
    }
    final normalized = path.replaceAll('/', '\\').toLowerCase();
    if (normalized.endsWith(r'\windows\winsxs') ||
        normalized.contains(r'\windows\winsxs\') ||
        normalized.endsWith(r'\windows\servicing') ||
        normalized.contains(r'\windows\servicing\')) {
      return true;
    }
    return false;
  }

  @override
  Future<DeleteResult> deleteItem(StorageItem item) => deleteItems([item]);

  @override
  Future<DeleteResult> deleteItems(List<StorageItem> items) {
    final targets = [for (final i in items) (i.path, i.isDirectory)];
    // Sync IO on an isolate: a Temp folder can hold tens of thousands of files.
    return Isolate.run(() {
      var result = const DeleteResult();
      for (final (path, isDir) in targets) {
        result = result.merge(
          isDir ? BestEffortDelete.tree(path) : BestEffortDelete.file(path),
        );
      }
      return result;
    });
  }

  @override
  Future<bool> deleteDirectory(String dirPath) async {
    try {
      if (ProtectedPaths.isProtected(dirPath)) return false;
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
