import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/widget/loan_record_status_indicator.dart';

void main() {
  Loan loan({
    String syncState = Loan.locallySaved,
    DateTime? clientConfirmedAt,
    DateTime? dateFinished,
  }) => Loan(
    depositorName: 'Borrower',
    phoneNumber: '',
    relativeName: '',
    address: '',
    loanAmount: 1000,
    interestRate: 0,
    interestType: InterestType.simple.index,
    interestFrequency: InterestFrequency.monthly.index,
    additionalDetails: '',
    familyRelationId: 1,
    mortgageMaterialId: 1,
    syncState: syncState,
    clientConfirmedAt: clientConfirmedAt,
    dateFinished: dateFinished,
  );

  Future<void> pumpIndicator(WidgetTester tester, Loan value) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LoanRecordStatusIndicator(loan: value)),
      ),
    );
  }

  testWidgets('uses one grey tick for a local record', (tester) async {
    await pumpIndicator(tester, loan());

    expect(find.byIcon(Icons.done_rounded), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
  });

  testWidgets('uses two grey ticks after server acknowledgement', (
    tester,
  ) async {
    await pumpIndicator(tester, loan(syncState: Loan.serverSaved));

    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Saved to server'), findsOneWidget);
  });

  testWidgets('uses two green ticks after OTP confirmation', (tester) async {
    await pumpIndicator(
      tester,
      loan(
        syncState: Loan.serverSaved,
        clientConfirmedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.done_all_rounded));
    expect(icon.color, const Color(0xFF2E7D32));
    expect(
      find.bySemanticsLabel('Borrower confirmed by phone OTP'),
      findsOneWidget,
    );
  });

  testWidgets('uses a distinct paid badge for completed records', (
    tester,
  ) async {
    await pumpIndicator(tester, loan(dateFinished: DateTime.utc(2026, 1, 1)));

    expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.byIcon(Icons.done_rounded), findsNothing);
  });
}
