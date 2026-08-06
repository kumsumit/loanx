import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/model/loan.dart';

void main() {
  group('Loan interest calculations', () {
    test('simple interest and collectable use the same total contract', () {
      final loan = _loan(
        interestType: InterestType.simple,
        interestRate: 10,
        durationInDays: 60,
      );

      expect(loan.calculateInterest(), closeTo(2000, 0.001));
      expect(loan.calculateCollectable(), closeTo(12000, 0.001));
    });

    test('compound interest compounds once per selected period', () {
      final loan = _loan(
        interestType: InterestType.compound,
        interestRate: 10,
        durationInDays: 60,
      );

      expect(loan.calculateInterest(), closeTo(2100, 0.001));
      expect(loan.calculateCollectable(), closeTo(12100, 0.001));
    });

    test('a newly created loan has only its principal collectable', () {
      final loan = _loan(
        interestType: InterestType.compound,
        interestRate: 10,
        durationInDays: 0,
      );

      expect(loan.calculateInterest(), closeTo(0, 0.001));
      expect(loan.calculateCollectable(), closeTo(10000, 0.001));
    });
  });
}

Loan _loan({
  required InterestType interestType,
  required double interestRate,
  required int durationInDays,
}) {
  final created = DateTime(2026, 1, 1);
  return Loan(
    depositorName: 'Borrower',
    phoneNumber: '1234567890',
    relativeName: '',
    address: '',
    loanAmount: 10000,
    interestRate: interestRate,
    interestType: interestType.index,
    interestFrequency: InterestFrequency.monthly.index,
    additionalDetails: '',
    familyRelationId: 1,
    mortgageMaterialId: 1,
    dateCreated: created,
    dateFinished: created.add(Duration(days: durationInDays)),
  );
}
