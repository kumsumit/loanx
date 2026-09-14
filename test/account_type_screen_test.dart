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

  testWidgets('stacks compact account choices on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: AccountTypeScreen(onContinue: _ignoreChoice)),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(Scaffold)).width, 320);

    final lender = tester.getRect(find.byKey(const Key('interest-lender')));
    final borrower = tester.getRect(find.byKey(const Key('interest-borrower')));
    final both = tester.getRect(find.byKey(const Key('interest-both')));

    expect(lender.bottom, lessThanOrEqualTo(borrower.top));
    expect(borrower.bottom, lessThanOrEqualTo(both.top));
    expect(lender.height, lessThan(110));
    expect(borrower.height, lessThan(110));
    expect(both.height, lessThan(110));
  });
}

void _ignoreChoice(AccountType _) {}
