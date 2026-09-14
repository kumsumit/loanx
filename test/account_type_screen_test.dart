import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/screens/account_type_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offers lender, borrower, and both as localized preferences', (
    tester,
  ) async {
    AccountType? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountTypeScreen(onContinue: (value) => selected = value),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('interest-lender')), findsOneWidget);
    expect(find.byKey(const Key('interest-borrower')), findsOneWidget);
    expect(find.byKey(const Key('interest-both')), findsOneWidget);

    await tester.tap(find.byKey(const Key('interest-lender')));
    await tester.tap(find.byKey(const Key('interest-continue')));
    expect(selected, AccountType.lender);
  });
}
