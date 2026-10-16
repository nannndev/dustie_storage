import 'package:equatable/equatable.dart';
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
  const StartScanRequested(this.path);

  @override
  List<Object?> get props => [path];
}

class PickAndScanCustomFolderRequested extends StorageEvent {
  const PickAndScanCustomFolderRequested();
}

class ScanProgressUpdated extends StorageEvent {
  final String currentPath;
  const ScanProgressUpdated(this.currentPath);

  @override
  List<Object?> get props => [currentPath];
}

class ScanCompletedEvent extends StorageEvent {
  final StorageSummary summary;
  const ScanCompletedEvent(this.summary);

  @override
  List<Object?> get props => [summary];
}

class ScanFailedEvent extends StorageEvent {
  final String message;
  const ScanFailedEvent(this.message);

  @override
  List<Object?> get props => [message];
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

class DeleteEmptyDirectoriesRequested extends StorageEvent {
  final List<String> dirPaths;
  const DeleteEmptyDirectoriesRequested(this.dirPaths);

  @override
  List<Object?> get props => [dirPaths];
}

class DismissNotificationRequested extends StorageEvent {
  const DismissNotificationRequested();
}
