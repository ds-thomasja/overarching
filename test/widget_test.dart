import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:lightning_core_ui/lightning_core_ui.dart';

import 'package:overarching/components/device_card/device_card.dart';
import 'package:overarching/main.dart';

void main() {
  testWidgets('Component gallery renders a live, controls-driven DeviceCard',
      (WidgetTester tester) async {
    // A viewport large enough to lay out the sidebar, preview and controls
    // panel without overflowing.
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ComponentPreviewApp());
    // Not pumpAndSettle: the loading state's skeleton shimmer never stops
    // animating, and DSText's tooltip-on-truncation measurement needs one
    // extra frame after the first build to resolve.
    await tester.pump();

    // 'DeviceCard' appears both as the sidebar entry and the content
    // heading, since it's the only (and thus default-selected) component.
    expect(find.text('DeviceCard'), findsNWidgets(2));

    // Exactly one live preview instance, driven by the controls panel.
    // "Primescan Connect" appears twice: once as the card's DSText and once
    // as the editable text of the "Title" control that drives it.
    expect(find.byType(DeviceCard), findsOneWidget);
    expect(find.text('Primescan Connect'), findsNWidgets(2));
    expect(find.text('Online'), findsOneWidget);

    // The battery toggle defaults to on, rendering the real
    // DSBatteryIndicator rather than a hand-built stand-in.
    expect(find.byType(DSBatteryIndicator), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);

    // The controls panel exposes the title/subline inputs, the state
    // dropdown and the battery/selected toggles.
    final dropdownFinder =
        find.byWidgetPredicate((widget) => widget is DSDropdown);
    expect(find.byType(DSInput), findsNWidgets(2));
    expect(dropdownFinder, findsOneWidget);
    expect(find.byType(DSSwitch), findsNWidgets(2));

    // Switching the state dropdown to "Loading" updates the live preview.
    await tester.tap(dropdownFinder);
    await tester.pump();
    await tester.tap(find.text('Loading').last);
    await tester.pump();

    expect(find.byType(DeviceCard), findsOneWidget);
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
