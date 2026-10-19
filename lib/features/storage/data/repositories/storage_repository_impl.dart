import 'dart:isolate';

import '../../domain/entities/delete_result.dart';
import '../../domain/entities/scan_progress.dart';
import '../../domain/entities/storage_item.dart';
import '../../domain/entities/storage_summary.dart';
import '../../domain/entities/system_drive_location.dart';
import '../../domain/repositories/storage_repository.dart';
import '../datasources/duplicate_verifier.dart';
import '../datasources/local_file_system_data_source.dart';
import '../datasources/system_drive_data_source.dart';

class StorageRepositoryImpl implements StorageRepository {
  final LocalFileSystemDataSource localDataSource;
  final SystemDriveDataSource systemDriveDataSource;

  StorageRepositoryImpl({
    required this.localDataSource,
    required this.systemDriveDataSource,
  });

  @override
  Stream<ScanProgress> scanDirectoryStream(
    String dirPath, {
    required Function(StorageSummary summary) onCompleted,
    required Function(String error) onError,
  }) {
    return localDataSource.scanDirectory(
      dirPath,
      onCompleted: onCompleted,
      onError: onError,
    );
  }

  @override
  void cancelScan([String? dirPath]) {
    localDataSource.cancelScan(dirPath);
  }

  @override
  Future<DeleteResult> deleteItem(StorageItem item) {
    return localDataSource.deleteItem(item);
  }

  @override
  Future<DeleteResult> deleteItems(List<StorageItem> items) {
    return localDataSource.deleteItems(items);
  }

  @override
  Future<bool> deleteDirectory(String dirPath) {
    return localDataSource.deleteDirectory(dirPath);
  }

  @override
  Future<List<StorageItem>> verifyDuplicates(
    List<List<StorageItem>> groups,
    Set<String> selected,
  ) => Isolate.run(() => DuplicateVerifier.verify(groups, selected).confirmed);

  @override
  Future<List<SystemDriveLocation>> getCommonLocations() {
    return systemDriveDataSource.getCommonLocations();
  }

  @override
  Future<String?> pickCustomDirectory() {
    return systemDriveDataSource.pickCustomDirectory();
  }
}
