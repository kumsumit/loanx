import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/service/currency_presentation.dart';

void main() {
  test(
    'formats currencies with country-appropriate precision and grouping',
    () {
      expect(
        CurrencyPresentation.format(1234567.5, 'INR'),
        contains('12,34,567.50'),
      );
      expect(CurrencyPresentation.format(1234.5, 'JPY'), contains('1,235'));
      expect(CurrencyPresentation.format(12.345, 'KWD'), contains('12.345'));
    },
  );

  test('loan currency is persisted and defaults legacy records to INR', () {
    final loan = Loan(
      depositorName: 'Asha',
      phoneNumber: '',
      relativeName: '',
      address: '',
      loanAmount: 10,
      currency: 'USD',
      interestRate: 0,
      interestType: 0,
      interestFrequency: 0,
      additionalDetails: '',
      familyRelationId: 1,
      mortgageMaterialId: 1,
    );

    final json = loan.toJson();
    expect(json[LoanFields.currency], 'USD');
    expect(Loan.fromJson({...json, LoanFields.id: 1}).currency, 'USD');
  });
}
