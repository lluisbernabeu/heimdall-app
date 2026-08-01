import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heimdall/main.dart';

void main() {
  testWidgets('Heimdall arranca', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HeimdallApp());
    expect(find.text('HEIMDALL'), findsOneWidget);
    // avanzar el timer del splash (800ms) para no dejar timers pendientes
    await tester.pump(const Duration(milliseconds: 900));
  });
}
