import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/bento_node.dart';
import '../../domain/entities/storage_item.dart';
import '../bloc/storage_bloc.dart';
import '../bloc/storage_event.dart';
import '../bloc/storage_state.dart';
import '../widgets/bento_treemap_widget.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/dustie_mascot.dart';
import '../widgets/dustie_speech_bubble.dart';
import '../widgets/size_tier_board_widget.dart';

class BentoBoardView extends StatefulWidget {
  const BentoBoardView({super.key});

  @override
  State<BentoBoardView> createState() => _BentoBoardViewState();
}

class _BentoBoardViewState extends State<BentoBoardView> {
  int _boardModeIndex = 0; // 0: Nested Bento Treemap, 1: Size Tiers
  final List<BentoNode> _navigationStack = [];

  // Memo: hover/mode-switch setState must not rebuild a tree over a million files
  (String, List<StorageItem>, BentoNode)? _treeCache;

  BentoNode _treeFor(String path, List<StorageItem> files) {
    final c = _treeCache;
    if (c != null && c.$1 == path && identical(c.$2, files)) return c.$3;
    final tree = BentoNode.buildTreeFromItems(path, files);
    _treeCache = (path, files, tree);
    return tree;
  }

  void _drillDown(BentoNode node) {
    if (node.isDirectory) {
      setState(() {
        _navigationStack.add(node);
      });
    }
  }

  void _navigateBack() {
    if (_navigationStack.isNotEmpty) {
      setState(() {
        _navigationStack.removeLast();
      });
    }
  }

  void _navigateToIndex(int index) {
    setState(() {
      while (_navigationStack.length > index + 1) {
        _navigationStack.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StorageBloc, StorageState>(
      buildWhen: (a, b) =>
          !identical(a.summary, b.summary) ||
          a.isScanning != b.isScanning ||
          a.currentPath != b.currentPath,
      builder: (context, state) {
        final allFiles = state.summary.files;

        // Stack holds snapshots; rebuild the current level from fresh data so deletes and rescans show up
        final currentNode = _navigationStack.isEmpty
            ? state.summary.rootTree ?? _treeFor(state.currentPath, allFiles)
            : _treeFor(_navigationStack.last.path, allFiles);

        // Dynamic cartoon speech bubble message
        final largestItem = allFiles.isEmpty ? null : allFiles.first;

        final speechText = state.isScanning
            ? 'Sedang mengendus file di drive kamu... 🔍'
            : largestItem != null
            ? 'Nyam! File paling raksasa di sini adalah "${largestItem.name}" (${largestItem.formattedSize})!'
            : 'Pilih folder atau drive untuk mulai visualisasi!';

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 760;
              return Padding(
                padding: EdgeInsets.all(isNarrow ? 14 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Dustie & Speech Bubble
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        DustieMascot(
                          size: isNarrow ? 36 : 48,
                          mood: DustieMood.happy,
                          animate: true,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: DustieSpeechBubble(message: speechText),
                        ),
                        SizedBox(width: isNarrow ? 10 : 20),

                        // Mode Switcher (Bento Treemap vs Size Tiers)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.bgSidebar,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildModePill(
                                0,
                                '🍱 Bento Treemap',
                                Icons.dashboard_customize_rounded,
                                iconOnly: isNarrow,
                              ),
                              const SizedBox(width: 4),
                              _buildModePill(
                                1,
                                '📊 Size Tiers',
                                Icons.view_column_rounded,
                                iconOnly: isNarrow,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Treemap Breadcrumbs (When in Treemap mode)
                    if (_boardModeIndex == 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgSidebar,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            if (_navigationStack.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_back_rounded,
                                  size: 18,
                                  color: AppColors.primaryLight,
                                ),
                                tooltip: 'Go Up One Level',
                                onPressed: _navigateBack,
                              ),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse:
                                    true, // keep the deepest folder visible
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () => setState(
                                        () => _navigationStack.clear(),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.home_rounded,
                                            size: 16,
                                            color: AppColors.primaryLight,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Root',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ..._navigationStack.asMap().entries.map((
                                      entry,
                                    ) {
                                      final idx = entry.key;
                                      final node = entry.value;
                                      final isLast =
                                          idx == _navigationStack.length - 1;

                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            child: Text(
                                              '/',
                                              style: TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: isLast
                                                ? null
                                                : () => _navigateToIndex(idx),
                                            child: Text(
                                              node.name,
                                              style: TextStyle(
                                                fontWeight: isLast
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: isLast
                                                    ? AppColors.primaryLight
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${currentNode.children.length} items • ${currentNode.formattedSize}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Main Content (Treemap or Tier Board)
                    Expanded(
                      child: allFiles.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '✨',
                                    style: TextStyle(fontSize: 48),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    state.isScanning ? 'Menganalisis file...' : 'Scan folder untuk melihat Bento Board!',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _boardModeIndex == 0
                          ? BentoTreemapWidget(
                              rootNode: currentNode,
                              onNodeTapped: _drillDown,
                              onDeleteNode: (node) =>
                                  _confirmDelete(context, node, allFiles),
                            )
                          : SizeTierBoardWidget(
                              allFiles: allFiles,
                              onDeleteItem: (item) {
                                context.read<StorageBloc>().add(
                                  DeleteSingleItemRequested(item),
                                );
                              },
                              onDeleteItems: (items) {
                                context.read<StorageBloc>().add(
                                  DeleteMultipleItemsRequested(items),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    BentoNode node,
    List<StorageItem> allFiles,
  ) {
    final item = StorageItem(
      path: node.path,
      name: node.name,
      size: node.size,
      isDirectory: node.isDirectory,
      modified: DateTime.now(),
      extension: node.isDirectory
          ? ''
          : (node.name.contains('.') ? '.${node.name.split('.').last}' : ''),
      category: node.category,
      childCount: node.itemCount,
    );
    showDialog(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        items: [item],
        onConfirm: () =>
            context.read<StorageBloc>().add(DeleteSingleItemRequested(item)),
      ),
    );
  }

  Widget _buildModePill(
    int index,
    String label,
    IconData icon, {
    bool iconOnly = false,
  }) {
    final isSelected = _boardModeIndex == index;

    return InkWell(
      onTap: () => setState(() => _boardModeIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Tooltip(
              message: iconOnly ? label : '',
              child: Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.onPrimary
                    : AppColors.textSecondary,
              ),
            ),
            if (!iconOnly) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.onPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
