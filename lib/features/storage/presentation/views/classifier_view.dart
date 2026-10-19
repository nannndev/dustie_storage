import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../domain/entities/file_category.dart';
import '../../domain/entities/storage_filter.dart';
import '../../domain/entities/storage_item.dart';
import '../bloc/storage_bloc.dart';
import '../bloc/storage_event.dart';
import '../bloc/storage_state.dart';
import '../cubit/storage_filter_cubit.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/file_list_tile.dart';

class ClassifierView extends StatefulWidget {
  const ClassifierView({super.key});

  @override
  State<ClassifierView> createState() => _ClassifierViewState();
}

class _ClassifierViewState extends State<ClassifierView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  final Set<String> _selectedItemPaths = {};

  // Memo: ticking a checkbox calls setState, which must not re-filter a million files
  (StorageFilter, List<StorageItem>, List<StorageItem>, int)? _filterCache;

  (List<StorageItem>, int) _filtered(
    StorageFilterCubit cubit,
    StorageFilter filter,
    List<StorageItem> files,
  ) {
    final c = _filterCache;
    if (c != null && c.$1 == filter && identical(c.$2, files)) {
      return (c.$3, c.$4);
    }
    final items = cubit.applyFilter(files);
    final bytes = items.fold<int>(0, (sum, i) => sum + i.size);
    _filterCache = (filter, files, items, bytes);
    return (items, bytes);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _selectAll(List<StorageItem> currentList) {
    setState(() {
      if (_selectedItemPaths.length == currentList.length) {
        _selectedItemPaths.clear();
      } else {
        _selectedItemPaths.addAll(currentList.map((e) => e.path));
      }
    });
  }

  void _deleteSelected(List<StorageItem> currentList) {
    final itemsToDelete = currentList
        .where((i) => _selectedItemPaths.contains(i.path))
        .toList();
    if (itemsToDelete.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => DeleteConfirmationDialog(
        items: itemsToDelete,
        onConfirm: () {
          context.read<StorageBloc>().add(
            DeleteMultipleItemsRequested(itemsToDelete),
          );
          setState(() {
            _selectedItemPaths.clear();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StorageBloc, StorageState>(
      buildWhen: (a, b) =>
          !identical(a.summary, b.summary) ||
          a.isScanning != b.isScanning ||
          a.currentPath != b.currentPath,
      builder: (context, storageState) {
        return BlocBuilder<StorageFilterCubit, StorageFilter>(
          builder: (context, filterState) {
            final filterCubit = context.read<StorageFilterCubit>();
            final (filteredItems, totalBytesFiltered) = _filtered(
              filterCubit,
              filterState,
              storageState.summary.files,
            );
            final selectedItems = _selectedItemPaths.isEmpty
                ? const <StorageItem>[]
                : filteredItems
                      .where((i) => _selectedItemPaths.contains(i.path))
                      .toList();
            final selectedBytes = selectedItems.fold<int>(
              0,
              (sum, i) => sum + i.size,
            );

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter Bar Row 1: Search + Dropdowns
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _searchController,
                            // Debounced: each search scans every path, so don't run it per keystroke
                            onChanged: (val) {
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 300),
                                () => filterCubit.setSearchQuery(val),
                              );
                            },
                            decoration: InputDecoration(
                              hintText:
                                  'Search files by name or extension (.mp4, cache, backup)...',
                              hintStyle: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        filterCubit.setSearchQuery('');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: AppColors.bgSidebar,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        _buildSizeFilterDropdown(filterState, filterCubit),
                        const SizedBox(width: 12),
                        _buildAgeFilterDropdown(filterState, filterCubit),
                        const SizedBox(width: 12),
                        _buildSortDropdown(filterState, filterCubit),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Category Filter Badges
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryChip(
                            'All Types',
                            null,
                            Icons.apps_rounded,
                            AppColors.primaryLight,
                            filterState,
                            filterCubit,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: filterState.showHiddenOnly,
                              showCheckmark: false,
                              avatar: Icon(
                                Icons.visibility_off_rounded,
                                size: 16,
                                color: filterState.showHiddenOnly
                                    ? AppColors.textPrimary
                                    : AppColors.catArchive,
                              ),
                              label: const Text('👻 Hidden Files'),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: filterState.showHiddenOnly
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: filterState.showHiddenOnly
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              backgroundColor: AppColors.bgSidebar,
                              selectedColor: AppColors.catArchive.withValues(
                                alpha: 0.35,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: filterState.showHiddenOnly
                                      ? AppColors.catArchive
                                      : AppColors.border,
                                ),
                              ),
                              onSelected: (_) => filterCubit.toggleHiddenOnly(),
                            ),
                          ),
                          ...FileCategory.values.map(
                            (cat) => _buildCategoryChip(
                              cat.label,
                              cat,
                              cat.icon,
                              cat.color,
                              filterState,
                              filterCubit,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Summary & Batch Actions Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgSidebar,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value:
                                filteredItems.isNotEmpty &&
                                _selectedItemPaths.length ==
                                    filteredItems.length,
                            tristate:
                                _selectedItemPaths.isNotEmpty &&
                                _selectedItemPaths.length <
                                    filteredItems.length,
                            onChanged: (val) => _selectAll(filteredItems),
                            activeColor: AppColors.primary,
                            side: BorderSide(
                              color: AppColors.borderLight,
                              width: 1.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${filteredItems.length} items',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${FileSizeFormatter.format(totalBytesFiltered)})',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedItemPaths.isNotEmpty) ...[
                            Text(
                              'Selected: ${_selectedItemPaths.length} (${FileSizeFormatter.format(selectedBytes)})',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            const SizedBox(width: 14),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _deleteSelected(filteredItems),
                              icon: const Icon(
                                Icons.delete_sweep_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Delete Selected',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // File List
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.filter_list_off_rounded,
                                    size: 48,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No files match your current filters',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextButton(
                                    onPressed: () {
                                      filterCubit.resetFilters();
                                      _searchController.clear();
                                    },
                                    child: Text(
                                      'Reset All Filters',
                                      style: TextStyle(
                                        color: AppColors.primaryLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final isSelected = _selectedItemPaths.contains(
                                  item.path,
                                );

                                return FileListTile(
                                  item: item,
                                  isSelected: isSelected,
                                  onSelectChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedItemPaths.add(item.path);
                                      } else {
                                        _selectedItemPaths.remove(item.path);
                                      }
                                    });
                                  },
                                  onDelete: () {
                                    showDialog(
                                      context: context,
                                      builder: (dialogCtx) =>
                                          DeleteConfirmationDialog(
                                            items: [item],
                                            onConfirm: () =>
                                                context.read<StorageBloc>().add(
                                                  DeleteSingleItemRequested(
                                                    item,
                                                  ),
                                                ),
                                          ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryChip(
    String label,
    FileCategory? category,
    IconData icon,
    Color color,
    StorageFilter filterState,
    StorageFilterCubit cubit,
  ) {
    final isSelected = filterState.category == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 16,
          color: isSelected ? AppColors.textPrimary : color,
        ),
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
        ),
        backgroundColor: AppColors.bgSidebar,
        selectedColor: color.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isSelected ? color : AppColors.border),
        ),
        onSelected: (_) => cubit.setCategory(category),
      ),
    );
  }

  Widget _buildSizeFilterDropdown(
    StorageFilter filterState,
    StorageFilterCubit cubit,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSidebar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: filterState.minSizeBytes,
          dropdownColor: AppColors.bgSidebar,
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: AppColors.textSecondary,
          ),
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Size: Any')),
            DropdownMenuItem(value: 10 * 1024 * 1024, child: Text('> 10 MB')),
            DropdownMenuItem(value: 50 * 1024 * 1024, child: Text('> 50 MB')),
            DropdownMenuItem(value: 100 * 1024 * 1024, child: Text('> 100 MB')),
            DropdownMenuItem(value: 500 * 1024 * 1024, child: Text('> 500 MB')),
            DropdownMenuItem(value: 1024 * 1024 * 1024, child: Text('> 1 GB')),
          ],
          onChanged: (val) {
            if (val != null) cubit.setMinSizeBytes(val);
          },
        ),
      ),
    );
  }

  Widget _buildAgeFilterDropdown(
    StorageFilter filterState,
    StorageFilterCubit cubit,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSidebar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: filterState.minAgeDays,
          dropdownColor: AppColors.bgSidebar,
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: AppColors.textSecondary,
          ),
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('Age: Any Time')),
            DropdownMenuItem(value: 30, child: Text('> 30 days old')),
            DropdownMenuItem(value: 90, child: Text('> 3 months old')),
            DropdownMenuItem(value: 180, child: Text('🧹 Dusty (> 6 mos)')),
            DropdownMenuItem(value: 365, child: Text('> 1 year old')),
          ],
          onChanged: (val) => cubit.setMinAgeDays(val),
        ),
      ),
    );
  }

  Widget _buildSortDropdown(
    StorageFilter filterState,
    StorageFilterCubit cubit,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSidebar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SortOption>(
          value: filterState.sortOption,
          dropdownColor: AppColors.bgSidebar,
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: AppColors.textSecondary,
          ),
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: SortOption.values.map((opt) {
            return DropdownMenuItem(value: opt, child: Text(opt.label));
          }).toList(),
          onChanged: (val) {
            if (val != null) cubit.setSortOption(val);
          },
        ),
      ),
    );
  }
}
