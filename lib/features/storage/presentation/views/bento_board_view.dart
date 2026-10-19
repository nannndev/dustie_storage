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
  bool _isDrillingDeeper = true;
  final ScrollController _breadcrumbScrollCtrl = ScrollController();

  // Memo: hover/mode-switch setState must not rebuild a tree over a million files
  (String, List<StorageItem>, BentoNode)? _treeCache;

  @override
  void dispose() {
    _breadcrumbScrollCtrl.dispose();
    super.dispose();
  }

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
        _isDrillingDeeper = true;
        _navigationStack.add(node);
      });
      _scrollToDeepestBreadcrumb();
    }
  }

  void _navigateBack() {
    if (_navigationStack.isNotEmpty) {
      setState(() {
        _isDrillingDeeper = false;
        _navigationStack.removeLast();
      });
      _scrollToDeepestBreadcrumb();
    }
  }

  void _navigateToIndex(int index) {
    setState(() {
      _isDrillingDeeper = false;
      while (_navigationStack.length > index + 1) {
        _navigationStack.removeLast();
      }
    });
    _scrollToDeepestBreadcrumb();
  }

  void _navigateToRoot() {
    setState(() {
      _isDrillingDeeper = false;
      _navigationStack.clear();
    });
    _scrollToDeepestBreadcrumb();
  }

  void _scrollToDeepestBreadcrumb() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_breadcrumbScrollCtrl.hasClients) {
        _breadcrumbScrollCtrl.animateTo(
          _breadcrumbScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
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
            : _navigationStack.isNotEmpty
            ? 'Menyelam ke folder "${currentNode.name}" (${currentNode.children.length} item • ${currentNode.formattedSize})! 🤿✨'
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
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgSidebar,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            if (_navigationStack.isNotEmpty) ...[
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _navigateBack,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.arrow_upward_rounded,
                                          size: 14,
                                          color: AppColors.primaryLight,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Up',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _breadcrumbScrollCtrl,
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildBreadcrumbPill(
                                      label: 'Root',
                                      icon: Icons.home_rounded,
                                      isCurrent: _navigationStack.isEmpty,
                                      onTap: _navigationStack.isEmpty
                                          ? null
                                          : _navigateToRoot,
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Icon(
                                              Icons.chevron_right_rounded,
                                              size: 16,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                          _buildBreadcrumbPill(
                                            label: node.name,
                                            icon: Icons.folder_rounded,
                                            isCurrent: isLast,
                                            folderColor:
                                                AppColors.getFolderColor(
                                                  node.name,
                                                  idx,
                                                ),
                                            onTap: isLast
                                                ? null
                                                : () => _navigateToIndex(idx),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgCard,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                '${currentNode.children.length} items • ${currentNode.formattedSize}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
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
                                    state.isScanning
                                        ? 'Menganalisis file...'
                                        : 'Scan folder untuk melihat Bento Board!',
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
                          ? AnimatedSwitcher(
                              duration: const Duration(milliseconds: 320),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                );
                              },
                              transitionBuilder: (child, animation) {
                                final isIncoming =
                                    (child.key as ValueKey<String>?)?.value ==
                                    currentNode.path;
                                final beginScale = _isDrillingDeeper
                                    ? (isIncoming ? 0.90 : 1.10)
                                    : (isIncoming ? 1.10 : 0.90);

                                final scaleAnim =
                                    Tween<double>(
                                      begin: beginScale,
                                      end: 1.0,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: isIncoming
                                            ? Curves.easeOutCubic
                                            : Curves.easeInCubic,
                                      ),
                                    );

                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: scaleAnim,
                                    child: child,
                                  ),
                                );
                              },
                              child: KeyedSubtree(
                                key: ValueKey(currentNode.path),
                                child: BentoTreemapWidget(
                                  rootNode: currentNode,
                                  onNodeTapped: _drillDown,
                                  onDeleteNode: (node) =>
                                      _confirmDelete(context, node, allFiles),
                                ),
                              ),
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

  Widget _buildBreadcrumbPill({
    required String label,
    required IconData icon,
    required bool isCurrent,
    Color? folderColor,
    VoidCallback? onTap,
  }) {
    final activeColor = folderColor ?? AppColors.primary;
    final textColor = isCurrent
        ? (folderColor ?? AppColors.primaryLight)
        : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isCurrent
                ? activeColor.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrent
                  ? activeColor.withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
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
