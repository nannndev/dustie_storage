import 'package:dustie_storage/features/storage/domain/entities/file_category.dart';
import 'package:dustie_storage/features/storage/domain/entities/scan_progress.dart';
import 'package:dustie_storage/features/storage/presentation/widgets/scanning_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ScanProgress _progress() {
  final cats = List.filled(FileCategory.values.length, 0);
  cats[FileCategory.video.index] = 3 * 1024 * 1024 * 1024;
  cats[FileCategory.image.index] = 1024 * 1024 * 1024;
  return ScanProgress(
    fileCount: 142381,
    bytes: 4 * 1024 * 1024 * 1024,
    categoryBytes: cats,
    currentPath: r'C:\Users\me\Videos',
  );
}

Widget _host(ScanProgress? p, {Size size = const Size(1280, 800)}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: ScanningOverlay(progress: p, onCancel: () {}),
        ),
      ),
    );

void main() {
  testWidgets('shows live totals and the biggest categories', (tester) async {
    await tester.pumpWidget(_host(_progress()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('142,381'), findsOneWidget);
    expect(find.text('4.0 GB'), findsOneWidget);
    expect(find.text('Videos 3.0 GB'), findsOneWidget);
    expect(find.text('Images 1.0 GB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders before the first progress report', (tester) async {
    await tester.pumpWidget(_host(null));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('0 B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a small window without overflow', (tester) async {
    tester.view.physicalSize = const Size(640, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(_progress(), size: const Size(640, 480)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
