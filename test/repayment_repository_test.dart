import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/domain/financial_engine.dart';
import 'package:loanx/domain/money.dart';
import 'package:loanx/service/database_helper.dart';
import 'package:loanx/service/repayment_repository.dart';

void main() {
  late Database db;
  late RepaymentRepository repository;
  final date = DateTime.utc(2026, 9, 14);

  setUp(() async {
    db = await DatabaseHelper.instance.openMemory(
      name: 'repayment-test-${DateTime.now().microsecondsSinceEpoch}',
    );
    await db.insert('localOwners', {
      'id': 'owner',
      'selfPartyId': 'self',
      'createdAt': date.toIso8601String(),
    });
    await db.insert('loans', {
      'uid': 'loan-1',
      'ownerId': 'owner',
      'lenderPartyId': 'self',
      'borrowerPartyId': 'other',
      'currency': 'INR',
    });
    await db.insert('loans', {
      'uid': 'loan-2',
      'ownerId': 'other-owner',
      'lenderPartyId': 'x',
      'borrowerPartyId': 'y',
      'currency': 'INR',
    });
    repository = RepaymentRepository(db, ownerId: 'owner', actorId: 'self');
  });

  tearDown(() => db.close());

  test('repayment and audit commit together and retry is idempotent', () async {
    final amount = Money.parse('125.50', currency: 'INR');
    final first = await repository.recordRepayment(
      loanUid: 'loan-1',
      amount: amount,
      paymentDate: date,
      paymentMethod: PaymentMethod.upi,
      referenceNumber: 'UPI-1',
      operationId: 'op-1',
    );
    final retry = await repository.recordRepayment(
      loanUid: 'loan-1',
      amount: amount,
      paymentDate: date,
      paymentMethod: PaymentMethod.upi,
      referenceNumber: 'UPI-1',
      operationId: 'op-1',
    );
    expect(retry.id, first.id);
    expect(await db.query('financialEvents'), hasLength(1));
    final audit = await db.query('auditEvents');
    expect(audit, hasLength(1));
    expect(audit.single['action'], 'REPAYMENT_CREATED');
  });

  test('same operation ID with different payload fails explicitly', () async {
    await repository.recordRepayment(
      loanUid: 'loan-1',
      amount: Money.parse('1.00', currency: 'INR'),
      paymentDate: date,
      paymentMethod: PaymentMethod.cash,
      operationId: 'same',
    );
    await expectLater(
      repository.recordRepayment(
        loanUid: 'loan-1',
        amount: Money.parse('2.00', currency: 'INR'),
        paymentDate: date,
        paymentMethod: PaymentMethod.cash,
        operationId: 'same',
      ),
      throwsStateError,
    );
    expect(await db.query('financialEvents'), hasLength(1));
  });

  test(
    'owner scope prevents cross-workspace financial writes and reads',
    () async {
      await expectLater(
        repository.recordRepayment(
          loanUid: 'loan-2',
          amount: Money.parse('1.00', currency: 'INR'),
          paymentDate: date,
          paymentMethod: PaymentMethod.cash,
        ),
        throwsStateError,
      );
      await expectLater(repository.listForLoan('loan-2'), throwsStateError);
      expect(await db.query('financialEvents'), isEmpty);
    },
  );

  test(
    'reversal is append-only, references original, and cannot duplicate',
    () async {
      final original = await repository.recordRepayment(
        loanUid: 'loan-1',
        amount: Money.parse('10.00', currency: 'INR'),
        paymentDate: date,
        paymentMethod: PaymentMethod.bankTransfer,
      );
      final reversal = await repository.reverseRepayment(
        eventId: original.id,
        effectiveDate: date.add(const Duration(days: 1)),
        reason: 'Bank transfer was returned',
        operationId: 'reverse-1',
      );
      expect(reversal.type, FinancialEventType.reversal);
      expect(reversal.reversesEventId, original.id);
      await expectLater(
        repository.reverseRepayment(
          eventId: original.id,
          effectiveDate: date.add(const Duration(days: 2)),
          reason: 'Again',
          operationId: 'reverse-2',
        ),
        throwsStateError,
      );
      expect(await db.query('financialEvents'), hasLength(2));
      expect(await db.query('auditEvents'), hasLength(2));
    },
  );

  test('repayment currency must match its loan', () async {
    await expectLater(
      repository.recordRepayment(
        loanUid: 'loan-1',
        amount: Money.parse('1.00', currency: 'USD'),
        paymentDate: date,
        paymentMethod: PaymentMethod.cash,
      ),
      throwsArgumentError,
    );
    expect(await db.query('financialEvents'), isEmpty);
  });
}
