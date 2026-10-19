import 'dart:io';

import 'package:dustie_storage/features/storage/data/datasources/local_file_system_data_source.dart';
import 'package:dustie_storage/features/storage/domain/entities/file_category.dart';
import 'package:dustie_storage/features/storage/domain/entities/storage_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

StorageItem _dirItem(String path) => StorageItem(
  path: path,
  name: p.basename(path),
  size: 0,
  isDirectory: true,
  modified: DateTime.now(),
  extension: '',
  category: FileCategory.other,
);

void main() {
  late Directory tmp;
  final ds = LocalFileSystemDataSourceImpl();

  setUp(() => tmp = Directory.systemTemp.createTempSync('dustie_del_'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('removes a whole folder and reports it as one path', () async {
    final root = Directory(p.join(tmp.path, 'junk'))..createSync();
    File(p.join(root.path, 'a.tmp')).writeAsBytesSync(List.filled(100, 1));
    Directory(p.join(root.path, 'sub')).createSync();
    File(
      p.join(root.path, 'sub', 'b.tmp'),
    ).writeAsBytesSync(List.filled(50, 1));

    final r = await ds.deleteItem(_dirItem(root.path));

    expect(root.existsSync(), isFalse);
    expect(r.removedPaths, {root.path});
    expect(r.freedBytes, 150);
    expect(r.isComplete, isTrue);
  });

  test(
    'keeps going past a locked file and reports partial progress',
    () async {
      final root = Directory(p.join(tmp.path, 'Temp'))..createSync();
      final locked = File(p.join(root.path, 'locked.log'))
        ..writeAsStringSync('x');
      File(p.join(root.path, 'free.tmp')).writeAsBytesSync(List.filled(200, 1));
      final handle = locked.openSync(mode: FileMode.append);

      final r = await ds.deleteItem(_dirItem(root.path));
      handle.closeSync();

      expect(File(p.join(root.path, 'free.tmp')).existsSync(), isFalse);
      expect(r.freedBytes, 200);
      expect(r.skippedPaths, [locked.path]);
      expect(r.removedPaths, contains(p.join(root.path, 'free.tmp')));
    },
    skip: !Platform.isWindows ? 'Only Windows locks open files' : false,
  );
}
