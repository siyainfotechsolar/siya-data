import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('App loads test', (WidgetTester tester) async {
    await tester.pumpWidget(const SiyaMobileApp());
    expect(find.byType(SiyaMobileApp), findsOneWidget);
  });
}
