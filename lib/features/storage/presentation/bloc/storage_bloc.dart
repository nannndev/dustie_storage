import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/file_size_formatter.dart';
import '../../domain/entities/delete_result.dart';
import '../../domain/entities/scan_progress.dart';
import '../../domain/entities/storage_summary.dart';
import '../../domain/repositories/storage_repository.dart';
import 'storage_event.dart';
import 'storage_state.dart';

class StorageBloc extends Bloc<StorageEvent, StorageState> {
  final StorageRepository repository;
  final Map<String, StreamSubscription<ScanProgress>> _scanSubscriptions = {};

  /// Per-path progress, so switching back to a background scan shows its numbers immediately.
  final Map<String, ScanProgress> _latestProgress = {};

  StorageBloc({required this.repository}) : super(StorageState.initial()) {
    on<LoadCommonLocationsRequested>(_onLoadCommonLocations);
    on<StartScanRequested>(_onStartScan);
    on<PickAndScanCustomFolderRequested>(_onPickAndScanCustomFolder);
    on<ScanProgressUpdated>(_onScanProgressUpdated);
    on<ScanCompletedEvent>(_onScanCompleted);
    on<ScanFailedEvent>(_onScanFailed);
    on<CancelScanRequested>(_onCancelScan);
    on<DeleteSingleItemRequested>(_onDeleteSingleItem);
    on<DeleteMultipleItemsRequested>(_onDeleteMultipleItems);
    on<DeleteVerifiedDuplicatesRequested>(_onDeleteVerifiedDuplicates);
    on<DeleteEmptyDirectoriesRequested>(_onDeleteEmptyDirectories);
    on<DismissNotificationRequested>(_onDismissNotification);
  }

  @override
  Future<void> close() {
    for (final sub in _scanSubscriptions.values) {
      sub.cancel();
    }
    _scanSubscriptions.clear();
    return super.close();
  }

