import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/domain/connected.dart';
import 'package:loanx/domain/financial_engine.dart';
import 'package:loanx/domain/money.dart';
import 'package:loanx/features/borrower/find_lender_screen.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/service/currency_presentation.dart';
import 'package:loanx/service/auth_client.dart';
import 'package:loanx/widget/empty_state.dart';
import 'package:loanx/src/rust/api/network.dart' as network;

class BorrowerLoanSummary {
  const BorrowerLoanSummary({
    required this.loan,
    required this.loanUid,
    required this.lenderPartyId,
    required this.lenderName,
    this.repayments = const [],
  });

  final Loan loan;
  final String loanUid;
  final String lenderPartyId;
  final String lenderName;
  final List<network.SharedRepayment> repayments;
}

class BorrowerDashboardData {
  const BorrowerDashboardData({
    required this.loans,
    required this.notifications,
  });

  final List<BorrowerLoanSummary> loans;
  final List<LoanNotification> notifications;
}

/// Connected loans where the current device owner is the borrower, together
/// with notifications that are explicitly tied to those loans/relationships.
final borrowerDashboardProvider = FutureProvider<BorrowerDashboardData>((
  ref,
) async {
  // Refresh after local loan writes or a sync updates the shared loan cache.
  ref.watch(loanListProvider);
  final dashboard = await loadBorrowerDashboard(
    await ref.read(dBProvider.future),
  );
  // Connected loans are an optional cloud enhancement. A local-only build
  // may not have the Dart defines required by AuthClient, but that must not
  // make the local borrower dashboard look broken or emit a retry loop.
  if (!AuthClient.hasServerConfiguration) return dashboard;
  try {
    final shared = await AuthClient().listSharedLoans();
    final remote = shared.map((item) {
      final scale = item.currencyScale.clamp(0, 6);
      final principal = item.principalMinor / _power10(scale);
      return BorrowerLoanSummary(
        loan: Loan(
          depositorName: 'LoanX lender',
          phoneNumber: '',
          relativeName: '',
          address: '',
          loanAmount: principal,
          currency: item.currency,
          interestRate: 0,
          interestType: 0,
          interestFrequency: 0,
          additionalDetails: 'Shared loan',
          familyRelationId: 0,
          mortgageMaterialId: 0,
          dateCreated: DateTime.tryParse(item.loanDate) ?? DateTime.now(),
        ),
        loanUid: item.loanId,
        lenderPartyId: item.lenderPartyId,
        lenderName: 'LoanX lender',
        repayments: item.repayments,
      );
    }).toList();
    return BorrowerDashboardData(
      loans: [...dashboard.loans, ...remote],
      notifications: dashboard.notifications,
    );
  } catch (error, stackTrace) {
    debugPrint('Borrower shared-loan refresh failed: $error');
    if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
    return dashboard;
  }
});

double _power10(int scale) {
  var value = 1.0;
  for (var i = 0; i < scale; i++) {
    value *= 10;
  }
  return value;
}

