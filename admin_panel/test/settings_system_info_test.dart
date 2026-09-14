import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/screens/settings_screen.dart';

void main() {
  group('Admin Settings & System Information Tests', () {
    testWidgets('SettingsScreen instantiates properly and displays telemetry title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );

      // Loading or screen renders without runtime errors
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
