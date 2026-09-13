import 'money.dart';

enum InterestMethod { zero, simple, flat, reducingBalance }

enum DayCountConvention { actual365, actual360, fixed30DayMonths }

enum RepaymentFrequency { none, daily, weekly, monthly }

enum FinancialEventType { repayment, fee, adjustment, reversal }

/// Versioned, deterministic calculation inputs. Annual rates are stored in
/// millionths of one percent: 12.5% = 12,500,000.
final class FinancialTerms {
  const FinancialTerms({
    required this.principal,
    required this.interestMethod,
    required this.annualRateMicros,
    required this.calculationStartDate,
    required this.maturityDate,
    this.dayCountConvention = DayCountConvention.actual365,
    this.repaymentFrequency = RepaymentFrequency.none,
    this.gracePeriodDays = 0,
    this.contractVersion = 'finance-v1',
  });

  final Money principal;
  final InterestMethod interestMethod;
  final BigInt annualRateMicros;
  final DateTime calculationStartDate;
  final DateTime maturityDate;
  final DayCountConvention dayCountConvention;
  final RepaymentFrequency repaymentFrequency;
  final int gracePeriodDays;
  final String contractVersion;

  void validate() {
    if (principal.minorUnits <= BigInt.zero || annualRateMicros < BigInt.zero) {
      throw ArgumentError('Principal must be positive and rate nonnegative');
    }
    if (!_dateOnly(calculationStartDate) ||
        !_dateOnly(maturityDate) ||
        maturityDate.isBefore(calculationStartDate)) {
      throw ArgumentError(
        'Financial dates must be UTC date-only values in order',
      );
    }
    if (gracePeriodDays < 0 || contractVersion != 'finance-v1') {
      throw ArgumentError('Unsupported financial contract');
    }
  }
}

final class FinancialEvent {
  const FinancialEvent({
    required this.id,
    required this.type,
    required this.amount,
    required this.effectiveDate,
    required this.recordedAt,
    this.reversesEventId,
  });
  final String id;
  final FinancialEventType type;
  final Money amount;
  final DateTime effectiveDate;
  final DateTime recordedAt;
  final String? reversesEventId;
}

final class LoanBalance {
  const LoanBalance({
    required this.principalOutstanding,
    required this.interestOutstanding,
    required this.feesOutstanding,
    required this.credit,
    required this.isOverdue,
  });
  final Money principalOutstanding;
  final Money interestOutstanding;
  final Money feesOutstanding;
  final Money credit;
  Money get totalOutstanding =>
      principalOutstanding + interestOutstanding + feesOutstanding;
  final bool isOverdue;
  bool get isClosed => totalOutstanding.minorUnits == BigInt.zero;
}

