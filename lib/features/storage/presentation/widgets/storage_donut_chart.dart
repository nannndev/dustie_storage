import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../domain/entities/file_category.dart';

class StorageDonutChart extends StatelessWidget {
  final Map<FileCategory, int> categorySizeMap;
  final int totalSize;
  final int totalFiles;
  final FileCategory? selectedCategory;
  final ValueChanged<FileCategory?>? onCategorySelected;
  final double size;

  const StorageDonutChart({
    super.key,
    required this.categorySizeMap,
    required this.totalSize,
    required this.totalFiles,
    this.selectedCategory,
    this.onCategorySelected,
    this.size = 230,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutChartPainter(
              categorySizeMap: categorySizeMap,
              totalSize: totalSize,
              selectedCategory: selectedCategory,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedCategory != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: selectedCategory!.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selectedCategory!.color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(selectedCategory!.emoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        selectedCategory!.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selectedCategory!.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  'Total Space',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                selectedCategory != null
                    ? FileSizeFormatter.format(categorySizeMap[selectedCategory] ?? 0)
                    : FileSizeFormatter.format(totalSize),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: selectedCategory != null ? selectedCategory!.color : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                selectedCategory != null && totalSize > 0
                    ? '${(((categorySizeMap[selectedCategory] ?? 0) / totalSize) * 100).toStringAsFixed(1)}% of total'
                    : '$totalFiles files',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final Map<FileCategory, int> categorySizeMap;
  final int totalSize;
  final FileCategory? selectedCategory;

  _DonutChartPainter({
    required this.categorySizeMap,
    required this.totalSize,
    this.selectedCategory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const strokeWidth = 22.0;

    final trackPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (totalSize <= 0) return;

    double startAngle = -math.pi / 2;
    const gapAngle = 0.04;

    // Sort categories by size descending so biggest slices come first
    final sortedEntries = categorySizeMap.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEntries) {
      final category = entry.key;
      final bytes = entry.value;
      if (bytes <= 0) continue;

      final sweepAngle = (bytes / totalSize) * (2 * math.pi) - gapAngle;
      if (sweepAngle <= 0.005) continue;

      final isSelected = selectedCategory == null || selectedCategory == category;
      final currentStroke = isSelected ? strokeWidth + 4 : strokeWidth - 4;

      final paint = Paint()
        ..color = isSelected ? category.color : category.color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = currentStroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.totalSize != totalSize ||
        oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.categorySizeMap != categorySizeMap;
  }
}
