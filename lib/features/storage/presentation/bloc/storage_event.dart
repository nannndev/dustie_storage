import 'package:equatable/equatable.dart';

import '../../domain/entities/scan_progress.dart';
import '../../domain/entities/storage_item.dart';
import '../../domain/entities/storage_summary.dart';

abstract class StorageEvent extends Equatable {
  const StorageEvent();

  @override
  List<Object?> get props => [];
}

class LoadCommonLocationsRequested extends StorageEvent {
  const LoadCommonLocationsRequested();
}

class StartScanRequested extends StorageEvent {
  final String path;
  final bool force;
  const StartScanRequested(this.path, {this.force = false});

  @override
  List<Object?> get props => [path, force];
}

class PickAndScanCustomFolderRequested extends StorageEvent {
  const PickAndScanCustomFolderRequested();
}

class ScanProgressUpdated extends StorageEvent {
  final ScanProgress progress;
  final String? targetPath;
  const ScanProgressUpdated(this.progress, {this.targetPath});

  @override
  List<Object?> get props => [progress, targetPath];
}

class ScanCompletedEvent extends StorageEvent {
  final StorageSummary summary;
  final String path;
  const ScanCompletedEvent(this.summary, {this.path = ''});

  @override
  List<Object?> get props => [summary, path];
}

class ScanFailedEvent extends StorageEvent {
  final String message;
  final String path;
  const ScanFailedEvent(this.message, {this.path = ''});

  @override
  List<Object?> get props => [message, path];
}

class CancelScanRequested extends StorageEvent {
  const CancelScanRequested();
}

class DeleteSingleItemRequested extends StorageEvent {
  final StorageItem item;
  const DeleteSingleItemRequested(this.item);

  @override
  List<Object?> get props => [item];
}

class DeleteMultipleItemsRequested extends StorageEvent {
  final List<StorageItem> items;
  const DeleteMultipleItemsRequested(this.items);

  @override
  List<Object?> get props => [items];
}

/// Deletes only selected duplicates whose bytes match a copy that stays.
class DeleteVerifiedDuplicatesRequested extends StorageEvent {
  final List<List<StorageItem>> groups;
  final Set<String> selectedPaths;
  const DeleteVerifiedDuplicatesRequested(this.groups, this.selectedPaths);

  @override
  List<Object?> get props => [groups, selectedPaths];
}

class DeleteEmptyDirectoriesRequested extends StorageEvent {
  final List<String> dirPaths;
  const DeleteEmptyDirectoriesRequested(this.dirPaths);

  @override
  List<Object?> get props => [dirPaths];
}

class DismissNotificationRequested extends StorageEvent {
  const DismissNotificationRequested();
}
