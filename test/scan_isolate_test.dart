import 'dart:async';
import 'dart:io';

import 'package:dustie_storage/features/storage/data/datasources/local_file_system_data_source.dart';
import 'package:dustie_storage/features/storage/domain/entities/storage_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'scans on a background isolate and reports files + empty folders',
    () async {
      final root = await Directory.systemTemp.createTemp('dustie_scan');
      addTearDown(() => root.delete(recursive: true));
      await File('${root.path}/a.txt').writeAsString('hello');
      await Directory('${root.path}/sub').create();
      await File('${root.path}/sub/b.bin').writeAsBytes(List.filled(100, 0));
      await Directory('${root.path}/empty').create();

      final done = Completer<StorageSummary>();
      LocalFileSystemDataSourceImpl()
          .scanDirectory(
            root.path,
            onCompleted: done.complete,
            onError: done.completeError,
          )
          .listen((_) {});
      final summary = await done.future.timeout(const Duration(seconds: 10));

      expect(summary.files.map((f) => f.name).toSet(), {'a.txt', 'b.bin'});
      expect(summary.totalSize, 105);
      expect(summary.emptyFolders, [p.join(root.path, 'empty')]);
    },
  );
}