  Future<void> _onLoadCommonLocations(
    LoadCommonLocationsRequested event,
    Emitter<StorageState> emit,
  ) async {
    emit(state.copyWith(status: StorageStatus.loading));
    try {
      final locs = await repository.getCommonLocations();
      emit(state.copyWith(status: StorageStatus.initial, locations: locs));

      if (locs.isNotEmpty && state.currentPath.isEmpty) {
        add(StartScanRequested(locs.first.path));
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: StorageStatus.failure,
          errorMessage: 'Failed to load system drive locations: $e',
        ),
      );
    }
  }

  Future<void> _onStartScan(
    StartScanRequested event,
    Emitter<StorageState> emit,
  ) async {
    final path = event.path;

    // 1. If this path is already cached and not forced, switch to it immediately!
    if (!event.force && state.cache.containsKey(path)) {
      emit(
        state.copyWith(
          status: StorageStatus.success,
          currentPath: path,
          summary: state.cache[path]!,
          statusMessage:
              'Ready (${state.cache[path]!.files.length} files found)',
          clearError: true,
        ),
      );
      return;
    }

    // 2. If it's already actively scanning in the background, switch to it and show live progress
    if (state.scanningPaths.contains(path)) {
      emit(
        state.copyWith(
          status: StorageStatus.scanning,
          currentPath: path,
          statusMessage: 'Scanning $path...',
          scanProgress: _latestProgress[path] ?? ScanProgress.empty(path),
          clearError: true,
        ),
      );
      return;
    }

    // 3. Launch background scan for this path
    final updatedScanning = Set<String>.from(state.scanningPaths)..add(path);
    _latestProgress[path] = ScanProgress.empty(path);
    emit(
      state.copyWith(
        status: StorageStatus.scanning,
        currentPath: path,
        statusMessage: 'Scanning $path...',
        scanningPaths: updatedScanning,
        scanProgress: _latestProgress[path],
        clearError: true,
      ),
    );

    await _scanSubscriptions[path]?.cancel();
    _scanSubscriptions[path] = repository
        .scanDirectoryStream(
          path,
          onCompleted: (summary) {
            add(ScanCompletedEvent(summary, path: path));
          },
          onError: (err) {
            add(ScanFailedEvent(err, path: path));
          },
        )
        .listen((progress) {
          add(ScanProgressUpdated(progress, targetPath: path));
        });
  }

  Future<void> _onPickAndScanCustomFolder(
    PickAndScanCustomFolderRequested event,
    Emitter<StorageState> emit,
  ) async {
    final picked = await repository.pickCustomDirectory();
    if (picked != null && picked.isNotEmpty) {
      add(StartScanRequested(picked));
    }
  }

  void _onScanProgressUpdated(
    ScanProgressUpdated event,
    Emitter<StorageState> emit,
  ) {
    final p = event.progress;
    if (event.targetPath != null) _latestProgress[event.targetPath!] = p;
    if (event.targetPath == null || event.targetPath == state.currentPath) {
      emit(
        state.copyWith(
          scanProgress: p,
          statusMessage:
              '${FileSizeFormatter.formatCount(p.fileCount)} files • ${FileSizeFormatter.format(p.bytes)} • ${p.currentPath}',
        ),
      );
    }
  }

  void _onScanCompleted(ScanCompletedEvent event, Emitter<StorageState> emit) {
    final completedPath = event.path.isNotEmpty
        ? event.path
        : event.summary.rootPath;
    _scanSubscriptions.remove(completedPath)?.cancel();

    final updatedCache = Map<String, StorageSummary>.from(state.cache)
      ..[completedPath] = event.summary;
    final updatedScanning = Set<String>.from(state.scanningPaths)
      ..remove(completedPath);

    if (state.currentPath == completedPath) {
      emit(
        state.copyWith(
          status: StorageStatus.success,
          summary: event.summary,
          cache: updatedCache,
          scanningPaths: updatedScanning,
          statusMessage:
              'Scan complete (${event.summary.files.length} files found)',
        ),
      );
    } else {
      emit(
        state.copyWith(
          cache: updatedCache,
          scanningPaths: updatedScanning,
          notificationMessage: 'Scan complete for $completedPath',
        ),
      );
    }
  }

  void _onScanFailed(ScanFailedEvent event, Emitter<StorageState> emit) {
    final failedPath = event.path;
    _scanSubscriptions.remove(failedPath)?.cancel();
    final updatedScanning = Set<String>.from(state.scanningPaths)
      ..remove(failedPath);

    if (state.currentPath == failedPath || failedPath.isEmpty) {
      emit(
        state.copyWith(
          status: StorageStatus.failure,
          errorMessage: event.message,
          scanningPaths: updatedScanning,
        ),
      );
    } else {
      emit(
        state.copyWith(
          scanningPaths: updatedScanning,
          notificationMessage: 'Failed to scan $failedPath: ${event.message}',
        ),
      );
    }
  }

  void _onCancelScan(CancelScanRequested event, Emitter<StorageState> emit) {
    final path = state.currentPath;
    _scanSubscriptions.remove(path)?.cancel();
    repository.cancelScan(path);

    final updatedScanning = Set<String>.from(state.scanningPaths)..remove(path);
    emit(
      state.copyWith(
        status: StorageStatus.success,
        scanningPaths: updatedScanning,
        statusMessage: 'Scan cancelled for $path',
      ),
    );
  }

  Future<void> _onDeleteSingleItem(
    DeleteSingleItemRequested event,
    Emitter<StorageState> emit,
  ) async {
    final result = await repository.deleteItem(event.item);
    await _applyDeleteResult(result, event.item.name, emit);
  }

  Future<void> _onDeleteMultipleItems(
    DeleteMultipleItemsRequested event,
    Emitter<StorageState> emit,
  ) async {
    final result = await repository.deleteItems(event.items);
    await _applyDeleteResult(result, '${event.items.length} items', emit);
  }

  Future<void> _onDeleteVerifiedDuplicates(
    DeleteVerifiedDuplicatesRequested event,
    Emitter<StorageState> emit,
  ) async {
    final confirmed = await repository.verifyDuplicates(
      event.groups,
      event.selectedPaths,
    );
    final rejected = event.selectedPaths.length - confirmed.length;
    if (confirmed.isEmpty) {
      emit(
        state.copyWith(
          errorMessage:
              'Nothing deleted: none of the $rejected selected files is an exact copy',
        ),
      );
      return;
    }
    final result = await repository.deleteItems(confirmed);
    await _applyDeleteResult(
      result,
      rejected == 0
          ? '${confirmed.length} duplicates'
          : '${confirmed.length} duplicates ($rejected kept: content differs)',
      emit,
    );
  }

  /// Patches the summary with whatever was removed, even if some files were locked.
  Future<void> _applyDeleteResult(
    DeleteResult result,
    String label,
    Emitter<StorageState> emit,
  ) async {
    if (!result.removedAnything) {
      emit(
        state.copyWith(
          errorMessage: 'Could not delete $label (${result.skipSummary})',
        ),
      );
      return;
    }
    final patched = await state.summary.withoutAsync(result.removedPaths);
    final updatedCache = Map<String, StorageSummary>.from(state.cache)
      ..[state.currentPath] = patched;
    emit(
      state.copyWith(
        summary: patched,
        cache: updatedCache,
        notificationMessage: result.isComplete
            ? 'Deleted $label (${result.formattedFreed} freed)'
            : 'Cleaned $label: ${result.formattedFreed} freed, skipped ${result.skipSummary}',
      ),
    );
  }

  Future<void> _onDeleteEmptyDirectories(
    DeleteEmptyDirectoriesRequested event,
    Emitter<StorageState> emit,
  ) async {
    final deleted = <String>{};
    for (final d in event.dirPaths) {
      if (await repository.deleteDirectory(d)) {
        deleted.add(d);
      }
    }
    final patched = await state.summary.withoutAsync(deleted);
    emit(
      state.copyWith(
        summary: patched,
        notificationMessage: 'Removed ${deleted.length} empty folders',
      ),
    );
  }

  void _onDismissNotification(
    DismissNotificationRequested event,
    Emitter<StorageState> emit,
  ) {
    emit(state.copyWith(clearNotification: true, clearError: true));
  }
}
