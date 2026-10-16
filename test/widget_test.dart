import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dustie_storage/app.dart';

void main() {
  testWidgets('Dustie Storage smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const DustieStorageApp());
    expect(find.text('Dustie'), findsWidgets);
  });
}
