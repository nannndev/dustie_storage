import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../navigation/presentation/cubit/navigation_cubit.dart';
import '../../domain/entities/file_category.dart';
import '../bloc/storage_bloc.dart';
import '../bloc/storage_event.dart';
import '../bloc/storage_state.dart';
import '../widgets/category_bar.dart';
import '../widgets/file_list_tile.dart';
import '../widgets/storage_donut_chart.dart';

class OverviewView extends StatefulWidget {
  const OverviewView({super.key});

  @override
  State<OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends State<OverviewView> {
  FileCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StorageBloc, StorageState>(
      buildWhen: (a, b) =>
          !identical(a.summary, b.summary) ||
          a.isScanning != b.isScanning ||
          a.currentPath != b.currentPath,
      builder: (context, state) {
        final result = state.summary;
        final top5 = result.files.take(5).toList();

        final potentialSavings =
            result.dustyItems.fold<int>(0, (sum, i) => sum + i.size) +
            result.installerItems.fold<int>(0, (sum, i) => sum + i.size);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stat Cards
                  if (isNarrow)
                    Column(
                      children: [
                        _buildStatCard(
                          title: 'Total Scanned',
                          value: FileSizeFormatter.format(result.totalSize),
                          subtitle: '${result.files.length} files found',
                          icon: Icons.pie_chart_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        _buildStatCard(
                          title: 'Dusty Clutter',
                          value: FileSizeFormatter.format(
                            result.dustyItems.fold<int>(
                              0,
                              (s, i) => s + i.size,
                            ),
                          ),
                          subtitle:
                              '${result.dustyItems.length} old files (>6 mos)',
                          icon: Icons.auto_delete_rounded,
                          color: AppColors.warning,
                          onTap: () =>
                              context.read<NavigationCubit>().setTab(3),
                        ),
                        const SizedBox(height: 12),
                        _buildStatCard(
                          title: 'Potential Reclaim',
                          value: FileSizeFormatter.format(potentialSavings),
                          subtitle: 'Dusty + Installers',
                          icon: Icons.cleaning_services_rounded,
                          color: AppColors.success,
                          onTap: () =>
                              context.read<NavigationCubit>().setTab(3),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Total Scanned',
                            value: FileSizeFormatter.format(result.totalSize),
                            subtitle: '${result.files.length} files found',
                            icon: Icons.pie_chart_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Dusty Clutter',
                            value: FileSizeFormatter.format(
                              result.dustyItems.fold<int>(
                                0,
                                (s, i) => s + i.size,
                              ),
                            ),
                            subtitle:
                                '${result.dustyItems.length} old files (>6 mos)',
                            icon: Icons.auto_delete_rounded,
                            color: AppColors.warning,
                            onTap: () =>
                                context.read<NavigationCubit>().setTab(3),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Potential Reclaim',
                            value: FileSizeFormatter.format(potentialSavings),
                            subtitle: 'Dusty + Installers',
                            icon: Icons.cleaning_services_rounded,
                            color: AppColors.success,
                            onTap: () =>
                                context.read<NavigationCubit>().setTab(3),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 28),

                  // Donut + Category Breakdown
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.bgSidebar,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: isNarrow
                        ? Column(
                            children: [
                              Center(
                                child: StorageDonutChart(
                                  categorySizeMap: result.categorySizeMap,
                                  totalSize: result.totalSize,
                                  totalFiles: result.files.length,
                                  selectedCategory: _selectedCategory,
                                  onCategorySelected: (cat) =>
                                      setState(() => _selectedCategory = cat),
                                ),
                              ),
                              const SizedBox(height: 24),
                              CategoryBar(
                                categorySizeMap: result.categorySizeMap,
                                totalSize: result.totalSize,
                                selectedCategory: _selectedCategory,
                                onCategoryToggled: (cat) =>
                                    setState(() => _selectedCategory = cat),
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              StorageDonutChart(
                                categorySizeMap: result.categorySizeMap,
                                totalSize: result.totalSize,
                                totalFiles: result.files.length,
                                selectedCategory: _selectedCategory,
                                onCategorySelected: (cat) =>
                                    setState(() => _selectedCategory = cat),
                              ),
                              const SizedBox(width: 36),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Storage Breakdown by Category',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            TextButton.icon(
                                              onPressed: () => context
                                                  .read<NavigationCubit>()
                                                  .setTab(1),
                                              icon: const Icon(
                                                Icons
                                                    .dashboard_customize_rounded,
                                                size: 16,
                                              ),
                                              label: const Text('Bento Board'),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.primaryLight,
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => context
                                                  .read<NavigationCubit>()
                                                  .setTab(2),
                                              icon: const Icon(
                                                Icons.tune_rounded,
                                                size: 16,
                                              ),
                                              label: const Text('Filters'),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    CategoryBar(
                                      categorySizeMap: result.categorySizeMap,
                                      totalSize: result.totalSize,
                                      selectedCategory: _selectedCategory,
                                      onCategoryToggled: (cat) => setState(
                                        () => _selectedCategory = cat,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 28),

                  // Top Storage Hogs Header
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: AppColors.catInstaller,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Biggest Space Consumers',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () =>
                            context.read<NavigationCubit>().setTab(2),
                        child: Text(
                          'View All in Classifier →',
                          style: TextStyle(color: AppColors.primaryLight),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (top5.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text(
                        state.isScanning
                            ? 'Scanning files...'
                            : 'No files scanned yet. Click a location above!',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: top5.length,
                      itemBuilder: (context, index) {
                        final item = top5[index];
                        return FileListTile(
                          item: item,
                          onDelete: () => context.read<StorageBloc>().add(
                            DeleteSingleItemRequested(item),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bgSidebar,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