Future<BorrowerDashboardData> loadBorrowerDashboard(Database db) async {
  final owners = await db.query('localOwners');
  if (owners.length != 1) {
    return const BorrowerDashboardData(loans: [], notifications: []);
  }

  final ownerId = owners.single['id'];
  final selfPartyId = owners.single['selfPartyId'];
  if (ownerId is! String ||
      ownerId.isEmpty ||
      selfPartyId is! String ||
      selfPartyId.isEmpty) {
    return const BorrowerDashboardData(loans: [], notifications: []);
  }

  final loanRows = await db.query(
    Loan.tableName,
    where: 'ownerId = ? AND borrowerPartyId = ?',
    whereArgs: [ownerId, selfPartyId],
    orderBy: '${LoanFields.dateCreated} DESC',
  );
  final loans = <BorrowerLoanSummary>[];
  final visibleEntityIds = <String>{};

  for (final row in loanRows) {
    final relationshipId = row['relationshipId'];
    final lenderPartyId = row['lenderPartyId'];
    final loanUid = row['uid'];
    if (relationshipId is! String ||
        relationshipId.isEmpty ||
        lenderPartyId is! String ||
        lenderPartyId.isEmpty ||
        loanUid is! String ||
        loanUid.isEmpty) {
      continue;
    }

    final relationships = await db.query(
      'relationships',
      where: 'id = ? AND ownerId = ? AND status = ?',
      whereArgs: [relationshipId, ownerId, 'ACTIVE'],
    );
    if (relationships.length != 1) continue;
    final relationship = relationships.single;
    if (!((relationship['partyAId'] == selfPartyId &&
            relationship['partyBId'] == lenderPartyId) ||
        (relationship['partyBId'] == selfPartyId &&
            relationship['partyAId'] == lenderPartyId))) {
      continue;
    }

    final shares = await db.query(
      'sharedResources',
      where:
          'ownerId = ? AND loanUid = ? AND recipientPartyId = ? AND resourceType = ? AND resourceId = ?',
      whereArgs: [ownerId, loanUid, selfPartyId, 'LOAN', loanUid],
    );
    if (!shares.any((share) => share['revokedAt'] == null)) continue;

    final lenders = await db.query(
      'parties',
      where: 'id = ? AND ownerId = ? AND status = ?',
      whereArgs: [lenderPartyId, ownerId, 'ACTIVE'],
    );
    if (lenders.length != 1) continue;
    final lender = lenders.single;
    final lenderUserId = lender['userId'];
    if (lenderUserId is! String || lenderUserId.isEmpty) continue;

    final eventRows = await db.query(
      'financialEvents',
      where: 'ownerId = ? AND loanUid = ?',
      whereArgs: [ownerId, loanUid],
      orderBy: 'effectiveDate, recordedAt, id',
    );
    loans.add(
      BorrowerLoanSummary(
        loan: Loan.fromJson(row),
        loanUid: loanUid,
        lenderPartyId: lenderPartyId,
        lenderName:
            (lender['displayName'] as String?)?.trim().isNotEmpty == true
            ? (lender['displayName'] as String).trim()
            : 'LoanX lender'.tr(),
        repayments: eventRows.map(_localRepayment).toList(growable: false),
      ),
    );
    visibleEntityIds.addAll([loanUid, relationshipId, lenderPartyId]);
  }

  if (visibleEntityIds.isEmpty) {
    return BorrowerDashboardData(loans: loans, notifications: const []);
  }

  final notificationRows = await db.query(
    'notifications',
    where: 'ownerId = ? AND recipientPartyId = ?',
    whereArgs: [ownerId, selfPartyId],
    orderBy: 'createdAt DESC, id DESC',
  );
  final notifications = notificationRows
      .where((row) => visibleEntityIds.contains(row['entityId']))
      .map(
        (row) => LoanNotification(
          id: row['id'] as String,
          type: row['type'] as String,
          title: row['title'] as String,
          body: row['body'] as String,
          entityType: row['entityType'] as String?,
          entityId: row['entityId'] as String?,
          createdAt: DateTime.parse(row['createdAt'] as String),
          readAt: row['readAt'] == null
              ? null
              : DateTime.parse(row['readAt'] as String),
        ),
      )
      .toList(growable: false);

  return BorrowerDashboardData(loans: loans, notifications: notifications);
}

network.SharedRepayment _localRepayment(Map<String, Object?> row) =>
    network.SharedRepayment(
      id: row['id'] as String,
      eventType: row['type'] as String,
      amountMinor: BigInt.parse(row['amountMinor'] as String).toInt(),
      currency: row['currency'] as String,
      currencyScale: (row['currencyScale'] as num).toInt(),
      paymentDate: (row['effectiveDate'] as String).substring(0, 10),
      recordedAt: row['recordedAt'] as String,
      paymentMethod: row['paymentMethod'] as String? ?? '',
      reversesEventId: row['reversesEventId'] as String? ?? '',
    );

