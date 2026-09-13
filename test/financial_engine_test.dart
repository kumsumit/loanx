import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/domain/financial_engine.dart';
import 'package:loanx/domain/money.dart';

void main() {
  final start = DateTime.utc(2026, 1, 1);
  final maturity = DateTime.utc(2027, 1, 1);
  Money inr(String value) => Money.parse(value, currency: 'INR');
  FinancialTerms terms(InterestMethod method, {String principal = '1000.00'}) =>
      FinancialTerms(
        principal: inr(principal),
        interestMethod: method,
        annualRateMicros: BigInt.from(10000000), // 10%
        calculationStartDate: start,
        maturityDate: maturity,
      );
  FinancialEvent repayment(String id, String amount, DateTime date) =>
      FinancialEvent(
        id: id,
        type: FinancialEventType.repayment,
        amount: inr(amount),
        effectiveDate: date,
        recordedAt: date.add(const Duration(hours: 1)),
      );

  test(
    'money parsing is exact and rejects excess precision or mixed currency',
    () {
      expect(inr('0.10') + inr('0.20'), inr('0.30'));
      expect(Money.parse('12', currency: 'JPY', scale: 0).toString(), '12');
      expect(() => inr('1.001'), throwsFormatException);
      expect(
        () => inr('1.00') + Money.parse('1.00', currency: 'USD'),
        throwsArgumentError,
      );
    },
  );

  test('zero and simple interest allocate repayment deterministically', () {
    final zero = FinancialEngine.calculate(terms(InterestMethod.zero), [
      repayment('p1', '250.00', DateTime.utc(2026, 6, 1)),
    ], asOf: maturity);
    expect(zero.principalOutstanding, inr('750.00'));
    expect(zero.interestOutstanding, inr('0.00'));

    final simple = FinancialEngine.calculate(terms(InterestMethod.simple), [
      repayment('p1', '50.00', DateTime.utc(2026, 6, 1)),
    ], asOf: maturity);
    expect(simple.interestOutstanding, inr('50.00'));
    expect(simple.principalOutstanding, inr('1000.00'));
  });

  test('flat interest uses full contractual term before maturity', () {
    final result = FinancialEngine.calculate(
      terms(InterestMethod.flat),
      const [],
      asOf: DateTime.utc(2026, 2, 1),
    );
    expect(result.interestOutstanding, inr('100.00'));
  });

  test('reducing balance accrues against principal after partial repayment', () {
    final result = FinancialEngine.calculate(
      terms(InterestMethod.reducingBalance),
      [repayment('p1', '550.00', DateTime.utc(2026, 7, 2))],
      asOf: maturity,
    );
    // First 182 days interest rounds to 49.86; payment clears it then principal.
    expect(result.principalOutstanding, inr('499.86'));
    expect(result.interestOutstanding, inr('25.06'));
  });

  test(
    'fees allocate first, overpayment becomes credit, and overdue is derived',
    () {
      final fee = FinancialEvent(
        id: 'fee',
        type: FinancialEventType.fee,
        amount: inr('20.00'),
        effectiveDate: start,
        recordedAt: start.add(const Duration(hours: 1)),
      );
      final result = FinancialEngine.calculate(terms(InterestMethod.zero), [
        fee,
        repayment('paid', '1030.00', start),
      ], asOf: DateTime.utc(2027, 1, 2));
      expect(result.totalOutstanding, inr('0.00'));
      expect(result.credit, inr('10.00'));
      expect(result.isOverdue, isFalse);
    },
  );

  test('reversal restores original result and cannot be repeated', () {
    final paid = repayment('paid', '100.00', DateTime.utc(2026, 2, 1));
    final reversal = FinancialEvent(
      id: 'reverse',
      type: FinancialEventType.reversal,
      amount: paid.amount,
      effectiveDate: DateTime.utc(2026, 2, 2),
      recordedAt: DateTime.utc(2026, 2, 2, 1),
      reversesEventId: paid.id,
    );
    final result = FinancialEngine.calculate(terms(InterestMethod.zero), [
      paid,
      reversal,
    ], asOf: maturity);
    expect(result.principalOutstanding, inr('1000.00'));
    expect(
      () => FinancialEngine.calculate(terms(InterestMethod.zero), [
        paid,
        reversal,
        FinancialEvent(
          id: 'reverse-2',
          type: FinancialEventType.reversal,
          amount: paid.amount,
          effectiveDate: DateTime.utc(2026, 2, 3),
          recordedAt: DateTime.utc(2026, 2, 3, 1),
          reversesEventId: paid.id,
        ),
      ], asOf: maturity),
      throwsStateError,
    );
  });
}
