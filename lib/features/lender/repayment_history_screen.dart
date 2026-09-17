import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/domain/financial_engine.dart';
import 'package:loanx/domain/money.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/service/currency_presentation.dart';
import 'package:loanx/service/auth_client.dart';
import 'package:loanx/service/repayment_repository.dart';

/// An append-only payment ledger for an existing lender-recorded loan.
///
/// Historical loans still calculate their legacy interest separately. This
/// screen deliberately shows the exact recorded repayment ledger without
/// claiming that it converts legacy terms into a new financial contract.
class RepaymentHistoryScreen extends StatefulWidget {
  const RepaymentHistoryScreen({
    super.key,
    required this.database,
    required this.loan,
  });

  final Database database;
  final Loan loan;

  @override
  State<RepaymentHistoryScreen> createState() => _RepaymentHistoryScreenState();
}

class _RepaymentHistoryScreenState extends State<RepaymentHistoryScreen> {
  late Future<_LedgerContext> _context;
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _context = _load();
  }

  Future<_LedgerContext> _load() async {
    final owners = await widget.database.query('localOwners');
    if (owners.length != 1 || owners.single['id'] is! String) {
      throw StateError('Local workspace is unavailable');
    }
    final ownerId = owners.single['id'] as String;
    final rows = await widget.database.query(
      Loan.tableName,
      columns: ['uid', 'currency', 'lenderPartyId'],
      where: 'id = ? AND ownerId = ?',
      whereArgs: [widget.loan.id, ownerId],
      limit: 1,
    );
    if (rows.length != 1 || rows.single['uid'] is! String) {
      throw StateError('Loan is unavailable in this workspace');
    }
    final uid = rows.single['uid'] as String;
    final repository = RepaymentRepository(
      widget.database,
      ownerId: ownerId,
      actorId: ownerId,
    );
    return _LedgerContext(
      repository: repository,
      loanUid: uid,
      currency: rows.single['currency'] as String? ?? widget.loan.currency,
      events: await repository.listForLoan(uid),
      canManage: rows.single['lenderPartyId'] == owners.single['selfPartyId'],
    );
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _context = _load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Repayment history'.tr())),
    floatingActionButton: FutureBuilder<_LedgerContext>(
      future: _context,
      builder: (context, snapshot) =>
          snapshot.hasData && snapshot.requireData.canManage
          ? FloatingActionButton.extended(
              heroTag: 'repayment-history-record',
              onPressed: _isMutating
                  ? null
                  : () => _record(snapshot.requireData),
              icon: const Icon(Icons.add_card_outlined),
              label: Text('Record repayment'.tr()),
            )
          : const SizedBox.shrink(),
    ),
    body: FutureBuilder<_LedgerContext>(
      future: _context,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Repayment history could not be loaded'.tr()),
          );
        }
        final ledger = snapshot.requireData;
        final repaid = _netRepayments(ledger.events);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                title: Text('Recorded repayments'.tr()),
                subtitle: Text(
                  'Legacy interest remains on the existing loan record until it is migrated to versioned terms.'
                      .tr(),
                ),
                trailing: Text(
                  Money(
                    minorUnits: repaid,
                    currency: ledger.currency,
                    scale: CurrencyPresentation.fractionDigits(ledger.currency),
                  ).toString(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (ledger.events.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('No repayments recorded'.tr())),
              )
            else
              ...ledger.events.map(
                (event) => _EventTile(
                  event: event,
                  currency: ledger.currency,
                  onReverse:
                      ledger.canManage &&
                          event.type == FinancialEventType.repayment
                      ? () => _reverse(ledger, event)
                      : null,
                ),
              ),
          ],
        );
      },
    ),
  );

  BigInt _netRepayments(List<FinancialEvent> events) {
    final reversed = events
        .where((event) => event.type == FinancialEventType.reversal)
        .map((event) => event.reversesEventId)
        .whereType<String>()
        .toSet();
    return events
        .where((event) => event.type == FinancialEventType.repayment)
        .where((event) => !reversed.contains(event.id))
        .fold(BigInt.zero, (total, event) => total + event.amount.minorUnits);
  }

  Future<void> _record(_LedgerContext ledger) async {
    if (_isMutating || !mounted) return;
    final amount = TextEditingController();
    var method = PaymentMethod.cash;
    final result = await showDialog<_PaymentDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Record repayment'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: 'Amount'.tr()),
              ),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: method,
                items: PaymentMethod.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.name.tr()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => method = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _PaymentDraft(amount.text.trim(), method),
              ),
              child: Text('Save'.tr()),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    if (result == null) return;
    if (!mounted) return;
    setState(() => _isMutating = true);
    try {
      final money = Money.parse(
        result.amount,
        currency: ledger.currency,
        scale: CurrencyPresentation.fractionDigits(ledger.currency),
      );
      await ledger.repository.recordRepayment(
        loanUid: ledger.loanUid,
        amount: money,
        paymentDate: _today(),
        paymentMethod: result.method,
      );
      await AuthClient().flushPendingFinancialEvents(database: widget.database);
      _reload();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Repayment could not be recorded'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _reverse(_LedgerContext ledger, FinancialEvent event) async {
    if (_isMutating || !mounted) return;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reverse repayment'.tr()),
        content: TextField(
          controller: reason,
          decoration: InputDecoration(labelText: 'Reason'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Reverse'.tr()),
          ),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _isMutating = true);
    try {
      await ledger.repository.reverseRepayment(
        eventId: event.id,
        effectiveDate: _today(),
        reason: text,
      );
      await AuthClient().flushPendingFinancialEvents(database: widget.database);
      _reload();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Repayment could not be reversed'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  DateTime _today() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }
}

class _LedgerContext {
  const _LedgerContext({
    required this.repository,
    required this.loanUid,
    required this.currency,
    required this.events,
    required this.canManage,
  });
  final RepaymentRepository repository;
  final String loanUid;
  final String currency;
  final List<FinancialEvent> events;
  final bool canManage;
}

class _PaymentDraft {
  const _PaymentDraft(this.amount, this.method);
  final String amount;
  final PaymentMethod method;
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.currency,
    this.onReverse,
  });
  final FinancialEvent event;
  final String currency;
  final VoidCallback? onReverse;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        event.type == FinancialEventType.reversal
            ? Icons.undo_rounded
            : Icons.payments_outlined,
      ),
      title: Text(
        event.type == FinancialEventType.reversal
            ? 'Repayment reversed'.tr()
            : 'Repayment'.tr(),
      ),
      subtitle: Text(DateFormat.yMMMd().format(event.effectiveDate.toLocal())),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${event.amount.currency} ${event.amount}'),
          if (onReverse != null)
            IconButton(
              tooltip: 'Reverse repayment'.tr(),
              onPressed: onReverse,
              icon: const Icon(Icons.undo_rounded),
            ),
        ],
      ),
    ),
  );
}
