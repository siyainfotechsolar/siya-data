import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admin_panel/screens/login_screen.dart';
import 'package:admin_panel/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Sub-Vendor Login Resolution & Web Form Validation', () {
    test('resolveLoginEmail normalizes Email, 10-digit Mobile, +91 Mobile & Vendor Code cleanly offline', () async {
      expect(await SupabaseService.resolveLoginEmail('Admin@SiyaSolar.com'), equals('admin@siyasolar.com'));
      expect(await SupabaseService.resolveLoginEmail('9822334455'), equals('9822334455@vendor.siyasolar.com'));
      expect(await SupabaseService.resolveLoginEmail('+91 98223 34455'), equals('9822334455@vendor.siyasolar.com'));
      expect(await SupabaseService.resolveLoginEmail('SIYA-VND-101'), equals('siya-vnd-101@vendor.siyasolar.com'));
    });

    testWidgets('AdminLoginScreen allows 10-digit Mobile and Vendor Code in Login field', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify updated label allows Mobile Number & Vendor Code
      expect(find.text('Email / Mobile Number / Vendor Code'), findsOneWidget);

      final signInFinder = find.text('Sign In to Admin Panel');

      // Enter 10-digit Mobile Number + valid password and submit form validation
      await tester.enterText(find.byType(TextFormField).at(0), '9822334455');
      await tester.enterText(find.byType(TextFormField).at(1), 'Siya@2026');
      await tester.ensureVisible(signInFinder);
      await tester.tap(signInFinder);
      await tester.pump();

      // Ensure email/mobile/code validation errors are NOT shown for valid mobile number
      expect(find.text('Please enter a valid email address'), findsNothing);
      expect(find.text('Enter a valid mobile number or vendor code'), findsNothing);
      await tester.pumpAndSettle();

      // Enter Vendor Code and submit validation
      await tester.enterText(find.byType(TextFormField).at(0), 'SIYA-VND-101');
      await tester.ensureVisible(signInFinder);
      await tester.tap(signInFinder);
      await tester.pump();

      expect(find.text('Please enter a valid email address'), findsNothing);
      expect(find.text('Enter a valid mobile number or vendor code'), findsNothing);
      await tester.pumpAndSettle();

      // Invalid malformed email still fails validation cleanly
      await tester.enterText(find.byType(TextFormField).at(0), 'bad@email');
      await tester.ensureVisible(signInFinder);
      await tester.tap(signInFinder);
      await tester.pump();
      expect(find.text('Please enter a valid email address'), findsOneWidget);

      // Too-short non-email identifier shows mobile/code validation message
      await tester.enterText(find.byType(TextFormField).at(0), 'ab');
      await tester.ensureVisible(signInFinder);
      await tester.tap(signInFinder);
      await tester.pump();
      expect(find.text('Enter a valid mobile number or vendor code'), findsOneWidget);
    });
  });
}
