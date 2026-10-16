import 'package:equatable/equatable.dart';

import '../../../../core/utils/file_size_formatter.dart';
import 'file_category.dart';
import 'storage_item.dart';

class BentoNode extends Equatable {
  final String name;
  final String path;
  final int size;
  final bool isDirectory;
  final FileCategory category;
  final List<BentoNode> children;
  final int itemCount;

  /// Synthetic tile bundling items too small to render legibly; not a real path on disk.
  final bool isGroup;

  const BentoNode({
    required this.name,
    required this.path,
    required this.size,
    required this.isDirectory,
    required this.category,
    this.children = const [],
    this.itemCount = 1,
    this.isGroup = false,
  });

  String get formattedSize => FileSizeFormatter.format(size);

  /// [depth] limits recursion: the board only shows one level (+ child names), and drill-down rebuilds from the path.
  static BentoNode buildTreeFromItems(
    String rootPath,
    List<StorageItem> items, {
    int depth = 2,
  }) {
    if (items.isEmpty) {
      return BentoNode(
        name: rootPath.isEmpty ? 'Root' : rootPath.split('/').last,
        path: rootPath,
        size: 0,
        isDirectory: true,
        category: FileCategory.other,
      );
    }

    // Map direct children under current rootPath
    final Map<String, List<StorageItem>> directChildrenItems = {};
    final List<StorageItem> directFiles = [];

    final normalizedRoot = rootPath.endsWith('/') ? rootPath : '$rootPath/';

    for (final item in items) {
      if (!item.path.startsWith(normalizedRoot) && item.path != rootPath) {
        continue;
      }

      // indexOf instead of split: avoids allocating every path segment for a million files
      final slash = item.path.indexOf('/', normalizedRoot.length);
      if (slash < 0) {
        // Direct file under this folder
        directFiles.add(item);
      } else {
        // Belongs to a subfolder
        final subfolderName = item.path.substring(normalizedRoot.length, slash);
        directChildrenItems.putIfAbsent(subfolderName, () => []).add(item);
      }
    }

    final List<BentoNode> children = [];

    // Add subfolders recursively
    for (final entry in directChildrenItems.entries) {
      final subfolderName = entry.key;
      final subItems = entry.value;
      final subPath = '$normalizedRoot$subfolderName';
      final totalSubSize = subItems.fold<int>(0, (s, i) => s + i.size);

      // Recursive nested node
      final subTree = depth > 1
          ? buildTreeFromItems(subPath, subItems, depth: depth - 1)
          : null;

      children.add(
        BentoNode(
          name: subfolderName,
          path: subPath,
          size: totalSubSize,
          isDirectory: true,
          category: FileCategory.other,
          children: subTree?.children ?? const [],
          itemCount: subItems.length,
        ),
      );
    }

    // Add direct files
    for (final file in directFiles) {
      children.add(
        BentoNode(
          name: file.name,
          path: file.path,
          size: file.size,
          isDirectory: false,
          category: file.category,
          children: const [],
          itemCount: 1,
        ),
      );
    }

    // Sort children strictly from LARGEST to SMALLEST
    children.sort((a, b) => b.size.compareTo(a.size));

    final totalSize = items.fold<int>(0, (s, i) => s + i.size);
    final rootName = rootPath.isEmpty
        ? 'Root'
        : rootPath.split('/').where((s) => s.isNotEmpty).last;

    return BentoNode(
      name: rootName,
      path: rootPath,
      size: totalSize,
      isDirectory: true,
      category: FileCategory.other,
      children: children,
      itemCount: items.length,
    );
  }

  @override
  List<Object?> get props => [
    name,
    path,
    size,
    isDirectory,
    category,
    children,
    itemCount,
    isGroup,
  ];
}
