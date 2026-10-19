import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/system_launcher.dart';
import '../../domain/entities/bento_node.dart';
import '../../domain/entities/file_category.dart';

class BentoTreemapWidget extends StatelessWidget {
  final BentoNode rootNode;
  final ValueChanged<BentoNode>? onNodeTapped;
  final Function(BentoNode node)? onDeleteNode;

  const BentoTreemapWidget({
    super.key,
    required this.rootNode,
    this.onNodeTapped,
    this.onDeleteNode,
  });

  // Smallest tile that still fits icon + name + size without overflow
  static const double minTileWidth = 96;
  static const double minTileHeight = 64;
  static const int maxTiles = 60;
  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    if (rootNode.children.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'No items in ${rootNode.name}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        final totalAreaSize = rootNode.size > 0 ? rootNode.size : 1;
        final visible = fitChildren(rootNode, area);
        final rects = _calculateSquarifiedTreemap(
          visible,
          Offset.zero & area,
          totalAreaSize,
        );

        return Stack(
          children: rects.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final rect = item.rect.deflate(_gap);
            return AnimatedPositioned(
              key: ValueKey(item.node.path),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              left: rect.left,
              top: rect.top,
              width: rect.width.clamp(0.0, double.infinity),
              height: rect.height.clamp(0.0, double.infinity),
              child: _BentoTile(
                node: item.node,
                index: index,
                ratio: item.node.size / totalAreaSize * 100,
                onOpen: () => _open(context, item.node),
                onDelete: onDeleteNode == null || item.node.isGroup
                    ? null
                    : () => onDeleteNode!(item.node),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Keeps the largest children that can get at least a min-size tile; bundles the rest into one group tile.
  static List<BentoNode> fitChildren(BentoNode parent, Size area) {
    final total = parent.size > 0 ? parent.size : 1;
    final pxPerByte = area.width * area.height / total;
    // 1.6x headroom: binary-split tiles are rarely perfectly square
    const minArea = minTileWidth * minTileHeight * 1.6;
    final children = parent.children;

    for (var i = 0; i < children.length; i++) {
      final tooSmall = children[i].size * pxPerByte < minArea;
      if ((tooSmall || i >= maxTiles - 1) && children.length - i > 1) {
        final rest = children.sublist(i);
        return [
          ...children.sublist(0, i),
          BentoNode(
            name: '+${rest.length} smaller items',
            path: '${parent.path}/\u0000group',
            size: rest.fold<int>(0, (s, n) => s + n.size),
            isDirectory: false,
            category: FileCategory.other,
            children: rest,
            itemCount: rest.length,
            isGroup: true,
          ),
        ];
      }
    }
    return children;
  }

  void _open(BuildContext context, BentoNode node) {
    if (node.isGroup) {
      _showGroup(context, node);
    } else if (node.isDirectory && onNodeTapped != null) {
      onNodeTapped!(node);
    } else {
      SystemLauncher.revealInFileManager(node.path);
    }
  }

  void _showGroup(BuildContext context, BentoNode group) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bgSidebar,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(
          '${group.itemCount} smaller items • ${group.formattedSize}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: SizedBox(
          width: 460,
          height: 420,
          child: ListView.builder(
            itemCount: group.children.length,
            itemBuilder: (_, i) {
              final node = group.children[i];
              final color = node.isDirectory
                  ? AppColors.getFolderColor(node.name, i)
                  : node.category.color;
              return ListTile(
                dense: true,
                leading: Icon(
                  node.isDirectory ? Icons.folder_rounded : node.category.icon,
                  color: color,
                  size: 20,
                ),
                title: Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      node.formattedSize,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (onDeleteNode != null)
                      IconButton(
                        tooltip: 'Delete',
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          onDeleteNode!(node);
                        },
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  _open(context, node);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Squarified Treemap layout algorithm (orders by size descending and lays out alternating horizontally and vertically)
  List<_TreemapItem> _calculateSquarifiedTreemap(
    List<BentoNode> nodes,
    Rect containerRect,
    int totalBytes,
  ) {
    if (nodes.isEmpty ||
        totalBytes <= 0 ||
        containerRect.width <= 0 ||
        containerRect.height <= 0) {
      return [];
    }

    final List<_TreemapItem> items = [];
    _layoutRecursive(nodes, containerRect, totalBytes, items, true);
    return items;
  }

  void _layoutRecursive(
    List<BentoNode> nodes,
    Rect rect,
    int totalSize,
    List<_TreemapItem> result,
    bool horizontal,
  ) {
    if (nodes.isEmpty) return;
    if (nodes.length == 1) {
      result.add(_TreemapItem(nodes.first, rect));
      return;
    }

    // Split nodes into two balanced groups by cumulative size
    int halfSize = totalSize ~/ 2;
    int currentSum = 0;
    int splitIndex = 0;

    for (int i = 0; i < nodes.length; i++) {
      currentSum += nodes[i].size;
      if (currentSum >= halfSize || i == nodes.length - 1) {
        splitIndex = i + 1;
        break;
      }
    }

    if (splitIndex <= 0) splitIndex = 1;
    if (splitIndex >= nodes.length) splitIndex = nodes.length - 1;

    final leftGroup = nodes.sublist(0, splitIndex);
    final rightGroup = nodes.sublist(splitIndex);

    final leftSize = leftGroup.fold<int>(0, (s, n) => s + n.size);
    final rightSize = rightGroup.fold<int>(0, (s, n) => s + n.size);
    final ratio = totalSize > 0
        ? (leftSize / totalSize).clamp(0.05, 0.95)
        : 0.5;

    Rect leftRect;
    Rect rightRect;

    // Split along the longer dimension to keep tiles squarish
    final splitHorizontal = rect.width >= rect.height;

    if (splitHorizontal) {
      final leftWidth = rect.width * ratio;
      leftRect = Rect.fromLTWH(rect.left, rect.top, leftWidth, rect.height);
      rightRect = Rect.fromLTWH(
        rect.left + leftWidth,
        rect.top,
        rect.width - leftWidth,
        rect.height,
      );
    } else {
      final topHeight = rect.height * ratio;
      leftRect = Rect.fromLTWH(rect.left, rect.top, rect.width, topHeight);
      rightRect = Rect.fromLTWH(
        rect.left,
        rect.top + topHeight,
        rect.width,
        rect.height - topHeight,
      );
    }

    _layoutRecursive(leftGroup, leftRect, leftSize, result, !splitHorizontal);
    _layoutRecursive(
      rightGroup,
      rightRect,
      rightSize,
      result,
      !splitHorizontal,
    );
  }
}

class _TreemapItem {
  final BentoNode node;
  final Rect rect;
  _TreemapItem(this.node, this.rect);
}

class _BentoTile extends StatefulWidget {
  final BentoNode node;
  final int index;
  final double ratio;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  const _BentoTile({
    required this.node,
    this.index = 0,
    required this.ratio,
    required this.onOpen,
    this.onDelete,
  });

  @override
  State<_BentoTile> createState() => _BentoTileState();
}

class _BentoTileState extends State<_BentoTile> {
  bool _hover = false;

  BentoNode get node => widget.node;

  Color get _color => node.isGroup
      ? AppColors.catOther
      : node.isDirectory
      ? AppColors.getFolderColor(node.name, widget.index)
      : node.category.color;

  IconData get _icon => node.isGroup
      ? Icons.more_horiz_rounded
      : node.isDirectory
      ? Icons.folder_rounded
      : node.category.icon;

  String get _hint => node.isGroup
      ? 'Click to list items'
      : node.isDirectory
      ? 'Click to dive into folder • Right-click for options'
      : 'Click to reveal in Explorer • Right-click for options';

  Future<void> _showMenu(Offset position) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: AppColors.bgSidebar,
      items: [
        PopupMenuItem(
          value: 'open',
          child: _menuRow(
            node.isGroup
                ? Icons.list_rounded
                : (node.isDirectory
                      ? Icons.folder_open_rounded
                      : Icons.search_rounded),
            node.isGroup
                ? 'Show items'
                : (node.isDirectory ? 'Open folder' : 'Reveal in file manager'),
            AppColors.textPrimary,
          ),
        ),
        if (node.isDirectory && !node.isGroup)
          PopupMenuItem(
            value: 'reveal',
            child: _menuRow(
              Icons.search_rounded,
              'Reveal in file manager',
              AppColors.textPrimary,
            ),
          ),
        if (widget.onDelete != null)
          PopupMenuItem(
            value: 'delete',
            child: _menuRow(
              Icons.delete_outline_rounded,
              'Delete…',
              AppColors.danger,
            ),
          ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'open':
        widget.onOpen();
      case 'reveal':
        SystemLauncher.revealInFileManager(node.path);
      case 'delete':
        widget.onDelete?.call();
    }
  }

  Widget _menuRow(IconData icon, String label, Color color) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 13, color: color)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message:
            '${node.name}\n${node.formattedSize} (${widget.ratio.toStringAsFixed(1)}%)'
            '${node.isDirectory ? ' • ${node.itemCount} files' : ''}\n$_hint',
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          onTap: widget.onOpen,
          onSecondaryTapUp: (d) => _showMenu(d.globalPosition),
          child: AnimatedScale(
            scale: _hover ? 1.015 : 1,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: color.withValues(alpha: _hover ? 0.26 : 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: _hover ? 0.95 : 0.55),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: _hover ? 0.25 : 0.06),
                    blurRadius: _hover ? 16 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              // Clip + size-aware content: nothing can overflow however small the tile gets
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (context, c) => _buildContent(c.biggest, color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Size size, Color color) {
    final w = size.width, h = size.height;

    if (w < 34 || h < 26) return const SizedBox.shrink();
    if (w < 80 || h < 58) {
      return Center(child: Icon(_icon, size: 16, color: color));
    }

    final isFull = w >= 140 && h >= 96;
    final pad = isFull ? 12.0 : 8.0;
    final name = Text(
      node.name,
      maxLines: isFull && h >= 120 ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: isFull ? 13 : 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.2,
      ),
    );

    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_icon, size: isFull ? 18 : 14, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(child: name),
              if (node.isDirectory && _hover && isFull) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: color.withValues(alpha: 0.7),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Dive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 10, color: color),
                    ],
                  ),
                ),
              ],
              if (isFull && _hover && widget.onDelete != null)
                InkWell(
                  onTap: widget.onDelete,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
          // Child-name pills only when there is clearly room for them
          if (isFull &&
              h >= 150 &&
              node.isDirectory &&
              node.children.isNotEmpty) ...[
            const SizedBox(height: 8),
            Expanded(
              child: ClipRect(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: node.children.take(4).map((child) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: w - pad * 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          child.name,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ] else
            const Spacer(),
          Row(
            children: [
              Flexible(
                child: Text(
                  node.formattedSize,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isFull ? 14 : 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (isFull) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.ratio < 0.1
                        ? '<0.1%'
                        : '${widget.ratio.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (isFull && node.isDirectory && h >= 110)
            Text(
              '${node.itemCount} files',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}
