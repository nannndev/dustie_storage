import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../domain/entities/storage_item.dart';
import '../bloc/storage_bloc.dart';
import '../bloc/storage_event.dart';
import '../bloc/storage_state.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/file_list_tile.dart';

class DuplicatesView extends StatefulWidget {
  const DuplicatesView({super.key});

  @override
  State<DuplicatesView> createState() => _DuplicatesViewState();
}

class _DuplicatesViewState extends State<DuplicatesView> {
  final Set<String> _selectedDuplicatePaths = {};

  void _autoSelectDuplicates(Map<String, List<StorageItem>> duplicateGroups) {
    setState(() {
      _selectedDuplicatePaths.clear();
      for (final group in duplicateGroups.values) {
        if (group.length > 1) {
          for (int i = 1; i < group.length; i++) {
            _selectedDuplicatePaths.add(group[i].path);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StorageBloc, StorageState>(
      builder: (context, state) {
        final groups = state.summary.duplicateGroups;
        final totalWastedBytes = groups.values.fold<int>(0, (sum, list) {
          if (list.length <= 1) return sum;
          return sum + (list.first.size * (list.length - 1));
        });

        final selectedItems = groups.values
            .expand((list) => list)
            .where((item) => _selectedDuplicatePaths.contains(item.path))
            .toList();
        final selectedBytes = selectedItems.fold<int>(0, (s, i) => s + i.size);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Stats & Auto-Select
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgSidebar,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.catImage.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.copy_rounded, color: AppColors.catImage, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${groups.length} Duplicate Groups Found',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Estimated wasted storage: ${FileSizeFormatter.format(totalWastedBytes)}',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (groups.isNotEmpty) ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primary),
                            foregroundColor: AppColors.primaryLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _autoSelectDuplicates(groups),
                          icon: const Icon(Icons.checklist_rounded, size: 18),
                          label: const Text('Auto-Select Clones'),
                        ),
                        const SizedBox(width: 12),
                        if (_selectedDuplicatePaths.isNotEmpty)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (dialogCtx) => DeleteConfirmationDialog(
                                  items: selectedItems,
                                  onConfirm: () {
                                    context.read<StorageBloc>().add(DeleteMultipleItemsRequested(selectedItems));
                                    setState(() => _selectedDuplicatePaths.clear());
                                  },
                                ),
                              );
                            },
                            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                            label: Text('Delete Selected (${FileSizeFormatter.format(selectedBytes)})'),
                          ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (groups.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(48),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.bgSidebar,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.thumb_up_alt_rounded, size: 48, color: AppColors.success),
                        const SizedBox(height: 14),
                        Text(
                          state.isScanning ? 'Checking for duplicates...' : 'No duplicate files detected in this scan!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All your files appear to be unique copies.',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final entry = groups.entries.elementAt(index);
                      final fileList = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSidebar,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    fileList.first.name,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgCardHover,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${fileList.length} copies • ${fileList.first.formattedSize} each',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...fileList.asMap().entries.map((itemEntry) {
                              final i = itemEntry.key;
                              final item = itemEntry.value;
                              final isSelected = _selectedDuplicatePaths.contains(item.path);

                              return Stack(
                                children: [
                                  FileListTile(
                                    item: item,
                                    isSelected: isSelected,
                                    onSelectChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedDuplicatePaths.add(item.path);
                                        } else {
                                          _selectedDuplicatePaths.remove(item.path);
                                        }
                                      });
                                    },
                                  ),
                                  if (i == 0)
                                    Positioned(
                                      top: 14,
                                      right: 90,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Original',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
