import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/screens/login_screen.dart';

void main() {
  testWidgets('AdminLoginScreen renders production UI without Dev Preview', (WidgetTester tester) async {
    // Set a desktop-sized surface
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: AdminLoginScreen(),
      ),
    );
    await tester.pump();

    // 1. Verify Header Elements
    expect(find.text('Siya Infotech Solar'), findsOneWidget);
    expect(find.text('Admin Data Management Portal'), findsOneWidget);

    // 2. Verify Form Fields
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // 3. Verify Sign In Button
    expect(find.text('Sign In to Admin Panel'), findsOneWidget);

    // 4. Verify Forgot Password link
    expect(find.text('Forgot Password?'), findsOneWidget);

    // 5. CRITICAL: Ensure 'Dev Preview (Skip Auth)' is completely absent
    expect(find.text('Dev Preview (Skip Auth)'), findsNothing);
    expect(find.textContaining('Dev Preview'), findsNothing);
    expect(find.textContaining('Skip Auth'), findsNothing);

    // 6. Test Form Validation on empty submit
    await tester.tap(find.text('Sign In to Admin Panel'));
    await tester.pump();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);

    // 7. Test Forgot Password Dialog opens
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Admin Password'), findsOneWidget);
    expect(find.text('Send Reset Link'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
