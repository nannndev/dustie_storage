import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/system_drive_location.dart';

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
import 'quick_clean_view.dart';
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
                                QuickCleanView(),
                              ],
                            );
                          },
                        ),
                        BlocBuilder<StorageBloc, StorageState>(
                          buildWhen: (a, b) =>
                              a.isScanning != b.isScanning ||
                              !identical(a.scanProgress, b.scanProgress),
                          builder: (context, state) {
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: state.isScanning
                                  ? ScanningOverlay(
                                      key: const ValueKey('scanning'),
                                      progress: state.scanProgress,
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
                  _buildNavItem(
                    context,
                    index: QuickCleanView.tabIndex,
                    activeIndex: activeIndex,
                    label: 'Quick Clean',
                    icon: Icons.cleaning_services_rounded,
                    onTap: () => nav.setTab(QuickCleanView.tabIndex),
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
                child: _TopLocationsBar(
                  locations: state.locations,
                  currentPath: state.currentPath,
                  scanningPaths: state.scanningPaths,
                  onLocationSelected: (path) =>
                      context.read<StorageBloc>().add(StartScanRequested(path)),
                  onPickCustomFolder: () => context.read<StorageBloc>().add(
                    const PickAndScanCustomFolderRequested(),
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
                    StartScanRequested(state.currentPath, force: true),
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

class _TopLocationsBar extends StatefulWidget {
  final List<SystemDriveLocation> locations;
  final String currentPath;
  final Set<String> scanningPaths;
  final ValueChanged<String> onLocationSelected;
  final VoidCallback onPickCustomFolder;

  const _TopLocationsBar({
    required this.locations,
    required this.currentPath,
    required this.scanningPaths,
    required this.onLocationSelected,
    required this.onPickCustomFolder,
  });

  @override
  State<_TopLocationsBar> createState() => _TopLocationsBarState();
}

class _TopLocationsBarState extends State<_TopLocationsBar> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollButtons();
      _scrollToCurrentSelection();
    });
  }

  @override
  void didUpdateWidget(covariant _TopLocationsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locations.length != widget.locations.length ||
        oldWidget.currentPath != widget.currentPath ||
        oldWidget.scanningPaths.length != widget.scanningPaths.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateScrollButtons();
        if (oldWidget.currentPath != widget.currentPath) {
          _scrollToCurrentSelection();
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollButtons);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final canLeft = currentScroll > 4;
    final canRight = currentScroll < (maxScroll - 4);
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollToCurrentSelection() {
    if (!mounted || !_scrollController.hasClients) return;
    final index = widget.locations.indexWhere(
      (l) => l.path == widget.currentPath,
    );
    if (index >= 0) {
      // Estimate ~140px per chip
      final target = (index * 130.0 - 60.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scrollBy(double offset) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + offset).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _scrollController.hasClients) {
      final delta = event.scrollDelta.dy != 0
          ? event.scrollDelta.dy
          : event.scrollDelta.dx;
      if (delta != 0) {
        final target = (_scrollController.offset + delta).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(target);
      }
    }
  }

  IconData _iconFor(SystemDriveLocation loc) {
    switch (loc.iconName) {
      case 'hard_drive':
        return Icons.dns_rounded;
      case 'storage':
        return Icons.storage_rounded;
      case 'cloud':
        return Icons.cloud_rounded;
      case 'cached':
        return Icons.layers_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'download':
        return Icons.download_rounded;
      case 'folder_shared':
        return Icons.folder_shared_rounded;
      case 'desktop_windows':
        return Icons.desktop_windows_rounded;
      default:
        if (loc.name.contains('Disk') ||
            loc.name.contains('Drive') ||
            loc.name.contains('Volume')) {
          return Icons.dns_rounded;
        }
        return Icons.folder_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _updateScrollButtons(),
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: Listener(
                onPointerSignal: _handlePointerSignal,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: _canScrollLeft ? 38.0 : 0.0,
                    right: _canScrollRight ? 38.0 : 0.0,
                  ),
                  child: Row(
                    children: [
                      ...widget.locations.map((loc) {
                        final isCurrent = widget.currentPath == loc.path;
                        final isScanningThis = widget.scanningPaths.contains(
                          loc.path,
                        );
                        final iconData = _iconFor(loc);

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Tooltip(
                            message: isScanningThis
                                ? '${loc.name} (Scanning in background...)\n${loc.path}'
                                : '${loc.name}\n${loc.path}',
                            waitDuration: const Duration(milliseconds: 400),
                            child: ActionChip(
                              avatar: isScanningThis
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: isCurrent
                                            ? AppColors.onPrimary
                                            : AppColors.primaryLight,
                                      ),
                                    )
                                  : Icon(
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
                              onPressed: () =>
                                  widget.onLocationSelected(loc.path),
                            ),
                          ),
                        );
                      }),
                      Tooltip(
                        message:
                            'Select any custom drive, external volume, or folder',
                        child: ActionChip(
                          avatar: Icon(
                            Icons.folder_open_rounded,
                            size: 15,
                            color: AppColors.textSecondary,
                          ),
                          label: const Text('Pick Folder...'),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                          backgroundColor: AppColors.bgCard,
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onPressed: widget.onPickCustomFolder,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),

            // Left scroll chevron button
            if (_canScrollLeft)
              Positioned(
                left: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.bgSidebar,
                        AppColors.bgSidebar.withValues(alpha: 0.9),
                        AppColors.bgSidebar.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.75, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.only(right: 14),
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.bgCard,
                      foregroundColor: AppColors.textPrimary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(28, 28),
                      side: BorderSide(color: AppColors.border),
                    ),
                    tooltip: 'Scroll left',
                    onPressed: () => _scrollBy(-220),
                  ),
                ),
              ),

            // Right scroll chevron button
            if (_canScrollRight)
              Positioned(
                right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.bgSidebar.withValues(alpha: 0.0),
                        AppColors.bgSidebar.withValues(alpha: 0.9),
                        AppColors.bgSidebar,
                      ],
                      stops: const [0.0, 0.25, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 14),
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.bgCard,
                      foregroundColor: AppColors.textPrimary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(28, 28),
                      side: BorderSide(color: AppColors.border),
                    ),
                    tooltip: 'Scroll right',
                    onPressed: () => _scrollBy(220),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
