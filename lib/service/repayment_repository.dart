import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../db/tostore_database.dart';
import '../domain/financial_engine.dart';
import '../domain/money.dart';
import '../domain/party.dart';

enum PaymentMethod { cash, bankTransfer, upi, cheque, other }

/// Owner-scoped, append-only local financial event store. Each write and its
/// audit record commit in one transaction. The operation ID is safe to retain
/// when the event is later replayed to a server.
final class RepaymentRepository {
  RepaymentRepository(
    this.database, {
    required this.ownerId,
    required this.actorId,
  });

  final Database database;
  final String ownerId;
  final String actorId;

  Future<FinancialEvent> recordRepayment({
    required String loanUid,
    required Money amount,
    required DateTime paymentDate,
    required PaymentMethod paymentMethod,
    String? referenceNumber,
    String? notes,
    String? operationId,
  }) => _append(
    loanUid: loanUid,
    amount: amount,
    effectiveDate: paymentDate,
    type: FinancialEventType.repayment,
    paymentMethod: paymentMethod.name,
    referenceNumber: referenceNumber,
    notes: notes,
    operationId: operationId,
  );

  Future<FinancialEvent> reverseRepayment({
    required String eventId,
    required DateTime effectiveDate,
    required String reason,
    String? operationId,
  }) async {
    final boundedReason = _bounded(reason, 500, required: true)!;
    final original = await _getOwned(eventId);
    if (original.type != FinancialEventType.repayment) {
      throw StateError('Only repayments can be reversed');
    }
    return _append(
      loanUid: await _loanUid(eventId),
      amount: original.amount,
      effectiveDate: effectiveDate,
      type: FinancialEventType.reversal,
      notes: boundedReason,
      reversesEventId: eventId,
      operationId: operationId,
    );
  }

