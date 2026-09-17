import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/model/loan.dart';

void main() {
  group('Loan persistence integrity', () {
    test(
      'midnight and subsecond timestamps preserve the instant on round trip',
      () {
        final loan =
            _loan(
              interestType: InterestType.simple,
              interestRate: 0,
              durationInDays: 1,
            ).copy(
              id: 1,
              dateCreated: DateTime.utc(2026, 1, 1, 0, 0, 0, 123),
              dateFinished: DateTime.utc(2026, 1, 2),
            );
        final json = loan.toJson();
        expect(json[LoanFields.dateCreated], '2026-01-01T00:00:00.123Z');
        expect(json[LoanFields.loanAmountExact], '10000.0');
        final restored = Loan.fromJson(json);
        expect(restored.dateCreated.isAtSameMomentAs(loan.dateCreated), isTrue);
        expect(
          restored.dateFinished!.isAtSameMomentAs(loan.dateFinished!),
          isTrue,
        );
      },
    );

    test('exact principal survives a legacy numeric field loss', () {
      final loan = _loan(
        interestType: InterestType.simple,
        interestRate: 0,
        durationInDays: 1,
      );
      final json = loan.copy(id: 1).toJson()..[LoanFields.loanAmount] = 0.0;

      expect(Loan.fromJson(json).loanAmount, 10000);
    });

    test('legacy date strings retain their existing interpretation', () {
      final json = _loan(
        interestType: InterestType.simple,
        interestRate: 0,
        durationInDays: 1,
      ).copy(id: 1).toJson();
      json[LoanFields.dateCreated] = '2026-01-01 13:14:15';
      expect(Loan.fromJson(json).dateCreated, DateTime(2026, 1, 1, 13, 14, 15));
    });

    test('invalid settlement cannot mutate completion history', () {
      final loan = _loan(
        interestType: InterestType.simple,
        interestRate: 0,
        durationInDays: 1,
      );
      final finished = loan.dateFinished;
      for (final amount in [double.nan, double.infinity, -1.0]) {
        expect(
          () => loan.complete(receivedBy: 'Owner', amountReceived: amount),
          throwsArgumentError,
        );
        expect(loan.dateFinished, finished);
        expect(loan.settlementAmount, isNull);
      }
    });

    test('nonfinite financial fields cannot be persisted', () {
      final loan = _loan(
        interestType: InterestType.simple,
        interestRate: 0,
        durationInDays: 1,
      );
      for (final invalid in [
        loan.copy(loanAmount: double.nan),
        loan.copy(interestRate: double.infinity),
        loan.copy(weight: double.nan),
        loan.copy(earlyRedemptionCharge: double.infinity),
        loan.copy(settlementAmount: double.nan),
      ]) {
        expect(invalid.toJson, throwsArgumentError);
      }
    });
  });

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

    test('a future-dated loan cannot accrue negative interest', () {
      final loan = _loan(
        interestType: InterestType.simple,
        interestRate: 10,
        durationInDays: -1,
      );

      expect(loan.calculateInterest(), 0);
      expect(loan.calculateCollectable(), 10000);
    });

    test('fixed charge applies when an item is redeemed during lock-in', () {
      final loan = _loan(
        interestType: InterestType.simple,
        interestRate: 10,
        durationInDays: 6,
        lockInDays: 7,
        earlyRedemptionCharge: 500,
      );

      expect(loan.isWithinLockIn(), isTrue);
      expect(loan.calculateEarlyRedemptionCharge(), 500);
      expect(loan.calculateCollectable(), closeTo(10700, 0.001));
    });

    test('fixed charge expires at the end of the lock-in period', () {
      final loan = _loan(
        interestType: InterestType.simple,
        interestRate: 10,
        durationInDays: 7,
        lockInDays: 7,
        earlyRedemptionCharge: 500,
      );

      expect(loan.isWithinLockIn(), isFalse);
      expect(loan.calculateEarlyRedemptionCharge(), 0);
      expect(loan.calculateCollectable(), closeTo(10233.333, 0.001));
    });

    test('mortgage term is stored per loan with a legacy default', () {
      final loan = _loan(
        interestType: InterestType.simple,
        interestRate: 10,
        durationInDays: 30,
      ).copy(id: 1, mortgageTermYears: 12);
      final json = loan.toJson();

      expect(Loan.fromJson(json).mortgageTermYears, 12);

      json.remove(LoanFields.mortgageTermYears);
      expect(Loan.fromJson(json).mortgageTermYears, 5);
    });

    test('mortgage weight is stored with a legacy default', () {
      final loan = _loan(
        interestType: InterestType.simple,
        interestRate: 10,
        durationInDays: 30,
      ).copy(id: 1, weight: 18.75);
      final json = loan.toJson();

      expect(Loan.fromJson(json).weight, 18.75);

      json.remove(LoanFields.weight);
      expect(Loan.fromJson(json).weight, 0);
    });

    test('mortgage weight display preserves saved precision and unit', () {
      final loan = _loan(
        interestType: InterestType.simple,
        interestRate: 10,
        durationInDays: 30,
      ).copy(id: 1, weight: 18.755, weightUnit: 'g');

      expect(loan.formattedMortgageWeight, '18.755');
      expect(loan.formattedMortgageWeightWithUnit, '18.755 g');
      expect(Loan.formatMortgageWeightWithUnit(20, ' kg '), '20 kg');
    });

    test('delivery and client confirmation markers survive round trip', () {
      final confirmedAt = DateTime.utc(2026, 2, 3, 4, 5, 6);
      final loan =
          _loan(
            interestType: InterestType.simple,
            interestRate: 0,
            durationInDays: 1,
          ).copy(
            id: 1,
            syncState: Loan.serverSaved,
            clientConfirmedAt: confirmedAt,
          );

      final restored = Loan.fromJson(loan.toJson());

      expect(restored.isServerSaved, isTrue);
      expect(restored.isClientConfirmed, isTrue);
      expect(restored.clientConfirmedAt!.isAtSameMomentAs(confirmedAt), isTrue);
    });

    test('legacy records default to locally saved', () {
      final json =
          _loan(
              interestType: InterestType.simple,
              interestRate: 0,
              durationInDays: 1,
            ).copy(id: 1).toJson()
            ..remove(LoanFields.syncState)
            ..remove(LoanFields.clientConfirmedAt);

      final restored = Loan.fromJson(json);

      expect(restored.isServerSaved, isFalse);
      expect(restored.isClientConfirmed, isFalse);
    });
  });
}

Loan _loan({
  required InterestType interestType,
  required double interestRate,
  required int durationInDays,
  int lockInDays = 0,
  double earlyRedemptionCharge = 0,
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
    lockInDays: lockInDays,
    earlyRedemptionCharge: earlyRedemptionCharge,
    additionalDetails: '',
    familyRelationId: 1,
    mortgageMaterialId: 1,
    dateCreated: created,
    dateFinished: created.add(Duration(days: durationInDays)),
  );
}
