import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/add_loan.dart';
import 'package:loanx/screens/mortgage_list_view.dart';
import 'package:loanx/widget/search_bar.dart';
import 'package:intl/intl.dart';

// import 'keyboard_input.dart';

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _PortfolioSummary(),
          Consumer(
            builder: (context, ref, child) => ref.watch(searchBarStatusProvider)
                ? const SearchAppBar()
                : const SizedBox(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Text(
              'Recent loans',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const MortgageListView(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New loan'),
        onPressed: () {
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoanInput()),
            );
          }
        },
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
            final active = loans.where((loan) => !loan.isFinished()).toList();
            final total = active.fold<double>(
              0,
              (value, loan) => value + loan.loanAmount,
            );
            final money = NumberFormat.compactCurrency(
              locale: 'en_IN',
              symbol: '₹',
              decimalDigits: 1,
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      colors.primary.withValues(alpha: .78),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: .2),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE PORTFOLIO',
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: .75),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      money.format(total),
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 18),
                     _SummaryMetric(
                          icon: Icons.receipt_long_outlined,
                          value: '${active.length}',
                          label: 'Active loans',
                        ),
                        const SizedBox(width: 28),
                        _SummaryMetric(
                          icon: Icons.check_circle_outline_rounded,
                          value: '${loans.length - active.length}',
                          label: 'Completed',
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
      children: [
        Icon(icon, color: foreground.withValues(alpha: .8), size: 20),
        const SizedBox(width: 8),
        Text(
          '$value $label',
          style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
