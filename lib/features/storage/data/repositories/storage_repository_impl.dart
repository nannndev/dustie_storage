import '../../domain/entities/storage_item.dart';
import '../../domain/entities/storage_summary.dart';
import '../../domain/entities/system_drive_location.dart';
import '../../domain/repositories/storage_repository.dart';
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
  Stream<String> scanDirectoryStream(
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
  void cancelScan() {
    localDataSource.cancelScan();
  }

  @override
  Future<bool> deleteItem(StorageItem item) {
    return localDataSource.deleteItem(item);
  }

  @override
  Future<int> deleteItems(List<StorageItem> items) {
    return localDataSource.deleteItems(items);
  }

  @override
  Future<bool> deleteDirectory(String dirPath) {
    return localDataSource.deleteDirectory(dirPath);
  }

  @override
  Future<List<SystemDriveLocation>> getCommonLocations() {
    return systemDriveDataSource.getCommonLocations();
  }

  @override
  Future<String?> pickCustomDirectory() {
    return systemDriveDataSource.pickCustomDirectory();
  }
}
