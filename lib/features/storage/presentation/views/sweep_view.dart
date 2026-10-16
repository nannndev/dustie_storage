import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../domain/entities/storage_item.dart';
import '../bloc/storage_bloc.dart';
import '../bloc/storage_event.dart';
import '../bloc/storage_state.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/dustie_mascot.dart';
import '../widgets/file_list_tile.dart';

class SweepView extends StatefulWidget {
  const SweepView({super.key});

  @override
  State<SweepView> createState() => _SweepViewState();
}

class _SweepViewState extends State<SweepView> {
  int _activeSweepIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StorageBloc, StorageState>(
      builder: (context, state) {
        final result = state.summary;

        final dusty = result.dustyItems;
        final installers = result.installerItems;
        final archives = result.archiveItems;
        final emptyFolders = result.emptyFolders;

        final dustyBytes = dusty.fold<int>(0, (s, i) => s + i.size);
        final installerBytes = installers.fold<int>(0, (s, i) => s + i.size);
        final archiveBytes = archives.fold<int>(0, (s, i) => s + i.size);

        final totalReclaimable = dustyBytes + installerBytes + archiveBytes;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner with Dustie Mascot
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryDark.withValues(alpha: 0.5),
                      AppColors.bgSidebar,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const DustieMascot(
                      size: 72,
                      mood: DustieMood.happy,
                      animate: true,
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dustie Smart Sweep',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Dustie found ${FileSizeFormatter.format(totalReclaimable)} of clutter that can be safely reviewed and cleaned to free up valuable storage.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Preset Selection Tabs
              Row(
                children: [
                  _buildPresetCard(
                    index: 0,
                    title: 'Dusty Files',
                    count: '${dusty.length} files',
                    size: FileSizeFormatter.format(dustyBytes),
                    icon: Icons.auto_delete_rounded,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 14),
                  _buildPresetCard(
                    index: 1,
                    title: 'Installers',
                    count: '${installers.length} packages',
                    size: FileSizeFormatter.format(installerBytes),
                    icon: Icons.install_desktop_rounded,
                    color: AppColors.catInstaller,
                  ),
                  const SizedBox(width: 14),
                  _buildPresetCard(
                    index: 2,
                    title: 'Old Archives',
                    count: '${archives.length} zips',
                    size: FileSizeFormatter.format(archiveBytes),
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.catArchive,
                  ),
                  const SizedBox(width: 14),
                  _buildPresetCard(
                    index: 3,
                    title: 'Empty Folders',
                    count: '${emptyFolders.length} folders',
                    size: '0 B (clutter)',
                    icon: Icons.folder_delete_rounded,
                    color: AppColors.catCode,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Content for Selected Preset
              _buildActiveCategoryContent(context, dusty, installers, archives, emptyFolders),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetCard({
    required int index,
    required String title,
    required String count,
    required String size,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _activeSweepIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeSweepIndex = index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.14) : AppColors.bgSidebar,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.25) : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      size,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                count,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCategoryContent(
    BuildContext context,
    List<StorageItem> dusty,
    List<StorageItem> installers,
    List<StorageItem> archives,
    List<String> emptyFolders,
  ) {
    if (_activeSweepIndex == 0) {
      return _buildItemListSection(
        context: context,
        title: 'Dusty Files (> 6 months untouched & > 5MB)',
        items: dusty,
        emptyMessage: 'No dusty files found! Your drive is clean.',
      );
    } else if (_activeSweepIndex == 1) {
      return _buildItemListSection(
        context: context,
        title: 'Leftover Installers (.dmg, .pkg, .exe, .deb, etc.)',
        items: installers,
        emptyMessage: 'No leftover installers found!',
      );
    } else if (_activeSweepIndex == 2) {
      return _buildItemListSection(
        context: context,
        title: 'Archives & Zip Files (.zip, .tar, .gz, etc.)',
        items: archives,
        emptyMessage: 'No forgotten archives found!',
      );
    } else {
      return _buildEmptyFoldersSection(context, emptyFolders);
    }
  }

  Widget _buildItemListSection({
    required BuildContext context,
    required String title,
    required List<StorageItem> items,
    required String emptyMessage,
  }) {
    final totalBytes = items.fold<int>(0, (s, i) => s + i.size);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            if (items.isNotEmpty)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => DeleteConfirmationDialog(
                      items: items,
                      onConfirm: () => context.read<StorageBloc>().add(DeleteMultipleItemsRequested(items)),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: Text('Clean All (${FileSizeFormatter.format(totalBytes)})'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.bgSidebar,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 44, color: AppColors.success),
                const SizedBox(height: 12),
                Text(
                  emptyMessage,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return FileListTile(
                item: item,
                onDelete: () {
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => DeleteConfirmationDialog(
                      items: [item],
                      onConfirm: () => context.read<StorageBloc>().add(DeleteSingleItemRequested(item)),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmptyFoldersSection(BuildContext context, List<String> emptyDirs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Empty Folders (Ghost Directories)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            if (emptyDirs.isNotEmpty)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => context.read<StorageBloc>().add(DeleteEmptyDirectoriesRequested(emptyDirs)),
                icon: const Icon(Icons.folder_delete_rounded, size: 18),
                label: Text('Delete All (${emptyDirs.length} folders)'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (emptyDirs.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.bgSidebar,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 44, color: AppColors.success),
                SizedBox(height: 12),
                Text(
                  'No empty folders found!',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: emptyDirs.length,
            itemBuilder: (context, index) {
              final dir = emptyDirs[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined, color: AppColors.catCode, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dir,
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: AppColors.danger,
                      onPressed: () => context.read<StorageBloc>().add(DeleteEmptyDirectoriesRequested([dir])),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
