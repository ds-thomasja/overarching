import 'package:flutter_test/flutter_test.dart';

import 'package:overarching/components/device_card/device_card.dart';
import 'package:overarching/main.dart';

void main() {
  testWidgets('Component gallery renders DeviceCard instances', (WidgetTester tester) async {
    await tester.pumpWidget(const ComponentPreviewApp());

    expect(find.byType(DeviceCard), findsNWidgets(4));
    expect(find.text('Primescan Connect'), findsNWidgets(3));
  });
}
