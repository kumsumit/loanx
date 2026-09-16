import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/service/auth_client.dart';
import 'package:loanx/service/database_helper.dart';

void main() {
  test('a local lender share is durable until account connection', () async {
    final db = await DatabaseHelper.instance.openMemory(
      name: 'pending-share-${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(db.close);

    await AuthClient().queuePendingLoanShare(
      borrowerPhoneE164: '+919876543210',
      borrowerName: 'Borrower',
      operationId: 'operation-1',
      loanPayload: const {
        'principal_minor': 125000,
        'currency': 'INR',
        'currency_scale': 2,
        'loan_date': '2026-09-17',
      },
      database: db,
    );

    final rows = await db.query(
      'pendingLoanShares',
      where: 'operationId = ?',
      whereArgs: ['operation-1'],
    );
    expect(rows, hasLength(1));
    expect(rows.single['status'], 'PENDING');
    expect(rows.single['borrowerPhoneE164'], '+919876543210');
    expect(rows.single['loanPayloadJson'], contains('125000'));
  });
}
