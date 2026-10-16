import 'dart:isolate';

import 'package:equatable/equatable.dart';

import 'bento_node.dart';
import 'file_category.dart';
import 'storage_item.dart';

class StorageSummary extends Equatable {
  final String rootPath;

  /// Always sorted largest-first, so views can take/filter without re-sorting a million items on the UI thread.
  final List<StorageItem> files;
  final List<StorageItem> folders;
  final int totalSize;
  final Map<FileCategory, int> categorySizeMap;
  final Map<FileCategory, int> categoryCountMap;
  final List<StorageItem> dustyItems;
  final List<StorageItem> largeItems;
  final List<StorageItem> installerItems;
  final List<StorageItem> archiveItems;
  final Map<String, List<StorageItem>> duplicateGroups;
  final List<String> emptyFolders;

  /// Root level of the Bento treemap, prebuilt with the summary (on the scan isolate) so the UI never walks all files.
  final BentoNode? rootTree;

  const StorageSummary({
    required this.rootPath,
    required this.files,
    required this.folders,
    required this.totalSize,
    required this.categorySizeMap,
    required this.categoryCountMap,
    required this.dustyItems,
    required this.largeItems,
    required this.installerItems,
    required this.archiveItems,
    required this.duplicateGroups,
    required this.emptyFolders,
    this.rootTree,
  });

  /// Derives every grouping from the flat file list, so a summary can be rebuilt after deletes without rescanning.
  factory StorageSummary.fromFiles(
    String rootPath,
    List<StorageItem> files,
    List<String> emptyFolders, {
    bool presorted = false,
  }) {
    if (!presorted) files.sort((a, b) => b.size.compareTo(a.size));
    final catSize = {for (var c in FileCategory.values) c: 0};
    final catCount = {for (var c in FileCategory.values) c: 0};
    final duplicatesMap = <String, List<StorageItem>>{};
    int totalBytes = 0;

    for (final item in files) {
      totalBytes += item.size;
      catSize[item.category] = catSize[item.category]! + item.size;
      catCount[item.category] = catCount[item.category]! + 1;
      if (item.size > 1024 * 50) {
        duplicatesMap
            .putIfAbsent('${item.name}_${item.size}', () => [])
            .add(item);
      }
    }

    List<StorageItem> sortedBySize(bool Function(StorageItem) test) =>
        files.where(test).toList();

    return StorageSummary(
      rootPath: rootPath,
      files: files,
      folders: const [],
      totalSize: totalBytes,
      categorySizeMap: catSize,
      categoryCountMap: catCount,
      dustyItems: sortedBySize((f) => f.isDusty && f.size > 1024 * 1024 * 5),
      largeItems: sortedBySize((f) => f.size >= 100 * 1024 * 1024),
      installerItems: sortedBySize((f) => f.category == FileCategory.installer),
      archiveItems: sortedBySize((f) => f.category == FileCategory.archive),
      duplicateGroups: Map.fromEntries(
        duplicatesMap.entries.where((e) => e.value.length > 1),
      ),
      emptyFolders: emptyFolders,
      rootTree: BentoNode.buildTreeFromItems(rootPath, files),
    );
  }

  /// Drops deleted paths (and anything under a deleted folder) and rebuilds the groupings.
  StorageSummary without(Set<String> deletedPaths) {
    bool gone(String path) => deletedPaths.any(
      (d) => path == d || path.startsWith('$d/') || path.startsWith('$d\\'),
    );
    return StorageSummary.fromFiles(
      rootPath,
      files.where((f) => !gone(f.path)).toList(),
      emptyFolders.where((d) => !gone(d)).toList(),
      presorted: true,
    );
  }

  /// [without] on a background isolate: rebuilding a million-file summary takes ~1s and would freeze the UI.
  Future<StorageSummary> withoutAsync(Set<String> deletedPaths) =>
      files.length < 20000
      ? Future.value(without(deletedPaths))
      : Isolate.run(() => without(deletedPaths));

  static StorageSummary empty() {
    return StorageSummary(
      rootPath: '',
      files: const [],
      folders: const [],
      totalSize: 0,
      categorySizeMap: {for (var c in FileCategory.values) c: 0},
      categoryCountMap: {for (var c in FileCategory.values) c: 0},
      dustyItems: const [],
      largeItems: const [],
      installerItems: const [],
      archiveItems: const [],
      duplicateGroups: const {},
      emptyFolders: const [],
    );
  }

  // Summaries are never mutated after creation, so identity is the right equality.
  // Deep-comparing a million files here cost ~1s per Bloc emit and froze the UI.
  @override
  List<Object?> get props => [identityHashCode(this)];
}