abstract final class FinancialEngine {
  static LoanBalance calculate(
    FinancialTerms terms,
    Iterable<FinancialEvent> input, {
    required DateTime asOf,
  }) {
    terms.validate();
    if (!_dateOnly(asOf)) {
      throw ArgumentError('asOf must be a UTC date-only value');
    }
    final events = input.where((e) => !e.effectiveDate.isAfter(asOf)).toList()
      ..sort((a, b) {
        final date = a.effectiveDate.compareTo(b.effectiveDate);
        return date != 0 ? date : a.recordedAt.compareTo(b.recordedAt);
      });
    final byId = <String, FinancialEvent>{};
    final reversed = <String>{};
    for (final event in events) {
      _validateEvent(terms.principal, event);
      if (byId.containsKey(event.id)) {
        throw StateError('Duplicate financial event ID');
      }
      byId[event.id] = event;
      if (event.type == FinancialEventType.reversal) {
        final original = byId[event.reversesEventId];
        if (original == null ||
            original.type == FinancialEventType.reversal ||
            original.amount != event.amount ||
            !reversed.add(original.id)) {
          throw StateError('Invalid or duplicate reversal');
        }
      }
    }

    var principal = terms.principal.minorUnits;
    var interest = BigInt.zero;
    var fees = BigInt.zero;
    var credit = BigInt.zero;
    var cursor = terms.calculationStartDate;
    final active = events.where(
      (e) => e.type != FinancialEventType.reversal && !reversed.contains(e.id),
    );
    for (final event in active) {
      final date = event.effectiveDate.isBefore(terms.calculationStartDate)
          ? terms.calculationStartDate
          : event.effectiveDate;
      if (terms.interestMethod == InterestMethod.reducingBalance &&
          date.isAfter(cursor)) {
        interest += _interest(principal, terms, cursor, date);
        cursor = date;
      }
      switch (event.type) {
        case FinancialEventType.fee:
          fees += event.amount.minorUnits;
        case FinancialEventType.adjustment:
          principal += event.amount.minorUnits;
          if (principal < BigInt.zero) {
            throw StateError('Adjustment makes principal negative');
          }
        case FinancialEventType.repayment:
          var payment = event.amount.minorUnits;
          final feePaid = _min(payment, fees);
          fees -= feePaid;
          payment -= feePaid;
          final interestPaid = _min(payment, interest);
          interest -= interestPaid;
          payment -= interestPaid;
          final principalPaid = _min(payment, principal);
          principal -= principalPaid;
          payment -= principalPaid;
          credit += payment;
        case FinancialEventType.reversal:
          throw StateError('Reversals must not enter active event calculation');
      }
    }
    final interestEnd = asOf.isAfter(terms.maturityDate)
        ? terms.maturityDate
        : asOf;
    if (terms.interestMethod == InterestMethod.reducingBalance) {
      if (interestEnd.isAfter(cursor)) {
        interest += _interest(principal, terms, cursor, interestEnd);
      }
    } else if (terms.interestMethod != InterestMethod.zero) {
      final end = terms.interestMethod == InterestMethod.flat
          ? terms.maturityDate
          : interestEnd;
      interest = _interest(
        terms.principal.minorUnits,
        terms,
        terms.calculationStartDate,
        end,
      );
      // Payments were allocated before fixed/simple interest was known. Reapply
      // their total in the documented fee → interest → principal order.
      fees = active
          .where((e) => e.type == FinancialEventType.fee)
          .fold(BigInt.zero, (sum, e) => sum + e.amount.minorUnits);
      final adjustments = active
          .where((e) => e.type == FinancialEventType.adjustment)
          .fold(BigInt.zero, (sum, e) => sum + e.amount.minorUnits);
      final paid = active
          .where((e) => e.type == FinancialEventType.repayment)
          .fold(BigInt.zero, (sum, e) => sum + e.amount.minorUnits);
      principal = terms.principal.minorUnits + adjustments;
      if (principal < BigInt.zero) {
        throw StateError('Adjustment makes principal negative');
      }
      credit = BigInt.zero;
      var remaining = paid;
      final feePaid = _min(remaining, fees);
      fees -= feePaid;
      remaining -= feePaid;
      final interestPaid = _min(remaining, interest);
      interest -= interestPaid;
      remaining -= interestPaid;
      final principalPaid = _min(remaining, principal);
      principal -= principalPaid;
      remaining -= principalPaid;
      credit = remaining;
    }
    Money money(BigInt value) => Money(
      minorUnits: value,
      currency: terms.principal.currency,
      scale: terms.principal.scale,
    );
    return LoanBalance(
      principalOutstanding: money(principal),
      interestOutstanding: money(interest),
      feesOutstanding: money(fees),
      credit: money(credit),
      isOverdue:
          asOf.isAfter(
            terms.maturityDate.add(Duration(days: terms.gracePeriodDays)),
          ) &&
          principal + interest + fees > BigInt.zero,
    );
  }

  static BigInt _interest(
    BigInt principal,
    FinancialTerms terms,
    DateTime from,
    DateTime to,
  ) {
    if (terms.interestMethod == InterestMethod.zero || !to.isAfter(from)) {
      return BigInt.zero;
    }
    final days = _days(from, to, terms.dayCountConvention);
    final denominatorDays =
        terms.dayCountConvention == DayCountConvention.actual360 ||
            terms.dayCountConvention == DayCountConvention.fixed30DayMonths
        ? 360
        : 365;
    // rate micros are millionths of a percent, hence 100,000,000 units = 100%.
    return divideRounded(
      principal * terms.annualRateMicros * BigInt.from(days),
      BigInt.from(100000000 * denominatorDays),
    );
  }

  static int _days(DateTime from, DateTime to, DayCountConvention convention) {
    if (convention != DayCountConvention.fixed30DayMonths) {
      return to.difference(from).inDays;
    }
    final d1 = from.day > 30 ? 30 : from.day;
    final d2 = to.day > 30 ? 30 : to.day;
    return (to.year - from.year) * 360 + (to.month - from.month) * 30 + d2 - d1;
  }

  static void _validateEvent(Money contract, FinancialEvent event) {
    if (event.amount.currency != contract.currency ||
        event.amount.scale != contract.scale ||
        event.amount.minorUnits <= BigInt.zero ||
        !_dateOnly(event.effectiveDate) ||
        !event.recordedAt.isUtc ||
        event.id.isEmpty) {
      throw ArgumentError('Invalid financial event');
    }
    if ((event.type == FinancialEventType.reversal) !=
        (event.reversesEventId != null)) {
      throw ArgumentError('Reversal reference mismatch');
    }
  }

  static BigInt _min(BigInt a, BigInt b) => a < b ? a : b;
}

bool _dateOnly(DateTime value) =>
    value.isUtc &&
    value.hour == 0 &&
    value.minute == 0 &&
    value.second == 0 &&
    value.millisecond == 0 &&
    value.microsecond == 0;
