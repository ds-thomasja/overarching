import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:overarching/components/device_card/device_card.dart';
import 'package:overarching/main.dart';

void main() {
  testWidgets('Component gallery renders DeviceCard instances', (WidgetTester tester) async {
    // A viewport large enough to lay out the Wrap without overflowing.
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ComponentPreviewApp());
    // Not pumpAndSettle: the loading DeviceCard's skeleton shimmer never
    // stops animating, and DSText's tooltip-on-truncation measurement needs
    // one extra frame after the first build to resolve.
    await tester.pump();

    expect(find.byType(DeviceCard), findsNWidgets(4));
    expect(find.text('Primescan Connect'), findsNWidgets(3));
    expect(find.text('Online'), findsNWidgets(3));
    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('Component gallery renders with the dark DS theme', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ComponentPreviewApp(dark: true));
    await tester.pump();

    expect(find.byType(ComponentGalleryPage), findsOneWidget);
  });
}
