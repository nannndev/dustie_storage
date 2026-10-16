import 'dart:async';
import 'dart:io';
import 'dart:isolate';

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
  Isolate? _isolate;
  ReceivePort? _port;
  StreamController<String>? _progress;

  @override
  void cancelScan() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port?.close();
    _port = null;
    _progress?.close();
    _progress = null;
  }

  @override
  Stream<String> scanDirectory(
    String dirPath, {
    required Function(StorageSummary summary) onCompleted,
    required Function(String error) onError,
  }) {
    cancelScan();
    final progress = _progress = StreamController<String>();
    final port = _port = ReceivePort();

    port.listen((msg) {
      if (msg is String) {
        progress.add(msg);
      } else if (msg is StorageSummary) {
        onCompleted(msg);
        cancelScan();
      } else {
        // Uncaught isolate error arrives as [error, stack]; without this the UI would stay "scanning" forever
        debugPrint('LocalFileSystemDataSource scan error: $msg');
        onError(msg is List && msg.isNotEmpty ? '${msg.first}' : 'Scan failed');
        cancelScan();
      }
    });

    () async {
      if (!await Directory(dirPath).exists()) {
        onError('Directory does not exist');
        cancelScan();
        return;
      }
      // Walk the disk on a background isolate so the UI thread never blocks (macOS beachball)
      final isolate = await Isolate.spawn(_scanInIsolate, (
        port.sendPort,
        dirPath,
      ), onError: port.sendPort);
      if (identical(_port, port)) {
        _isolate = isolate;
      } else {
        isolate.kill(priority: Isolate.immediate); // cancelled while spawning
      }
    }();

    return progress.stream;
  }

  static void _scanInIsolate((SendPort, String) args) {
    final (send, rootPath) = args;
    final files = <StorageItem>[];
    final emptyFolders = <String>[];
    final stack = [rootPath];
    final clock = Stopwatch()..start();
    var lastProgress = -1000;

    while (stack.isNotEmpty) {
      final dirPath = stack.removeLast();
      final List<FileSystemEntity> children;
      try {
        children = Directory(dirPath).listSync(followLinks: false);
      } catch (_) {
        continue; // protected system dir: skip, and don't report it as empty
      }
      if (children.isEmpty && dirPath != rootPath) emptyFolders.add(dirPath);

      for (final entity in children) {
        if (entity is Directory) {
          stack.add(entity.path);
        } else if (entity is File) {
          try {
            final stat = entity.statSync();
            final ext = p.extension(entity.path);
            files.add(
              StorageItem(
                path: entity.path,
                name: p.basename(entity.path),
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

      // ~10 progress messages/sec is plenty for the status line
      if (clock.elapsedMilliseconds - lastProgress > 100) {
        lastProgress = clock.elapsedMilliseconds;
        send.send(dirPath);
      }
    }

    // Isolate.exit hands the result over without copying the (possibly huge) file list
    Isolate.exit(send, StorageSummary.fromFiles(rootPath, files, emptyFolders));
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
