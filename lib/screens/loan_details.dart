import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:loanx/extension/string.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/provider/provider.dart';

class LoanDetails extends ConsumerWidget {
  const LoanDetails({super.key, required this.loan});

  final Loan loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loan details')),
      body: ref
          .watch(familyRelationListProvider)
          .when(
            data: (relations) => ref
                .watch(mortgageMaterialListProvider)
                .when(
                  data: (materials) {
                    final relation = relations.firstWhere(
                      (item) => item.id == loan.familyRelationId,
                    );
                    final material = materials.firstWhere(
                      (item) => item.id == loan.mortgageMaterialId,
                    );
                    return _DetailsContent(
                      loan: loan,
                      relation: relation.name,
                      material: material.name,
                    );
                  },
                  error: (_, _) => const _LoadError(),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
            error: (_, _) => const _LoadError(),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
    );
  }
}

class _DetailsContent extends StatelessWidget {
  const _DetailsContent({
    required this.loan,
    required this.relation,
    required this.material,
  });

  final Loan loan;
  final String relation;
  final String material;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final calculated = loan.calculateCollectable();
    final interest = loan.interestType == InterestType.compound.index
        ? calculated - loan.loanAmount
        : calculated;
    final collectable = loan.interestType == InterestType.compound.index
        ? calculated
        : loan.loanAmount + calculated;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primary, colors.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loan.depositorName,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: colors.onPrimary),
                    ),
                  ),
                  _StatusPill(completed: loan.isFinished()),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'COLLECTABLE AMOUNT',
                style: TextStyle(
                  color: colors.onPrimary.withValues(alpha: .7),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                currency.format(collectable),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _AmountMetric(
                      label: 'Principal',
                      value: currency.format(loan.loanAmount),
                    ),
                  ),
                  Expanded(
                    child: _AmountMetric(
                      label: 'Interest',
                      value: currency.format(interest),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Loan information'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              _DetailRow(
                icon: Icons.percent_rounded,
                label: 'Interest',
                value:
                    '${loan.interestRate}% · ${InterestType.values[loan.interestType].name.toSentenceCase()}',
              ),
              if (loan.interestType == InterestType.compound.index)
                _DetailRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Frequency',
                  value: InterestFrequency.values[loan.interestFrequency].name
                      .toSentenceCase(),
                ),
              _DetailRow(
                icon: Icons.inventory_2_outlined,
                label: 'Mortgage material',
                value: material,
              ),
              _DetailRow(
                icon: Icons.event_outlined,
                label: 'Created',
                value: DateFormat(
                  'd MMM yyyy, h:mm a',
                ).format(loan.dateCreated),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Borrower information'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: loan.phoneNumber,
              ),
              _DetailRow(
                icon: Icons.people_outline_rounded,
                label: relation,
                value: loan.relativeName,
              ),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: loan.address,
              ),
              _DetailRow(
                icon: Icons.notes_rounded,
                label: 'Additional details',
                value: loan.additionalDetails.trim().isEmpty
                    ? 'No additional details'
                    : loan.additionalDetails,
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        completed ? 'Completed' : 'Active',
        style: TextStyle(
          color: colors.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AmountMetric extends StatelessWidget {
  const _AmountMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: .7))),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(value, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last) const Divider(indent: 58),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Unable to load loan details'));
}
