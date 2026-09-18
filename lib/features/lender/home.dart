import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/features/lender/add_loan.dart';
import 'package:loanx/features/borrower/home.dart';
import 'package:loanx/features/lender/mortgage_list_view.dart';
import 'package:loanx/service/currency_presentation.dart';
import 'package:loanx/widget/search_bar.dart';

// import 'keyboard_input.dart';

class Home extends HookWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context) {
    final borrowing = AppSettings.getUsesBorrowerExperience();
    if (borrowing) return const BorrowerHome();
    final filter = useState(LoanStatusFilter.all);
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, child) =>
                  ref.watch(searchBarStatusProvider)
                  ? const SearchAppBar()
                  : const SizedBox(),
            ),
          ),
          const SliverToBoxAdapter(child: _PortfolioSummary()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  Text(
                    LocaleKeys.loans2.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  _StatusFilter(
                    value: filter.value,
                    onChanged: (value) => filter.value = value,
                  ),
                ],
              ),
            ),
          ),
        ],
        body: MortgageListView(filter: filter.value),
      ),
      floatingActionButton: Consumer(
        builder: (context, ref, child) => ref.watch(loanListProvider).when(
          data: (loans) => loans.isEmpty
              ? const SizedBox.shrink()
              : FloatingActionButton.extended(
                  key: const Key('add'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(LocaleKeys.newLoan.tr()),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoanInput()),
                    );
                  },
                ),
          error: (_, _) => const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _PortfolioSummary extends ConsumerWidget {
  const _PortfolioSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return ref
        .watch(loanListProvider)
        .when(
          data: (loans) {
            if (loans.isEmpty) return const SizedBox.shrink();

            final active = loans.where((loan) => !loan.isFinished()).toList();
            final grouped = <String, List<Loan>>{};
            for (final loan in active) {
              grouped.putIfAbsent(loan.currency, () => []).add(loan);
            }
            String totals(num Function(Loan loan) value) => grouped.entries
                .map(
                  (entry) => CurrencyPresentation.format(
                    entry.value.fold<num>(0, (sum, loan) => sum + value(loan)),
                    entry.key,
                  ),
                )
                .join(' · ');
            final principal = totals((loan) => loan.loanAmount);
            final receivable = totals((loan) => loan.calculateCollectable());
            // Interest is shown independently from the amount receivable so
            // that principal and any applicable early-redemption fee do not
            // inflate the lender's earnings figure.
            final interestEarned = totals((loan) => loan.calculateInterest());
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  // Keep this card on the basic GPU paint path. Combining a
                  // gradient, rounded corners and a large blurred shadow can
                  // corrupt the off-screen render target on older Android GPUs.
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.estimatedReceivable.tr(),
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: .75),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          receivable.isEmpty ? '—' : receivable,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryMetric(
                            icon: Icons.receipt_long_outlined,
                            value: '${active.length}',
                            label: 'Active loans',
                          ),
                        ),
                        Expanded(
                          child: _SummaryMetric(
                            icon: Icons.account_balance_wallet_outlined,
                            value: principal.isEmpty ? '—' : principal,
                            label: 'Principal outstanding',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SummaryMetric(
                      icon: Icons.trending_up_rounded,
                      value: interestEarned.isEmpty ? '—' : interestEarned,
                      // This is the accrued interest under each active loan's
                      // saved terms, not principal or early-redemption fees.
                      label: 'Calculated interest',
                    ),
                  ],
                ),
              ),
            );
          },
          error: (_, _) => const SizedBox(height: 12),
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: LinearProgressIndicator(),
          ),
        );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.value, required this.onChanged});

  final LoanStatusFilter value;
  final ValueChanged<LoanStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LoanStatusFilter>(
      tooltip: LocaleKeys.filterLoans.tr(),
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: LoanStatusFilter.all,
          child: Text(LocaleKeys.allLoans.tr()),
        ),
        PopupMenuItem(
          value: LoanStatusFilter.active,
          child: Text(LocaleKeys.active.tr()),
        ),
        PopupMenuItem(
          value: LoanStatusFilter.completed,
          child: Text(LocaleKeys.completed.tr()),
        ),
      ],
      child: Chip(
        avatar: const Icon(Icons.filter_list_rounded, size: 18),
        label: Text(value.label),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: foreground.withValues(alpha: .8), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label.tr(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground.withValues(alpha: .8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
