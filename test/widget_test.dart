// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:phonecontrol/main.dart';

void main() {
  testWidgets('App boots and shows role selector', (WidgetTester tester) async {
    await tester.pumpWidget(const RemoteControlApp());

    expect(find.text('跨设备控制工具'), findsOneWidget);
    expect(find.text('被控端'), findsOneWidget);
    expect(find.text('控制端'), findsOneWidget);
  });
}
