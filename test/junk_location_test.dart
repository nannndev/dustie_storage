import 'dart:io';

import 'package:dustie_storage/features/storage/data/datasources/best_effort_delete.dart';
import 'package:dustie_storage/features/storage/data/datasources/junk_location_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('dustie_junk_'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('isSafeTarget', () {
    final home = p.join(p.rootPrefix(Directory.current.path), 'Users', 'me');
    final ds = JunkLocationDataSourceImpl(
      environment: {'USERPROFILE': home, 'HOME': home},
    );

    test('rejects drive roots, shallow paths and home', () {
      expect(ds.isSafeTarget(p.rootPrefix(Directory.current.path)), isFalse);
      expect(ds.isSafeTarget(p.join(p.rootPrefix(home), 'Users')), isFalse);
      expect(ds.isSafeTarget(home), isFalse);
    });

    test('accepts a nested cache folder', () {
      expect(ds.isSafeTarget(p.join(home, 'AppData', 'Local', 'Temp')), isTrue);
    });
  });

  test('keepRoot empties the folder but leaves it in place', () {
    final root = Directory(p.join(tmp.path, 'Temp'))..createSync();
    Directory(p.join(root.path, 'sub')).createSync();
    File(p.join(root.path, 'sub', 'x.tmp')).writeAsBytesSync([1, 2, 3]);

    final r = BestEffortDelete.tree(root.path, keepRoot: true);

    expect(root.existsSync(), isTrue);
    expect(root.listSync(), isEmpty);
    expect(r.freedBytes, 3);
  });

  test('olderThan keeps recent files', () {
    final root = Directory(p.join(tmp.path, 'Temp'))..createSync();
    final oldFile = File(p.join(root.path, 'old.tmp'))..writeAsBytesSync([1]);
    oldFile.setLastModifiedSync(
      DateTime.now().subtract(const Duration(days: 3)),
    );
    final fresh = File(p.join(root.path, 'fresh.tmp'))
      ..writeAsBytesSync([1, 1]);

    final r = BestEffortDelete.tree(
      root.path,
      keepRoot: true,
      olderThan: DateTime.now().subtract(const Duration(days: 1)),
    );

    expect(oldFile.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
    expect(r.freedBytes, 1);
  });
}
