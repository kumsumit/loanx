import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/features/lender/loan_details.dart';
import 'package:loanx/service/currency_presentation.dart';
import 'package:loanx/widget/empty_state.dart';

/// Loans where the current device owner is the borrower.
///
/// The direction is read from the canonical party IDs, so lender-side records
/// are never shown in the borrower's "My loans" area.
final borrowerLoansProvider = FutureProvider<List<Loan>>((ref) async {
  // Keep this feature in sync after local loan writes performed by the shared
  // repository, including offline writes.
  ref.watch(loanListProvider);
  final Database db = await ref.read(dBProvider.future);
  final owners = await db.query('localOwners');
  if (owners.length != 1) return const [];
  final selfPartyId = owners.single['selfPartyId'];
  if (selfPartyId is! String || selfPartyId.isEmpty) return const [];
  final rows = await db.query(
    Loan.tableName,
    where: 'borrowerPartyId = ?',
    whereArgs: [selfPartyId],
    orderBy: '${LoanFields.dateCreated} DESC',
  );
  return rows.map(Loan.fromJson).toList();
});

class BorrowerHome extends ConsumerWidget {
  const BorrowerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loans = ref.watch(borrowerLoansProvider);
    return Scaffold(
      body: loans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Loans could not be loaded',
          message: 'Please restart the app and try again.',
        ),
        data: (items) => _BorrowerLoanList(loans: items),
      ),
      
    );
  }
}

class _BorrowerLoanList extends StatelessWidget {
  const _BorrowerLoanList({required this.loans});

  final List<Loan> loans;

  @override
  Widget build(BuildContext context) {
    final active = loans.where((loan) => !loan.isFinished()).toList();
    final totals = <String, num>{};
    for (final loan in active) {
      totals.update(
        loan.currency,
        (value) => value + loan.calculateCollectable(),
        ifAbsent: () => loan.calculateCollectable(),
      );
    }
    final outstanding = totals.entries
        .map((entry) => CurrencyPresentation.format(entry.value, entry.key))
        .join(' · ');
    return CustomScrollView(
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
                const SizedBox(height: 6),
                Text(
                  'All loans you have received, including loans from lenders who do not use LoanX.'
                      .tr(),
                ),
                const SizedBox(height: 16),
                _OutstandingCard(
                  activeCount: active.length,
                  outstanding: outstanding.isEmpty ? '—' : outstanding,
                ),
              ],
            ),
          ),
        ),
        if (loans.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No loans recorded',
              message: 'Add a loan from any lender to track what you owe.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            sliver: SliverList.builder(
              itemCount: loans.length,
              itemBuilder: (context, index) => _LoanCard(loan: loans[index]),
            ),
          ),
      ],
    );
  }
}

class _OutstandingCard extends StatelessWidget {
  const _OutstandingCard({
    required this.activeCount,
    required this.outstanding,
  });
  final int activeCount;
  final String outstanding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated amount owed'.tr(),
            style: TextStyle(color: colors.onPrimary.withValues(alpha: .8)),
          ),
          const SizedBox(height: 4),
          Text(
            outstanding,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$activeCount active loans'.tr(),
            style: TextStyle(color: colors.onPrimary.withValues(alpha: .8)),
          ),
        ],
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan});
  final Loan loan;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Text(
            loan.depositorName.isEmpty
                ? '?'
                : loan.depositorName[0].toUpperCase(),
          ),
        ),
        title: Text(loan.depositorName),
        subtitle: Text(
          loan.isFinished() ? 'Closed'.tr() : 'External lender'.tr(),
        ),
        trailing: Text(
          CurrencyPresentation.format(
            loan.calculateCollectable(),
            loan.currency,
          ),
          style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800),
        ),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => LoanDetails(loan: loan))),
      ),
    );
  }
}
