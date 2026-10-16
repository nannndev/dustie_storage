import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../navigation/presentation/cubit/navigation_cubit.dart';
import '../bloc/storage_bloc.dart';
import '../bloc/storage_event.dart';
import '../bloc/storage_state.dart';
import '../widgets/dustie_mascot.dart';
import '../widgets/scanning_overlay.dart';
import 'bento_board_view.dart';
import 'classifier_view.dart';
import 'duplicates_view.dart';
import 'overview_view.dart';
import 'sweep_view.dart';

class MainDashboardView extends StatelessWidget {
  const MainDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<StorageBloc, StorageState>(
      listener: (context, state) {
        if (state.notificationMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.notificationMessage!),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<StorageBloc>().add(const DismissNotificationRequested());
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<StorageBloc>().add(const DismissNotificationRequested());
        }
      },
      child: Scaffold(
        body: Row(
          children: [
            _buildSidebar(context),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(context),
                  Expanded(
                    child: Stack(
                      children: [
                        BlocBuilder<NavigationCubit, int>(
                          builder: (context, activeIndex) {
                            return IndexedStack(
                              index: activeIndex,
                              children: const [
                                OverviewView(),
                                BentoBoardView(),
                                ClassifierView(),
                                SweepView(),
                                DuplicatesView(),
                              ],
                            );
                          },
                        ),
                        BlocBuilder<StorageBloc, StorageState>(
                          buildWhen: (a, b) =>
                              a.isScanning != b.isScanning ||
                              a.statusMessage != b.statusMessage,
                          builder: (context, state) {
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: state.isScanning
                                  ? ScanningOverlay(
                                      key: const ValueKey('scanning'),
                                      statusMessage: state.statusMessage,
                                      onCancel: () => context
                                          .read<StorageBloc>()
                                          .add(const CancelScanRequested()),
                                    )
                                  : const SizedBox.shrink(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppColors.bgSidebar,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: BlocBuilder<StorageBloc, StorageState>(
        buildWhen: (a, b) =>
            !identical(a.summary, b.summary) ||
            a.isScanning != b.isScanning ||
            a.currentPath != b.currentPath,
        builder: (context, storageState) {
          return BlocBuilder<NavigationCubit, int>(
            builder: (context, activeIndex) {
              final nav = context.read<NavigationCubit>();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo & Mascot
                  Row(
                    children: [
                      DustieMascot(
                        size: 38,
                        mood: storageState.isScanning
                            ? DustieMood.scanning
                            : DustieMood.happy,
                        animate: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dustie',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Storage Manager',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Navigation Tabs
                  _buildNavItem(
                    context,
                    index: 0,
                    activeIndex: activeIndex,
                    label: 'Overview',
                    icon: Icons.pie_chart_rounded,
                    onTap: () => nav.setTab(0),
                  ),
                  _buildNavItem(
                    context,
                    index: 1,
                    activeIndex: activeIndex,
                    label: '🍱 Bento Board',
                    icon: Icons.dashboard_customize_rounded,
                    onTap: () => nav.setTab(1),
                  ),
                  _buildNavItem(
                    context,
                    index: 2,
                    activeIndex: activeIndex,
                    label: 'Classifier & Filter',
                    icon: Icons.tune_rounded,
                    onTap: () => nav.setTab(2),
                  ),
                  _buildNavItem(
                    context,
                    index: 3,
                    activeIndex: activeIndex,
                    label: 'Dustie Sweep',
                    icon: Icons.auto_delete_rounded,
                    badge: storageState.summary.dustyItems.length,
                    onTap: () => nav.setTab(3),
                  ),
                  _buildNavItem(
                    context,
                    index: 4,
                    activeIndex: activeIndex,
                    label: 'Duplicate Finder',
                    icon: Icons.copy_rounded,
                    badge: storageState.summary.duplicateGroups.length,
                    onTap: () => nav.setTab(4),
                  ),

                  const Spacer(),

                  // AI Stage 2 Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.primaryLight,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Assistant',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Stage 2: Coming Soon',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required int activeIndex,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    final isSelected = activeIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.primaryLight
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.bgCardHover,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return BlocBuilder<StorageBloc, StorageState>(
      builder: (context, state) {
        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.bgSidebar,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...state.locations.map((loc) {
                        final isCurrent = state.currentPath == loc.path;
                        IconData iconData = Icons.folder_rounded;
                        if (loc.name.contains('Entire') ||
                            loc.name.contains('Root')) {
                          iconData = Icons.dns_rounded;
                        } else if (loc.name.contains('Caches') ||
                            loc.name.contains('AppData')) {
                          iconData = Icons.layers_rounded;
                        } else if (loc.name.contains('Home')) {
                          iconData = Icons.home_rounded;
                        } else if (loc.name == 'Downloads') {
                          iconData = Icons.download_rounded;
                        } else if (loc.name == 'Documents') {
                          iconData = Icons.folder_shared_rounded;
                        } else if (loc.name == 'Desktop') {
                          iconData = Icons.desktop_windows_rounded;
                        } else if (loc.name.contains('Volumes')) {
                          iconData = Icons.storage_rounded;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: Icon(
                              iconData,
                              size: 15,
                              color: isCurrent
                                  ? AppColors.onPrimary
                                  : AppColors.primaryLight,
                            ),
                            label: Text(loc.name),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isCurrent
                                  ? AppColors.onPrimary
                                  : AppColors.textSecondary,
                            ),
                            backgroundColor: isCurrent
                                ? AppColors.primary
                                : AppColors.bgCard,
                            side: BorderSide(
                              color: isCurrent
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            onPressed: () => context.read<StorageBloc>().add(
                              StartScanRequested(loc.path),
                            ),
                          ),
                        );
                      }),
                      ActionChip(
                        avatar: Icon(
                          Icons.folder_open_rounded,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        label: const Text('Pick Folder...'),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        backgroundColor: AppColors.bgCard,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onPressed: () => context.read<StorageBloc>().add(
                          const PickAndScanCustomFolderRequested(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Light / Dark Mode Cartoon Toggle
              BlocBuilder<ThemeCubit, ThemeMode>(
                builder: (context, themeMode) {
                  final isDark = themeMode == ThemeMode.dark;
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: IconButton(
                      tooltip: isDark
                          ? 'Switch to Cartoon Light Mode ☀️'
                          : 'Switch to Cozy Dark Mode 🌙',
                      icon: Icon(
                        isDark
                            ? Icons.wb_sunny_rounded
                            : Icons.nightlight_round,
                        color: isDark
                            ? AppColors.warning
                            : AppColors.primaryLight,
                        size: 18,
                      ),
                      onPressed: () => context.read<ThemeCubit>().toggleTheme(),
                    ),
                  );
                },
              ),

              const SizedBox(width: 10),

              if (state.isScanning) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 10),
                // Live path so users see the scan is progressing, not frozen
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    state.statusMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: Icon(
                    Icons.stop_circle_rounded,
                    color: AppColors.danger,
                    size: 22,
                  ),
                  tooltip: 'Cancel Scan',
                  onPressed: () => context.read<StorageBloc>().add(
                    const CancelScanRequested(),
                  ),
                ),
              ] else ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => context.read<StorageBloc>().add(
                    StartScanRequested(state.currentPath),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Re-scan',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
