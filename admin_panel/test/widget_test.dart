import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App loads test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Siya Admin App')),
        ),
      ),
    );
    expect(find.text('Siya Admin App'), findsOneWidget);
  });
}
