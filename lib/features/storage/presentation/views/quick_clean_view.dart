import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../../core/utils/system_launcher.dart';
import '../../domain/entities/delete_result.dart';
import '../../domain/entities/junk_location.dart';
import '../../../navigation/presentation/cubit/navigation_cubit.dart';
import '../cubit/quick_clean_cubit.dart';
import '../widgets/dustie_mascot.dart';

class QuickCleanView extends StatelessWidget {
  const QuickCleanView({super.key});

  static const tabIndex = 5;

  @override
  Widget build(BuildContext context) {
    // IndexedStack builds every tab at startup, so load on first switch to this tab instead.
    return BlocListener<NavigationCubit, int>(
      listenWhen: (_, index) => index == tabIndex,
      listener: (context, _) => context.read<QuickCleanCubit>().ensureLoaded(),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return BlocBuilder<QuickCleanCubit, QuickCleanState>(
      builder: (context, state) {
        final cubit = context.read<QuickCleanCubit>();
        final totalBytes = state.measurements.values.fold<int>(
          0,
          (s, m) => s + m.bytes,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _banner(state, totalBytes),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Known junk folders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Re-measure',
                    onPressed: state.isCleaning ? null : cubit.load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: state.selected.isEmpty || state.isCleaning
                        ? null
                        : () => _confirmAndClean(context, state),
                    icon: state.isCleaning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cleaning_services_rounded, size: 18),
                    label: Text(
                      state.isCleaning
                          ? 'Cleaning…'
                          : 'Clean Selected (${FileSizeFormatter.format(state.selectedBytes)})',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (state.loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.locations.isEmpty)
                Text(
                  'No known junk folders on this system.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                for (final l in state.locations)
                  _LocationTile(
                    location: l,
                    measurement: state.measurements[l.id],
                    selected: state.selected.contains(l.id),
                    cleaning: state.cleaning.contains(l.id),
                    blocked: state.isBlocked(l),
                    lastResult: state.results[l.id],
                    onToggle: state.isCleaning
                        ? null
                        : () => cubit.toggle(l.id),
                    onCleanAsAdmin: state.needsAdmin(l) && !state.isCleaning
                        ? () => _cleanAsAdmin(context, l)
                        : null,
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _banner(QuickCleanState state, int totalBytes) {
    final measuring = state.measurements.length < state.locations.length;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.25),
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
          const DustieMascot(size: 72, mood: DustieMood.happy, animate: true),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Clean',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  measuring
                      ? 'Dustie is measuring temp files and caches…'
                      : 'Dustie found ${FileSizeFormatter.format(totalBytes)} in temp folders and caches. No scan needed — files in use are skipped automatically.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndClean(
    BuildContext context,
    QuickCleanState state,
  ) async {
    final cubit = context.read<QuickCleanCubit>();
    final messenger = ScaffoldMessenger.of(context);
    await cubit.refreshProcesses();
    if (!context.mounted) return;
    final current = cubit.state;
    final chosen = current.locations.where(
      (l) => current.selected.contains(l.id),
    );
    final names = chosen.map((l) => l.name).join(', ');
    final blocked = chosen.where(current.isBlocked).map((l) => l.name).toList();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSidebar,
        title: const Text('Clean these folders?'),
        content: Text(
          'Dustie will empty: $names\n\n'
          'About ${FileSizeFormatter.format(state.selectedBytes)}. The folders themselves stay; '
          'anything currently in use is skipped. This cannot be undone.'
          '${blocked.isEmpty ? '' : '\n\n⚠️ Still running: ${blocked.join(', ')}. Close those apps first for a full clean.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clean'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final result = await cubit.cleanSelected();
    if (result == null) return;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        content: Text(
          result.isComplete
              ? '✨ ${result.formattedFreed} freed!'
              : '✨ ${result.formattedFreed} freed — skipped ${result.skipSummary}',
        ),
      ),
    );
  }

  Future<void> _cleanAsAdmin(BuildContext context, JunkLocation l) async {
    final cubit = context.read<QuickCleanCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final r = await cubit.cleanAsAdmin(l);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: r == null ? AppColors.danger : AppColors.success,
        content: Text(
          r == null
              ? 'Admin clean cancelled'
              : '🛡️ ${FileSizeFormatter.format(r.freedBytes)} freed as admin'
                    '${r.skippedCount > 0 ? ' — ${r.skippedCount} still in use' : ''}',
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final JunkLocation location;
  final JunkMeasurement? measurement;
  final bool selected;
  final bool cleaning;
  final bool blocked;
  final DeleteResult? lastResult;
  final VoidCallback? onToggle;
  final VoidCallback? onCleanAsAdmin;

  const _LocationTile({
    required this.location,
    required this.measurement,
    required this.selected,
    required this.cleaning,
    required this.blocked,
    required this.lastResult,
    required this.onToggle,
    required this.onCleanAsAdmin,
  });

  IconData get _icon => switch (location.kind) {
    JunkKind.temp => Icons.hourglass_empty_rounded,
    JunkKind.browserCache => Icons.public_rounded,
    JunkKind.crashDumps => Icons.bug_report_rounded,
    JunkKind.logs => Icons.receipt_long_rounded,
    JunkKind.appCache => Icons.cached_rounded,
    JunkKind.devCache => Icons.code_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final regenerable = location.risk == JunkRisk.regenerable;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.success : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Checkbox(value: selected, onChanged: (_) => onToggle?.call()),
              Icon(_icon, color: AppColors.textSecondary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            location.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (regenerable) ...[
                          const SizedBox(width: 8),
                          _chip('rebuilds on use', AppColors.warning),
                        ],
                        if (blocked) ...[
                          const SizedBox(width: 8),
                          _chip(
                            'app running — close it first',
                            AppColors.danger,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      location.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (lastResult case final r? when !r.isComplete)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Last clean left ${r.skippedPaths.length} files: ${r.skipSummary}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onCleanAsAdmin != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: OutlinedButton.icon(
                    onPressed: onCleanAsAdmin,
                    icon: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 16,
                    ),
                    label: const Text('Clean as Admin'),
                  ),
                ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: cleaning || measurement == null
                    ? const Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            measurement!.formattedSize,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${measurement!.fileCount} files',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
              ),
              IconButton(
                tooltip: 'Open folder',
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                onPressed: () =>
                    SystemLauncher.revealInFileManager(location.path),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}