  Future<List<FinancialEvent>> listForLoan(String loanUid) async {
    await _requireLoan(database, loanUid);
    final rows = await database.query(
      'financialEvents',
      where: 'ownerId = ? AND loanUid = ?',
      whereArgs: [ownerId, loanUid],
      orderBy: 'effectiveDate, recordedAt, id',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<FinancialEvent> _append({
    required String loanUid,
    required Money amount,
    required DateTime effectiveDate,
    required FinancialEventType type,
    String? paymentMethod,
    String? referenceNumber,
    String? notes,
    String? reversesEventId,
    String? operationId,
  }) async {
    if (!_dateOnly(effectiveDate) || amount.minorUnits <= BigInt.zero) {
      throw ArgumentError(
        'Amount must be positive and payment date must be UTC date-only',
      );
    }
    final id = operationId ?? domainId();
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(id)) {
      throw ArgumentError('Invalid operation ID');
    }
    final reference = _bounded(referenceNumber, 200);
    final safeNotes = _bounded(notes, 1000);
    final payload = <String, Object?>{
      'loanUid': loanUid,
      'type': type.name,
      'amountMinor': amount.minorUnits.toString(),
      'currency': amount.currency,
      'currencyScale': amount.scale,
      'effectiveDate': effectiveDate.toIso8601String(),
      'paymentMethod': paymentMethod,
      'referenceNumber': reference,
      'notes': safeNotes,
      'reversesEventId': reversesEventId,
    };
    final syncPayload = <String, Object?>{
      'loan_id': loanUid,
      'type': type.name,
      'amount_minor': amount.minorUnits.toString(),
      'currency': amount.currency,
      'currency_scale': amount.scale,
      'effective_date': _dateString(effectiveDate),
      'payment_method': paymentMethod,
      'reference_number': reference,
      'reverses_event_id': reversesEventId,
      'reason': safeNotes,
    };
    final hash = sha256.convert(utf8.encode(jsonEncode(payload))).toString();
    return database.transaction((tx) async {
      await _requireLoan(tx, loanUid, currency: amount.currency);
      final loanRows = await tx.query(
        'loans',
        columns: ['loanAmountExact', 'loanAmount', 'dateCreated'],
        where: 'uid = ? AND ownerId = ?',
        whereArgs: [loanUid, ownerId],
        limit: 1,
      );
      final loanRow = loanRows.single;
      String? principalMinor;
      try {
        final principal =
            loanRow['loanAmountExact'] as String? ??
            (loanRow['loanAmount'] as num).toString();
        principalMinor = Money.parse(
          principal,
          currency: amount.currency,
          scale: amount.scale,
        ).minorUnits.toString();
      } catch (_) {
        // Legacy rows without a parseable principal can still sync when their
        // stable UUID is available.
      }
      final queuePayload = <String, Object?>{
        ...syncPayload,
        'principal_minor': principalMinor,
        'loan_date': (loanRow['dateCreated'] as String?)?.substring(0, 10),
      };
      final previous = await tx.query(
        'financialEvents',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (previous.isNotEmpty) {
        if (previous.single['ownerId'] != ownerId ||
            previous.single['payloadHash'] != hash) {
          throw StateError('Operation ID was already used with different data');
        }
        return _fromRow(previous.single);
      }
      if (reversesEventId != null) {
        final originalRows = await tx.query(
          'financialEvents',
          where: 'id = ? AND ownerId = ?',
          whereArgs: [reversesEventId, ownerId],
        );
        if (originalRows.length != 1 ||
            originalRows.single['type'] != FinancialEventType.repayment.name ||
            originalRows.single['loanUid'] != loanUid ||
            originalRows.single['amountMinor'] !=
                amount.minorUnits.toString()) {
          throw StateError('Original repayment is unavailable or incompatible');
        }
        final reversals = await tx.query(
          'financialEvents',
          where: 'ownerId = ? AND reversesEventId = ?',
          whereArgs: [ownerId, reversesEventId],
        );
        if (reversals.isNotEmpty) {
          throw StateError('Repayment is already reversed');
        }
      }
      final recordedAt = DateTime.now().toUtc();
      final row = <String, Object?>{
        'id': id,
        'ownerId': ownerId,
        ...payload,
        'recordedAt': recordedAt.toIso8601String(),
        'createdBy': actorId,
        'payloadHash': hash,
      };
      await tx.insert('financialEvents', row);
      await tx.insert('auditEvents', {
        'id': domainId(),
        'ownerId': ownerId,
        'actorId': actorId,
        'entityType': 'FINANCIAL_EVENT',
        'entityId': id,
        'action': type == FinancialEventType.reversal
            ? 'REPAYMENT_REVERSED'
            : 'REPAYMENT_CREATED',
        'occurredAt': recordedAt.toIso8601String(),
        'correlationId': id,
      });
      final now = recordedAt.toIso8601String();
      await tx.insert('pendingFinancialEvents', {
        'id': id,
        'eventId': id,
        'loanUid': loanUid,
        'payloadJson': jsonEncode(queuePayload),
        'status': 'PENDING',
        'attemptCount': 0,
        'createdAt': now,
        'updatedAt': now,
      });
      return _fromRow(row);
    });
  }

  Future<void> _requireLoan(
    DatabaseExecutor tx,
    String loanUid, {
    String? currency,
  }) async {
    final rows = await tx.query(
      'loans',
      columns: ['uid', 'currency'],
      where: 'uid = ? AND ownerId = ?',
      whereArgs: [loanUid, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Loan is unavailable in this workspace');
    }
    if (currency != null && rows.single['currency'] != currency) {
      throw ArgumentError('Repayment currency must match the loan currency');
    }
  }

  Future<FinancialEvent> _getOwned(String id) async {
    final rows = await database.query(
      'financialEvents',
      where: 'id = ? AND ownerId = ?',
      whereArgs: [id, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Financial event is unavailable in this workspace');
    }
    return _fromRow(rows.single);
  }

  Future<String> _loanUid(String id) async {
    final rows = await database.query(
      'financialEvents',
      columns: ['loanUid'],
      where: 'id = ? AND ownerId = ?',
      whereArgs: [id, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Financial event is unavailable in this workspace');
    }
    return rows.single['loanUid'] as String;
  }

  static FinancialEvent _fromRow(Map<String, Object?> row) => FinancialEvent(
    id: row['id'] as String,
    type: FinancialEventType.values.byName(row['type'] as String),
    amount: Money(
      minorUnits: BigInt.parse(row['amountMinor'] as String),
      currency: row['currency'] as String,
      scale: (row['currencyScale'] as num).toInt(),
    ),
    effectiveDate: DateTime.parse(row['effectiveDate'] as String),
    recordedAt: DateTime.parse(row['recordedAt'] as String),
    reversesEventId: row['reversesEventId'] as String?,
  );

  static String? _bounded(String? value, int max, {bool required = false}) {
    final result = value?.trim();
    if (result == null || result.isEmpty) {
      if (required) throw ArgumentError('Value is required');
      return null;
    }
    if (result.length > max ||
        RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(result)) {
      throw ArgumentError('Value is invalid');
    }
    return result;
  }

  static bool _dateOnly(DateTime value) =>
      value.isUtc &&
      value.hour == 0 &&
      value.minute == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0;

  static String _dateString(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
