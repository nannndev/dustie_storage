import '../entities/delete_result.dart';
import '../entities/scan_progress.dart';
import '../entities/storage_item.dart';
import '../entities/storage_summary.dart';
import '../entities/system_drive_location.dart';

abstract class StorageRepository {
  Stream<ScanProgress> scanDirectoryStream(
    String dirPath, {
    required Function(StorageSummary summary) onCompleted,
    required Function(String error) onError,
  });

  void cancelScan([String? dirPath]);

  Future<DeleteResult> deleteItem(StorageItem item);

  Future<DeleteResult> deleteItems(List<StorageItem> items);

  Future<bool> deleteDirectory(String dirPath);

  /// Of the [selected] paths, returns those byte-identical to a copy that will remain.
  Future<List<StorageItem>> verifyDuplicates(
    List<List<StorageItem>> groups,
    Set<String> selected,
  );

  Future<List<SystemDriveLocation>> getCommonLocations();

  Future<String?> pickCustomDirectory();
}
