import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/utils/back_navigation_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackNavigationHelper Tests', () {
    testWidgets('showDiscardDialog returns false when Stay is pressed',
        (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await BackNavigationHelper.showDiscardDialog(context);
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved Changes'), findsOneWidget);
      expect(find.text('Unsaved changes will be lost.'), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();

      expect(result, false);
      expect(find.text('Unsaved Changes'), findsNothing);
    });

    testWidgets('showDiscardDialog returns true when Discard is pressed',
        (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await BackNavigationHelper.showDiscardDialog(context);
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(result, true);
      expect(find.text('Unsaved Changes'), findsNothing);
    });

    testWidgets('showProcessingDialog returns false on Stay and true on Leave',
        (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await BackNavigationHelper.showProcessingDialog(context);
              },
              child: const Text('Show Processing'),
            ),
          ),
        ),
      );

      // 1. Test Stay
      await tester.tap(find.text('Show Processing'));
      await tester.pumpAndSettle();

      expect(find.text('Operation in Progress'), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);

      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(result, false);

      // 2. Test Leave
      await tester.tap(find.text('Show Processing'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(result, true);
    });

    testWidgets('showExitAppDialog returns false on Cancel and true on Exit',
        (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await BackNavigationHelper.showExitAppDialog(context);
              },
              child: const Text('Show Exit'),
            ),
          ),
        ),
      );

      // Test Cancel
      await tester.tap(find.text('Show Exit'));
      await tester.pumpAndSettle();
      expect(find.text('Exit App'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, false);

      // Test Exit
      await tester.tap(find.text('Show Exit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      expect(result, true);
    });

    testWidgets('handleDoubleBackPress first press shows SnackBar and updates time',
        (WidgetTester tester) async {
      DateTime? lastPressTime;
      bool? didExit;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  didExit = BackNavigationHelper.handleDoubleBackPress(
                    context: context,
                    lastBackPressTime: lastPressTime,
                    onTimeUpdated: (t) => lastPressTime = t,
                  );
                },
                child: const Text('Simulate Back'),
              ),
            ),
          ),
        ),
      );

      // First back press: should show snackbar and return false
      await tester.tap(find.text('Simulate Back'));
      await tester.pump();

      expect(didExit, false);
      expect(lastPressTime, isNotNull);
      expect(find.text('Press back again to exit'), findsOneWidget);
    });
  });
}
