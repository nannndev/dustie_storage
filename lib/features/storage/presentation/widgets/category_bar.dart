import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../domain/entities/file_category.dart';

class CategoryBar extends StatelessWidget {
  final Map<FileCategory, int> categorySizeMap;
  final int totalSize;
  final FileCategory? selectedCategory;
  final ValueChanged<FileCategory?> onCategoryToggled;

  const CategoryBar({
    super.key,
    required this.categorySizeMap,
    required this.totalSize,
    this.selectedCategory,
    required this.onCategoryToggled,
  });

  @override
  Widget build(BuildContext context) {
    // Sort active categories by size descending to match donut chart ordering
    final sortedEntries =
        categorySizeMap.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    // Sort category badges by size descending as well
    final sortedCategories = FileCategory.values.toList()
      ..sort(
        (a, b) => (categorySizeMap[b] ?? 0).compareTo(categorySizeMap[a] ?? 0),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Multi-color Segmented Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 14,
            color: AppColors.border,
            child: totalSize == 0
                ? const SizedBox.shrink()
                : Row(
                    children: sortedEntries.map((entry) {
                      final ratio = entry.value / totalSize;
                      if (ratio <= 0.001) return const SizedBox.shrink();
                      final isSelected =
                          selectedCategory == null ||
                          selectedCategory == entry.key;

                      return Expanded(
                        flex: (ratio * 1000).toInt().clamp(1, 1000),
                        child: Tooltip(
                          message:
                              '${entry.key.emoji} ${entry.key.label}: ${FileSizeFormatter.format(entry.value)} (${(ratio * 100).toStringAsFixed(1)}%)',
                          child: InkWell(
                            onTap: () => onCategoryToggled(
                              selectedCategory == entry.key ? null : entry.key,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              color: isSelected
                                  ? entry.key.color
                                  : entry.key.color.withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        // Badges Grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sortedCategories.map((cat) {
            final size = categorySizeMap[cat] ?? 0;
            final isSelected = selectedCategory == cat;

            return InkWell(
              onTap: () => onCategoryToggled(isSelected ? null : cat),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cat.color.withValues(alpha: 0.28)
                      : cat.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? cat.color
                        : cat.color.withValues(alpha: 0.25),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cat.color.withValues(alpha: 0.3)
                            : (size > 0
                                  ? cat.color.withValues(alpha: 0.14)
                                  : AppColors.bgCardHover),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        FileSizeFormatter.format(size),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: size > 0 ? cat.color : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
