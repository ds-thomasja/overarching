import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightning_core_ui/lightning_core_ui.dart';

import 'package:overarching/components/device_card/device_card.dart';
import 'package:overarching/components/device_modal/device_modal.dart';
import 'package:overarching/main.dart';

/// Boots the gallery in a viewport large enough to lay out the sidebar, preview
/// and controls panel without overflowing, and settles the first frame.
Future<void> _pumpGallery(WidgetTester tester, {bool dark = false}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ComponentPreviewApp(dark: dark));
  // Not pumpAndSettle: the loading state's skeleton shimmer never stops
  // animating, and DSText's tooltip-on-truncation measurement needs one
  // extra frame after the first build to resolve.
  await tester.pump();
}

/// Selects a component in the gallery's left-hand sidebar.
Future<void> _selectComponent(WidgetTester tester, String name) async {
  // Before selection the name appears only once, as the sidebar entry.
  await tester.tap(find.text(name));
  await tester.pump();
}

/// Opens the DeviceModal playground's modal and pumps the (zero-duration) DS
/// modal route into place.
Future<void> _openDeviceModal(WidgetTester tester) async {
  await tester.tap(find.text('Open DeviceModal'));
  await tester.pump();
  await tester.pump();
}

/// Boots a single [DeviceModal] inside the same DS bootstrap the real app uses,
/// but without the gallery around it, so the modal's own geometry can be
/// measured directly.
Future<void> _pumpDeviceModal(WidgetTester tester, Widget modal) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: DSCoreUILocalizationDelegates.localizationsDelegates,
    supportedLocales: DSCoreUILocalizationDelegates.supportedLocales,
    builder: (context, child) => DSTheme(
      data: const DSThemeDataLight(),
      child: DSRegion(region: DSRegionDataDE.new, child: child!),
    ),
    home: Align(child: modal),
  ));
  await tester.pump();
}

/// The bottom edge of the modal's 40px header row, i.e. the y coordinate at
/// which the header-to-body gap begins.
///
/// Read off the close icon-button, which spans the full header row height.
double _modalHeaderBottom(WidgetTester tester) => tester
    .getRect(find.ancestor(
      of: find.byWidgetPredicate(
          (widget) => widget is DSIcon && widget.iconRef == DSIcons.close),
      matching: find.byType(DSButton),
    ))
    .bottom;

/// Finds a DS widget that is parameterized with a type argument.
///
/// `find.byType` resolves a bare generic to its `dynamic` instantiation, which
/// never matches a concrete one such as `DSDropdown<int>`; a predicate on the
/// runtime type does.
Finder _byGenericType<T>() => find.byWidgetPredicate((widget) => widget is T);