class BorrowerHome extends ConsumerWidget {
  const BorrowerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(borrowerDashboardProvider);
    return Scaffold(
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Loans could not be loaded',
          message: 'Please restart the app and try again.',
        ),
        data: (data) =>
            _BorrowerDashboard(data: data, onRefresh: () => _refresh(ref)),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(borrowerDashboardProvider);
    await ref.read(borrowerDashboardProvider.future);
  }
}

class _BorrowerDashboard extends StatelessWidget {
  const _BorrowerDashboard({required this.data, required this.onRefresh});

  final BorrowerDashboardData data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final active = data.loans.where((item) => !item.loan.isFinished()).toList();
    final byLender = <String, List<BorrowerLoanSummary>>{};
    for (final item in data.loans) {
      byLender.putIfAbsent(item.lenderPartyId, () => []).add(item);
    }
    final interestTotals = _totals(active, (loan) => loan.calculateInterest());
    final amountDueTotals = _totals(
      active,
      (loan) => loan.calculateCollectable(),
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My loans'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _LoanSummaryCard(
                    activeCount: active.length,
                    interest: interestTotals,
                    amountDue: amountDueTotals,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('find-lenders'),
                      icon: const Icon(Icons.travel_explore_rounded),
                      label: Text('Find lenders near you'.tr()),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FindLenderScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'My lenders'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (byLender.isEmpty)
                    Text('No connected lenders'.tr())
                  else
                    ...byLender.values.map((loans) {
                      final openLoans = loans
                          .where((item) => !item.loan.isFinished())
                          .toList();
                      return Card(
                        child: ExpansionTile(
                          title: Text(loans.first.lenderName),
                          subtitle: Text(
                            '${loans.length} ${'loans'.tr()} · '
                            '${'Amount due'.tr()}: '
                            '${_totals(openLoans, (loan) => loan.calculateCollectable())}',
                          ),
                          children: [
                            for (final item in loans) _LoanCard(item: item),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  Text(
                    'Lender notifications'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (data.notifications.isEmpty)
                    Text('No lender notifications'.tr())
                  else
                    ...data.notifications.map(
                      (notification) =>
                          _NotificationTile(notification: notification),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Loans from LoanX lenders'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          if (data.loans.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No connected loans'.tr(),
                message:
                    'Loans issued to you by connected LoanX lenders will appear here.'
                        .tr(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              sliver: SliverList.builder(
                itemCount: data.loans.length,
                itemBuilder: (context, index) =>
                    _LoanCard(item: data.loans[index]),
              ),
            ),
        ],
      ),
    );
  }

  String _totals(
    List<BorrowerLoanSummary> items,
    num Function(Loan loan) value,
  ) {
    final totals = <String, num>{};
    for (final item in items) {
      totals.update(
        item.loan.currency,
        (current) => current + value(item.loan),
        ifAbsent: () => value(item.loan),
      );
    }
    return totals.entries
        .map((entry) => CurrencyPresentation.format(entry.value, entry.key))
        .join(' · ');
  }
}

class _LoanSummaryCard extends StatelessWidget {
  const _LoanSummaryCard({
    required this.activeCount,
    required this.interest,
    required this.amountDue,
  });

  final int activeCount;
  final String interest;
  final String amountDue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount due'.tr(),
            style: TextStyle(color: colors.onPrimary.withValues(alpha: .8)),
          ),
          const SizedBox(height: 4),
          Text(
            amountDue.isEmpty ? '—' : amountDue,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${'Calculated interest'.tr()}: ${interest.isEmpty ? '—' : interest}',
            style: TextStyle(color: colors.onPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '$activeCount ${'Active loans'.tr()}',
            style: TextStyle(color: colors.onPrimary.withValues(alpha: .8)),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final LoanNotification notification;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(
        notification.readAt == null
            ? Icons.notifications_active_outlined
            : Icons.notifications_none_rounded,
      ),
      title: Text(notification.title),
      subtitle: Text(notification.body),
      trailing: notification.readAt == null
          ? const Icon(Icons.circle, size: 10)
          : null,
    ),
  );
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.item});

  final BorrowerLoanSummary item;

  @override
  Widget build(BuildContext context) {
    final loan = item.loan;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Text(item.lenderName.characters.first.toUpperCase()),
        ),
        title: Text(item.lenderName),
        subtitle: Text(
          '${'Interest'.tr()}: ${CurrencyPresentation.format(loan.calculateInterest(), loan.currency)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyPresentation.format(
                loan.calculateCollectable(),
                loan.currency,
              ),
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(loan.isFinished() ? 'Closed'.tr() : 'Active'.tr()),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _BorrowerLoanDetails(item: item)),
        ),
      ),
    );
  }
}

