import 'package:flutter_test/flutter_test.dart';
import 'package:krishirakshak/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KrishiRakshakApp());
    // Basic test to check if app builds
    expect(find.byType(KrishiRakshakApp), findsOneWidget);
  });
}