void main() {
  testWidgets('Component gallery renders a live, controls-driven DeviceCard',
      (WidgetTester tester) async {
    await _pumpGallery(tester);

    // 'DeviceCard' appears both as the sidebar entry and the content
    // heading, since it sorts first and is therefore selected by default.
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
    final dropdownFinder = _byGenericType<DSDropdown>();
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

  testWidgets('Component gallery renders with the dark DS theme',
      (WidgetTester tester) async {
    await _pumpGallery(tester, dark: true);

    expect(find.byType(ComponentGalleryPage), findsOneWidget);
  });

  testWidgets('DeviceModal playground exposes its variant controls',
      (WidgetTester tester) async {
    await _pumpGallery(tester);
    await _selectComponent(tester, 'DeviceModal');

    // Now both the sidebar entry and the section heading.
    expect(find.text('DeviceModal'), findsNWidgets(2));

    // A modal is a route, so the preview holds the button that opens it rather
    // than the component itself.
    expect(find.text('Open DeviceModal'), findsOneWidget);
    expect(find.byType(DeviceModal), findsNothing);

    // The controls panel: the device-name and notification-message inputs, the
    // mode, type and device-count dropdowns (type only shows in select-device
    // mode, the playground's default), and one toggle per Figma boolean.
    expect(find.byType(DSInput), findsNWidgets(2));
    expect(_byGenericType<DSDropdown>(), findsNWidgets(3));
    expect(find.byType(DSSwitch), findsNWidgets(7));
  });

  testWidgets(
      'DeviceModal select-device mode lists real DeviceCards and confirms a '
      'selection', (WidgetTester tester) async {
    await _pumpGallery(tester);
    await _selectComponent(tester, 'DeviceModal');
    await _openDeviceModal(tester);

    // The DS modal chrome: title in the header, primary button in the toolbar.
    expect(find.byType(DeviceModal), findsOneWidget);
    expect(find.text('Select device'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);

    // The rows are the project's real DeviceCard, not a re-render of it, and
    // carry the full set of card data.
    expect(find.byType(DeviceCard), findsNWidgets(4));
    expect(find.text('SN:865561'), findsOneWidget);
    expect(find.byType(DSBatteryIndicator), findsNWidgets(4));
    expect(find.text('Online'), findsNWidgets(2));
    expect(find.text('Offline'), findsNWidgets(2));

    // The banner is the real DS inline notification. Its message is asserted
    // via the widget rather than its text, which would also match the
    // "Notification message" DSInput still mounted behind the barrier.
    expect(find.byType(DSInlineNotification), findsOneWidget);

    // Tapping a card moves the modal's own pending selection; only Confirm
    // commits it.
    await tester.tap(find.byType(DeviceCard).first);
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.byType(DeviceModal), findsNothing);
    expect(find.text('Last outcome: Confirmed #0'), findsOneWidget);
  });

  testWidgets('DeviceModal device-details mode renders every optional block',
      (WidgetTester tester) async {
    await _pumpGallery(tester);
    await _selectComponent(tester, 'DeviceModal');

    // Switch the mode dropdown (the first of the two) to the details variant.
    await tester.tap(_byGenericType<DSDropdown>().first);
    await tester.pump();
    await tester.tap(find.text('Device details').last);
    await tester.pump();

    await _openDeviceModal(tester);

    expect(find.byType(DeviceModal), findsOneWidget);

    // In details mode the title is the device's own name, which also appears
    // as the editable text of the "Device name" control driving it.
    expect(find.text('Primescan Connect'), findsNWidgets(2));

    // The info row: both sublines, the battery indicator and the status tag.
    expect(find.text('Subline-1'), findsOneWidget);
    expect(find.text('Subline-2'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);

    // The optional blocks, each backed by the real DS component.
    expect(_byGenericType<DSSegmentedControl>(), findsOneWidget);
    expect(find.text('CEREC / Connect'), findsOneWidget);
    expect(find.byType(DSInlineNotification), findsOneWidget);
    expect(find.byType(DSProgressBar), findsOneWidget);
    expect(find.text('Loading description...'), findsOneWidget);

    // The switchable devices are DeviceCards with name and subline only.
    expect(find.byType(DeviceCard), findsNWidgets(4));
    expect(find.text('Title'), findsNWidgets(4));
    expect(find.text('Description'), findsNWidgets(4));
    expect(find.byType(DSBatteryIndicator), findsOneWidget);

    // The segmented control drives a real selection change inside the modal.
    await tester.tap(find.text('CEREC / Connect'));
    await tester.pump();
    expect(_byGenericType<DSSegmentedControl>(), findsOneWidget);

    // The footer is a single secondary "Switch device" button.
    await tester.tap(find.text('Switch device'));
    await tester.pumpAndSettle();

    expect(find.byType(DeviceModal), findsNothing);
    expect(find.text('Last outcome: Switch device pressed'), findsOneWidget);
  });

  testWidgets(
      'DeviceModal details mode starts its body flush against the header',
      (WidgetTester tester) async {
    // No sublines, battery or status tag, so the image is the first body block.
    await _pumpDeviceModal(
      tester,
      DeviceModal.deviceDetails(
        device: const DeviceModalDeviceDetails(name: 'Device name'),
        onClose: () {},
      ),
    );

    final surfaceTop = tester.getRect(find.byType(DeviceModal)).top;
    final headerBottom = _modalHeaderBottom(tester);
    final imageTop = tester
        .getRect(find.byWidgetPredicate((widget) =>
            widget is SizedBox && widget.width == 240 && widget.height == 240))
        .top;

    // 24 surface padding + a 40 header row (32px heading2xl line box plus two
    // 4px component/xxs insets, matching the 40x40 close icon-button).
    expect(headerBottom - surfaceTop, 64,
        reason: 'the header row must end 64px below the surface top');
    // The Figma details variant places no LayoutSpacing between the header and
    // the scroll view, so the total is 24 + 40 + 0 = 64. DSModalDialog would
    // add its own non-overridable 24 here.
    expect(imageTop - headerBottom, 0,
        reason: 'details mode must have no header-to-body gap');
  });

  testWidgets('DeviceModal list mode keeps an 8px header-to-body gap',
      (WidgetTester tester) async {
    await _pumpDeviceModal(
      tester,
      DeviceModal.selectDevice(
        devices: const [DeviceModalDevice(name: 'Primescan Connect')],
        notificationMessage: 'Using the correct sensor.',
        onClose: () {},
      ),
    );

    final surfaceTop = tester.getRect(find.byType(DeviceModal)).top;
    final headerBottom = _modalHeaderBottom(tester);
    final bannerTop = tester.getRect(find.byType(DSInlineNotification)).top;

    expect(headerBottom - surfaceTop, 64,
        reason: 'the header row must end 64px below the surface top');
    // The Figma list variant places an explicit 8px LayoutSpacing.S there, so
    // the total is 24 + 40 + 8 = 72.
    expect(bannerTop - headerBottom, 8,
        reason: 'list mode must have an 8px header-to-body gap');
  });
}