class _BorrowerLoanDetails extends StatelessWidget {
  const _BorrowerLoanDetails({required this.item});

  final BorrowerLoanSummary item;

  @override
  Widget build(BuildContext context) {
    final loan = item.loan;
    final date = DateFormat.yMMMd(context.locale.toString());
    final repaid = _netRepayments(item.repayments);
    return Scaffold(
      appBar: AppBar(title: Text('Loan details'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _DetailRow(label: 'Lender'.tr(), value: item.lenderName),
          _DetailRow(
            label: 'Principal'.tr(),
            value: CurrencyPresentation.format(loan.loanAmount, loan.currency),
          ),
          _DetailRow(
            label: 'Calculated interest'.tr(),
            value: CurrencyPresentation.format(
              loan.calculateInterest(),
              loan.currency,
            ),
          ),
          _DetailRow(
            label: 'Amount due'.tr(),
            value: CurrencyPresentation.format(
              loan.calculateCollectable(),
              loan.currency,
            ),
          ),
          _DetailRow(
            label: 'Recorded repayments'.tr(),
            value: Money(
              minorUnits: repaid,
              currency: loan.currency,
              scale: CurrencyPresentation.fractionDigits(loan.currency),
            ).toString(),
          ),
          _DetailRow(
            label: 'Interest rate'.tr(),
            value: '${loan.interestRate}%',
          ),
          _DetailRow(
            label: 'Interest type'.tr(),
            value: InterestType.values[loan.interestType].name.tr(),
          ),
          _DetailRow(
            label: 'Loan date'.tr(),
            value: date.format(loan.dateCreated),
          ),
          _DetailRow(
            label: 'Status'.tr(),
            value: loan.isFinished() ? 'Closed'.tr() : 'Active'.tr(),
          ),
          const SizedBox(height: 16),
          Text(
            'Repayment history'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (item.repayments.isEmpty)
            Text('No repayments recorded'.tr())
          else
            ...item.repayments.map(
              (repayment) => Card(
                child: ListTile(
                  leading: Icon(
                    repayment.eventType == FinancialEventType.reversal.name
                        ? Icons.undo_rounded
                        : Icons.payments_outlined,
                  ),
                  title: Text(
                    repayment.eventType == FinancialEventType.reversal.name
                        ? 'Repayment reversed'.tr()
                        : 'Repayment'.tr(),
                  ),
                  subtitle: Text(_formatRepaymentDate(repayment.paymentDate)),
                  trailing: Text(
                    Money(
                      minorUnits: BigInt.from(repayment.amountMinor),
                      currency: repayment.currency,
                      scale: repayment.currencyScale,
                    ).toString(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

BigInt _netRepayments(List<network.SharedRepayment> repayments) {
  final reversed = repayments
      .where((item) => item.eventType == FinancialEventType.reversal.name)
      .map((item) => item.reversesEventId)
      .where((id) => id.isNotEmpty)
      .toSet();
  return repayments
      .where((item) => item.eventType == FinancialEventType.repayment.name)
      .where((item) => !reversed.contains(item.id))
      .fold(
        BigInt.zero,
        (total, item) => total + BigInt.from(item.amountMinor),
      );
}

String _formatRepaymentDate(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null ? value : DateFormat.yMMMd().format(parsed.toLocal());
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
