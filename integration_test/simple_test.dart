import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/main.dart' as app;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('starts the local LoanX application', (
    WidgetTester tester,
  ) async {
    await app.main();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(app.MyApp), findsOneWidget);
    expect(find.textContaining('flutter_rust_bridge quickstart'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
