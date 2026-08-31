import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/main.dart';

void main() {
  testWidgets('App loads test', (WidgetTester tester) async {
    await tester.pumpWidget(const SiyaAdminApp());
    expect(find.byType(SiyaAdminApp), findsOneWidget);
  });
}
