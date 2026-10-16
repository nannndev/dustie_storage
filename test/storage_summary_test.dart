import 'package:dustie_storage/features/storage/domain/entities/file_category.dart';
import 'package:dustie_storage/features/storage/domain/entities/storage_item.dart';
import 'package:dustie_storage/features/storage/domain/entities/storage_summary.dart';
import 'package:flutter_test/flutter_test.dart';

StorageItem _file(String path, int size) => StorageItem(
      path: path,
      name: path.split('/').last,
      size: size,
      isDirectory: false,
      modified: DateTime(2020),
      extension: '.dmg',
      category: FileCategory.installer,
    );

void main() {
  test('without() drops deleted files and folder contents, then regroups', () {
    final summary = StorageSummary.fromFiles('/root', [
      _file('/root/a/x.dmg', 200 * 1024),
      _file('/root/b/x.dmg', 200 * 1024),
      _file('/root/ab/y.dmg', 100),
    ], ['/root/empty']);
    expect(summary.duplicateGroups, hasLength(1));

    final after = summary.without({'/root/a', '/root/empty'});

    expect(after.files.map((f) => f.path), ['/root/b/x.dmg', '/root/ab/y.dmg']);
    expect(after.totalSize, 200 * 1024 + 100);
    expect(after.duplicateGroups, isEmpty);
    expect(after.emptyFolders, isEmpty);
  });
}
