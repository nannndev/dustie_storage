import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/file_size_formatter.dart';
import '../../domain/repositories/storage_repository.dart';
import 'storage_event.dart';
import 'storage_state.dart';

class StorageBloc extends Bloc<StorageEvent, StorageState> {
  final StorageRepository repository;
  StreamSubscription<String>? _scanSubscription;

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
    on<DeleteEmptyDirectoriesRequested>(_onDeleteEmptyDirectories);
    on<DismissNotificationRequested>(_onDismissNotification);
  }

  @override
  Future<void> close() {
    _scanSubscription?.cancel();
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
    await _scanSubscription?.cancel();
    repository.cancelScan();

    emit(
      state.copyWith(
        status: StorageStatus.scanning,
        currentPath: event.path,
        statusMessage: 'Scanning ${event.path}...',
        clearError: true,
      ),
    );

    _scanSubscription = repository
        .scanDirectoryStream(
          event.path,
          onCompleted: (summary) {
            add(ScanCompletedEvent(summary));
          },
          onError: (err) {
            add(ScanFailedEvent(err));
          },
        )
        .listen((currentPath) {
          add(ScanProgressUpdated(currentPath));
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
    if (state.isScanning) {
      emit(state.copyWith(statusMessage: event.currentPath));
    }
  }

  void _onScanCompleted(ScanCompletedEvent event, Emitter<StorageState> emit) {
    emit(
      state.copyWith(
        status: StorageStatus.success,
        summary: event.summary,
        statusMessage:
            'Scan complete (${event.summary.files.length} files found)',
      ),
    );
  }

  void _onScanFailed(ScanFailedEvent event, Emitter<StorageState> emit) {
    emit(
      state.copyWith(
        status: StorageStatus.failure,
        errorMessage: event.message,
      ),
    );
  }

  void _onCancelScan(CancelScanRequested event, Emitter<StorageState> emit) {
    _scanSubscription?.cancel();
    repository.cancelScan();
    emit(
      state.copyWith(
        status: StorageStatus.success,
        statusMessage: 'Scan cancelled',
      ),
    );
  }

  Future<void> _onDeleteSingleItem(
    DeleteSingleItemRequested event,
    Emitter<StorageState> emit,
  ) async {
    final success = await repository.deleteItem(event.item);
    if (success) {
      // Patch results in place instead of rescanning: keeps the user's tab, filters and scroll position
      final patched = await state.summary.withoutAsync({event.item.path});
      emit(
        state.copyWith(
          summary: patched,
          notificationMessage:
              'Deleted ${event.item.name} (${event.item.formattedSize} freed)',
        ),
      );
    } else {
      emit(state.copyWith(errorMessage: 'Could not delete ${event.item.name}'));
    }
  }

  Future<void> _onDeleteMultipleItems(
    DeleteMultipleItemsRequested event,
    Emitter<StorageState> emit,
  ) async {
    final deleted = <String>{};
    int freedBytes = 0;
    for (final item in event.items) {
      if (await repository.deleteItem(item)) {
        deleted.add(item.path);
        freedBytes += item.size;
      }
    }
    final patched = await state.summary.withoutAsync(deleted);
    emit(
      state.copyWith(
        summary: patched,
        notificationMessage:
            'Deleted ${deleted.length} items (${FileSizeFormatter.format(freedBytes)} reclaimed!)',
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
