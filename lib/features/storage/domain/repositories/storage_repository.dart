import '../entities/storage_item.dart';
import '../entities/storage_summary.dart';
import '../entities/system_drive_location.dart';

abstract class StorageRepository {
  Stream<String> scanDirectoryStream(
    String dirPath, {
    required Function(StorageSummary summary) onCompleted,
    required Function(String error) onError,
  });

  void cancelScan();

  Future<bool> deleteItem(StorageItem item);

  Future<int> deleteItems(List<StorageItem> items);

  Future<bool> deleteDirectory(String dirPath);

  Future<List<SystemDriveLocation>> getCommonLocations();

  Future<String?> pickCustomDirectory();
}
