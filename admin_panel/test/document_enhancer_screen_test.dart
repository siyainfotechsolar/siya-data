import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:admin_panel/models/document_enhancer_models.dart';
import 'package:admin_panel/screens/document_enhancer_screen.dart';
import 'package:admin_panel/widgets/doc_comparison_dialog.dart';
import 'package:admin_panel/widgets/doc_perspective_crop_dialog.dart';

Uint8List _createDummyImage({int width = 300, int height = 400}) {
  final image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixelRgb(x, y, 220, 220, 215);
    }
  }
  for (int y = 50; y < 70; y++) {
    for (int x = 20; x < width - 20; x++) {
      image.setPixelRgb(x, y, 10, 10, 10);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DocumentEnhancerScreen renders with all sections and controls', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: DocumentEnhancerScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Subtitle
    expect(find.text('Document Clear, Enhance & A4 Print'), findsOneWidget);
    expect(find.textContaining('Tools → Process WhatsApp photos'), findsOneWidget);

    // Verify Section A
    expect(find.text('Section A: Upload Documents'), findsOneWidget);
    expect(find.text('Browse Files / Photos'), findsOneWidget);

    // Verify initial empty state in Section E
    expect(find.text('No documents selected for A4 conversion.'), findsOneWidget);
  });

  testWidgets('DocComparisonDialog opens and switches view modes', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final original = _createDummyImage();
    final enhanced = _createDummyImage();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: ctx,
                  builder: (_) => DocComparisonDialog(
                    originalBytes: original,
                    enhancedBytes: enhanced,
                    title: 'Test Document',
                  ),
                );
              },
              child: const Text('Open Comparison'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Comparison'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Before & After Clarity Comparison'), findsOneWidget);
    expect(find.text('Side by Side'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Enhanced'), findsOneWidget);

    // Switch to Original view
    await tester.tap(find.text('Original'));
    await tester.pumpAndSettle();
    expect(find.text('ORIGINAL UPLOADED FILE (BEFORE)'), findsOneWidget);

    // Switch to Enhanced view
    await tester.tap(find.text('Enhanced'));
    await tester.pumpAndSettle();
    expect(find.text('ENHANCED DOCUMENT OUTPUT (AFTER)'), findsOneWidget);

    // Close
    await tester.tap(find.text('Close Comparison'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Before & After Clarity Comparison'), findsNothing);
  });

  testWidgets('DocPerspectiveCropDialog opens and adjusts sliders and deskew toggle', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final dummy = _createDummyImage();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: ctx,
                  builder: (_) => DocPerspectiveCropDialog(
                    imageBytes: dummy,
                    initialSettings: const DocumentEnhanceSettings(),
                  ),
                );
              },
              child: const Text('Open Crop'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Crop'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Crop Document & Straighten'), findsOneWidget);
    expect(find.text('Perspective Deskew'), findsOneWidget);

    // Toggle perspective deskew switch
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // Click Apply Crop
    final applyBtn = find.widgetWithText(ElevatedButton, 'Apply Crop');
    expect(applyBtn, findsOneWidget);
    await tester.tap(applyBtn);
    await tester.pumpAndSettle();
    expect(find.textContaining('Crop Document & Straighten'), findsNothing);
  });

  testWidgets('DocumentEnhancerScreen toggles between General and Aadhaar Card mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: DocumentEnhancerScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Initially in General Document mode
    expect(find.text('General Document'), findsOneWidget);
    expect(find.text('Aadhaar Card — Front & Back'), findsOneWidget);
    expect(find.text('Section A: Upload Documents'), findsOneWidget);

    // Switch to Aadhaar Card mode
    await tester.tap(find.text('Aadhaar Card — Front & Back'));
    await tester.pumpAndSettle();

    // In Aadhaar Card mode
    expect(find.textContaining('Aadhaar Front Side'), findsOneWidget);
    expect(find.textContaining('Aadhaar Back Side'), findsOneWidget);
    expect(find.text('Click to Upload Front Side'), findsOneWidget);
    expect(find.text('Click to Upload Back Side'), findsOneWidget);

    // Switch back to General Document mode
    await tester.tap(find.text('General Document'));
    await tester.pumpAndSettle();

    expect(find.text('Section A: Upload Documents'), findsOneWidget);
    expect(find.text('Browse Files / Photos'), findsOneWidget);
  });
}
