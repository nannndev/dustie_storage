import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../domain/entities/storage_item.dart';
import 'delete_confirmation_dialog.dart';
import 'file_list_tile.dart';

class SizeTierBoardWidget extends StatelessWidget {
  final List<StorageItem> allFiles;
  final Function(StorageItem item) onDeleteItem;
  final Function(List<StorageItem> items) onDeleteItems;

  const SizeTierBoardWidget({
    super.key,
    required this.allFiles,
    required this.onDeleteItem,
    required this.onDeleteItems,
  });

  @override
  Widget build(BuildContext context) {
    final titanFiles = allFiles.where((f) => f.size >= 1024 * 1024 * 1024).toList()
      ..sort((a, b) => b.size.compareTo(a.size));

    final heavyFiles = allFiles.where((f) => f.size >= 500 * 1024 * 1024 && f.size < 1024 * 1024 * 1024).toList()
      ..sort((a, b) => b.size.compareTo(a.size));

    final moderateFiles = allFiles.where((f) => f.size >= 100 * 1024 * 1024 && f.size < 500 * 1024 * 1024).toList()
      ..sort((a, b) => b.size.compareTo(a.size));

    final featherFiles = allFiles.where((f) => f.size < 100 * 1024 * 1024).toList()
      ..sort((a, b) => b.size.compareTo(a.size));

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate dynamic column width: at least 260px each
        final colWidth = ((constraints.maxWidth - 42) / 4).clamp(260.0, 420.0);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: colWidth,
                  child: _buildTierColumn(context, '🐋 Titan (> 1 GB)', titanFiles, AppColors.tierTitan),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: colWidth,
                  child: _buildTierColumn(context, '🦣 Heavy (500MB - 1GB)', heavyFiles, AppColors.tierHeavy),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: colWidth,
                  child: _buildTierColumn(context, '🦊 Moderate (100 - 500MB)', moderateFiles, AppColors.tierModerate),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: colWidth,
                  child: _buildTierColumn(context, '🐣 Feather (< 100MB)', featherFiles, AppColors.tierFeather),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTierColumn(BuildContext context, String title, List<StorageItem> files, Color color) {
    final totalBytes = files.fold<int>(0, (s, i) => s + i.size);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSidebar,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  FileSizeFormatter.format(totalBytes),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${files.length} items',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              if (files.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.danger,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => DeleteConfirmationDialog(
                        items: files,
                        onConfirm: () => onDeleteItems(files),
                      ),
                    );
                  },
                  child: const Text('Clean All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // File List
          if (files.isEmpty)
            Container(
              height: 380,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('✨', style: TextStyle(fontSize: 28)),
                  SizedBox(height: 8),
                  Text(
                    'No files in this tier!',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 440,
              child: ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final item = files[index];
                  return FileListTile(
                    item: item,
                    isCompact: true, // Compact mode fixes any horizontal overflow!
                    onDelete: () {
                      showDialog(
                        context: context,
                        builder: (dialogCtx) => DeleteConfirmationDialog(
                          items: [item],
                          onConfirm: () => onDeleteItem(item),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
