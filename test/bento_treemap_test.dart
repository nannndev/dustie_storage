import 'package:dustie_storage/features/storage/domain/entities/bento_node.dart';
import 'package:dustie_storage/features/storage/domain/entities/file_category.dart';
import 'package:dustie_storage/features/storage/presentation/widgets/bento_treemap_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BentoNode _root() {
  // Long-tail sizes like a real folder: a few huge items, many tiny ones
  final children = [
    for (var i = 0; i < 200; i++)
      BentoNode(
        name: 'a_really_long_file_name_that_should_ellipsize_$i.mp4',
        path: '/root/$i',
        size: 1000000 ~/ (i + 1),
        isDirectory: i % 3 == 0,
        category: FileCategory.video,
      ),
  ];
  return BentoNode(
    name: 'root',
    path: '/root',
    size: children.fold(0, (s, n) => s + n.size),
    isDirectory: true,
    category: FileCategory.other,
    children: children,
  );
}

void main() {
  test('fitChildren groups the long tail so every tile can reach min size', () {
    final root = _root();
    const area = Size(800, 500);
    final visible = BentoTreemapWidget.fitChildren(root, area);

    expect(visible.length, lessThanOrEqualTo(BentoTreemapWidget.maxTiles));
    expect(visible.last.isGroup, isTrue);
    expect(visible.fold<int>(0, (s, n) => s + n.size), root.size);
  });

  for (final size in const [Size(320, 240), Size(800, 500), Size(1400, 900)]) {
    testWidgets('renders without overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: BentoTreemapWidget(rootNode: _root()))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
