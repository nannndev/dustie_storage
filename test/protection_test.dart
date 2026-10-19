import 'dart:io';

import 'package:dustie_storage/features/storage/data/datasources/best_effort_delete.dart';
import 'package:dustie_storage/features/storage/data/datasources/duplicate_verifier.dart';
import 'package:dustie_storage/features/storage/domain/entities/delete_result.dart';
import 'package:dustie_storage/features/storage/domain/entities/file_category.dart';
import 'package:dustie_storage/features/storage/domain/entities/protected_paths.dart';
import 'package:dustie_storage/features/storage/domain/entities/storage_item.dart';
import 'package:dustie_storage/features/storage/domain/entities/storage_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

StorageItem _item(String path, int size, {DateTime? modified}) => StorageItem(
  path: path,
  name: p.basename(path),
  size: size,
  isDirectory: false,
  modified: modified ?? DateTime(2020),
  extension: p.extension(path),
  category: FileCategoryExt.fromExtension(p.extension(path)),
);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('dustie_prot_'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('ProtectedPaths', () {
    test('flags toolchains, caches and OS folders on any separator', () {
      for (final path in [
        r'C:\Users\me\AppData\Local\Pub\Cache\hosted\pub.dev\analyzer-8.4.0\lib\a.dart',
        r'C:\Users\me\dev\flutter\bin\cache\pkg\sky_engine\lib\ui\painting.dart',
        '/home/me/.pub-cache/hosted/x.dart',
        '/home/me/project/.git/objects/ab',
        r'C:\Windows\System32\drivers\etc\hosts',
        r'C:\Program Files\App\app.exe',
        '/usr/lib/libc.so',
      ]) {
        expect(ProtectedPaths.isProtected(path), isTrue, reason: path);
      }
    });

    test('leaves ordinary user folders alone', () {
      for (final path in [
        r'C:\Users\me\Downloads\setup.exe',
        r'C:\Users\me\Videos\cache-of-memories.mp4',
        '/home/me/projects/system/notes.md',
        r'D:\PROJECT\dustie_storage\build\app.exe',
      ]) {
        expect(ProtectedPaths.isProtected(path), isFalse, reason: path);
      }
    });
  });

  test('summary never suggests protected files for cleanup', () {
    final cache = r'C:\Users\me\AppData\Local\Pub\Cache\hosted\pub.dev';
    final big = 20 * 1024 * 1024;
    final summary = StorageSummary.fromFiles(r'C:\Users\me', [
      _item(p.windows.join(cache, 'analyzer-8.2.0', 'lib', 'big.dart'), big),
      _item(p.windows.join(cache, 'analyzer-8.4.0', 'lib', 'big.dart'), big),
      _item(r'C:\Users\me\Downloads\old.zip', big),
    ], []);

    expect(summary.totalSize, 3 * big, reason: 'still counted in totals');
    expect(summary.duplicateGroups, isEmpty);
    expect(summary.dustyItems.map((f) => f.name), ['old.zip']);
    expect(summary.archiveItems.map((f) => f.name), ['old.zip']);
  });

  test('tree delete keeps protected files nested inside the target', () {
    final root = Directory(p.join(tmp.path, 'home'))..createSync();
    final keep = File(p.join(root.path, '.pub-cache', 'hosted', 'a.dart'))
      ..createSync(recursive: true);
    final junk = File(p.join(root.path, 'junk.tmp'))..writeAsStringSync('x');

    final r = BestEffortDelete.tree(root.path, keepRoot: true);

    expect(keep.existsSync(), isTrue);
    expect(junk.existsSync(), isFalse);
    expect(r.countSkipped(SkipReason.protected), 1);
  });

  group('DuplicateVerifier', () {
    File write(String name, List<int> bytes) =>
        File(p.join(tmp.path, name))..writeAsBytesSync(bytes);

    test('same name and size but different bytes is not a duplicate', () {
      final a = write('a1.dart', List.filled(4096, 1));
      final b = write('a2.dart', [...List.filled(4095, 1), 2]);
      final group = [_item(a.path, 4096), _item(b.path, 4096)];

      final r = DuplicateVerifier.verify([group], {b.path});

      expect(r.confirmed, isEmpty);
      expect(r.rejected.single.path, b.path);
    });

    test('identical bytes are confirmed', () {
      final a = write('c1.bin', List.filled(3 * 1024 * 1024 + 7, 9));
      final b = write('c2.bin', List.filled(3 * 1024 * 1024 + 7, 9));
      final size = a.lengthSync();
      final group = [_item(a.path, size), _item(b.path, size)];

      final r = DuplicateVerifier.verify([group], {b.path});

      expect(r.confirmed.single.path, b.path);
    });

    test('refuses to delete every copy in a group', () {
      final a = write('d1.bin', [1, 2, 3]);
      final b = write('d2.bin', [1, 2, 3]);
      final group = [_item(a.path, 3), _item(b.path, 3)];

      final r = DuplicateVerifier.verify([group], {a.path, b.path});

      expect(r.confirmed, isEmpty);
      expect(r.rejected, hasLength(2));
    });
  });
}
