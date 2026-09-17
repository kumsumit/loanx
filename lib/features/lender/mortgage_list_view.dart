import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/extension/system_value_localization.dart';
import 'package:loanx/model/mortgage_material.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/features/lender/loan_details.dart';
import 'package:loanx/features/lender/add_loan.dart';
import 'package:loanx/service/currency_presentation.dart';
import 'package:loanx/service/device_performance.dart';
import 'package:loanx/widget/empty_state.dart';
import 'package:loanx/widget/loan_record_status_indicator.dart';
import 'package:loanx/widget/snackbar.dart';

enum LoanStatusFilter {
  all,
  active,
  completed;

  String get label => switch (this) {
    LoanStatusFilter.all => LocaleKeys.allLoans.tr(),
    LoanStatusFilter.active => LocaleKeys.active.tr(),
    LoanStatusFilter.completed => LocaleKeys.completed.tr(),
  };
}

class MortgageListView extends StatelessWidget {
  const MortgageListView({super.key, this.filter = LoanStatusFilter.all});

  final LoanStatusFilter filter;

  Widget _mortgageBuilder(
    BuildContext context,
    Loan loan,
    MortgageMaterial? mortgageMaterial,
  ) {
    return Consumer(
      builder: (context, ref, child) {
        final loanSelectionList = ref.watch(loanSelectionListProvider);
        final selected = loanSelectionList.contains(loan.id);
        final colors = Theme.of(context).colorScheme;
        final amount = CurrencyPresentation.format(
          loan.loanAmount,
          loan.currency,
        );
        return GestureDetector(
          onHorizontalDragEnd: (details) async {
            if (details.velocity.pixelsPerSecond.dx > 0 && !loan.isFinished()) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(LocaleKeys.confirmation.tr()),
                  content: Text(
                    "Are you sure want you have returned this mortgage to the borrower and clear the loan?"
                        .tr(),
                  ),
                  actionsAlignment: MainAxisAlignment.spaceEvenly,
                  actions: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(LocaleKeys.cancel.tr()),
                    ),
                    OutlinedButton(
                      child: Text(LocaleKeys.ok2.tr()),
                      onPressed: () async {
                        loan.toggleFinished();
                        await ref
                            .read(loanListProvider.notifier)
                            .updateLoan(loan);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          showSnackBar(
                            context,
                            LocaleKeys.nowYouCanGiveMortgageToTheBorrower.tr(),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            }
          },
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LoanDetails(loan: loan)),
            );
          },
          onLongPress: () {
            if (loanSelectionList.contains(loan.id)) {
              ref.read(loanSelectionListProvider.notifier).remove(loan.id ?? 0);
            } else {
              ref.read(loanSelectionListProvider.notifier).add(loan.id ?? 0);
            }
          },
          child: AnimatedContainer(
            // Avoid keeping every list card in an animation layer on older
            // Android GPUs. The selected state remains visible immediately.
            duration: DevicePerformance.reducePaintComplexity
                ? Duration.zero
                : const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? colors.primaryContainer
                  : colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: loan.isFinished()
                          ? colors.surfaceContainerHighest
                          : colors.secondaryContainer,
                      foregroundColor: loan.isFinished()
                          ? colors.onSurfaceVariant
                          : colors.onSecondaryContainer,
                      child: selected
                          ? const Icon(Icons.check_rounded)
                          : Text(
                              loan.depositorName.trim().isEmpty
                                  ? '?'
                                  : loan.depositorName.trim()[0].toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loan.depositorName,
                            key: Key('list_item_${loan.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  decoration: loan.isFinished()
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  amount,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              const Spacer(),
                              LoanRecordStatusIndicator(loan: loan),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: colors.outlineVariant, height: 1),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _LoanCardField(
                          label: '',
                          value:
                              mortgageMaterial?.localizedName ??
                              LocaleKeys.notRecorded.tr(),
                        ),
                      ),
                      if (loan.formattedMortgageWeight.isNotEmpty) ...[
                        SizedBox(
                          height: 36,
                          child: VerticalDivider(
                            color: colors.outlineVariant,
                            width: 24,
                          ),
                        ),
                        Icon(
                          Icons.scale_outlined,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: _LoanCardField(
                            label: '',
                            value: loan.formattedMortgageWeightWithUnit,
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      loan.isFinished()
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      size: 16,
                      color: loan.isFinished()
                          ? colors.onSurfaceVariant
                          : colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        loan.isFinished()
                            ? '${LocaleKeys.completed.tr()} · ${DateFormat('d MMMM yyyy, h:mm a').format(loan.dateFinished!)}'
                            : DateFormat(
                                'd MMMM yyyy, h:mm a',
                              ).format(loan.dateCreated),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final loans = ref.watch(loanListProvider);
        final mortgageMaterials = ref.watch(mortgageMaterialListProvider);
        return mortgageMaterials.when(
          data: (mortgageMaterialList) {
            if (mortgageMaterialList.isEmpty) {
              return EmptyState(
                icon: Icons.inventory_2_outlined,
                title: LocaleKeys.setUpYourLoanMaterials.tr(),
                message:
                    'Add at least one pledged material in Manage before creating a loan.'
                        .tr(),
              );
            }
            return loans.when(
              data: (loanList) {
                final filteredLoans = switch (filter) {
                  LoanStatusFilter.all => loanList,
                  LoanStatusFilter.active =>
                    loanList.where((loan) => !loan.isFinished()).toList(),
                  LoanStatusFilter.completed =>
                    loanList.where((loan) => loan.isFinished()).toList(),
                };
                if (filteredLoans.isEmpty) {
                  final hasLoans = loanList.isNotEmpty;
                  return EmptyState(
                    icon: hasLoans
                        ? Icons.filter_alt_off_outlined
                        : Icons.receipt_long_outlined,
                    title: hasLoans
                        ? LocaleKeys.noFilteredLoans.tr(
                            namedArgs: {'filter': filter.label.toLowerCase()},
                          )
                        : LocaleKeys.noLoansYet.tr(),
                    message: hasLoans
                        ? 'Try a different filter to view your loan records.'
                              .tr()
                        : 'Create your first loan to track borrowers, pledged materials, and repayment status.'
                              .tr(),
                    action: hasLoans
                        ? null
                        : FilledButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const LoanInput(),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(LocaleKeys.createALoan.tr()),
                          ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  scrollCacheExtent: const ScrollCacheExtent.pixels(300),
                  itemCount: filteredLoans.length,
                  itemBuilder: (context, index) {
                    final loan = filteredLoans[index];
                    MortgageMaterial? mortgageMaterial;
                    for (final item in mortgageMaterialList) {
                      if (item.id == loan.mortgageMaterialId) {
                        mortgageMaterial = item;
                        break;
                      }
                    }
                    return _mortgageBuilder(context, loan, mortgageMaterial);
                  },
                );
              },
              error: (e, b) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: LocaleKeys.loansCouldNotBeLoaded.tr(),
                message: LocaleKeys.pleaseRestartTheAppAndTryAgain.tr(),
              ),
              loading: () => Center(child: CircularProgressIndicator()),
            );
          },
          error: (e, b) => EmptyState(
            icon: Icons.error_outline_rounded,
            title: LocaleKeys.materialsCouldNotBeLoaded.tr(),
            message: LocaleKeys.pleaseRestartTheAppAndTryAgain.tr(),
          ),
          loading: () => Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _LoanCardField extends StatelessWidget {
  const _LoanCardField({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final alignment = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
        ],
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// showDescriptionDialog(BuildContext context, loanx loanx, Item item,
//     FamilyRelation familyRelation, MortgageMaterial MortgageMaterial) {
//   final loan = Loan(
//       principal: loanx.loanAmount,
//       interestRate: loanx.interestRate,
//       duration: DateTime.now().difference(loanx.dateCreated).inDays,
//       interestType: InterestType.simple,
//       compoundingFrequency: CompoundingFrequency.monthly);
//   final double interest = loan.calculateInterest();
//   showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//             title: Text(LocaleKeys.loanxDetails.tr()),
//             content: SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: SingleChildScrollView(
//                 scrollDirection: Axis.vertical,
//                 child: DataTable(
//                   columns: [
//                     DataColumn(label: SizedBox()),
//                     DataColumn(label: SizedBox()),
//                   ],
//                   rows: [
//                     buildDataRow(
//                         context, 'Depositor Name', loanx.depositorName),
//                     buildDataRow(
//                         context, 'Relative Name', loanx.relativeName),
//                     buildDataRow(context, 'Address', loanx.address),
//                     buildDataRow(
//                         context, 'Loan Amount', loanx.loanAmount.toStringAsFixed(2)),
//                      buildDataRow(
//                         context, 'Calculated Interest', interest.toStringAsFixed(2)),
//                     buildDataRow(context, 'Interest Rate',
//                         loanx.interestRate.toString()),
//                     buildDataRow(context, 'Interest Type',
//                        InterestType.values[loanx.interestType].name.toSentenceCase()),
//                     if (InterestType.values[loanx.interestType] == InterestType.compound)
//                       buildDataRow(context, 'Compounding Frequency',
//                           CompoundingFrequency.values[loanx.compoundingFrequency].name.toSentenceCase()),
//                     buildDataRow(context, 'Weight', loanx.weight.toString()),
//                     buildDataRow(context, 'Additional Details',
//                         loanx.additionalDetails),
//                     buildDataRow(context, 'Item', item.name),
//                     buildDataRow(
//                         context, 'Family Relation', familyRelation.name),
//                     buildDataRow(
//                         context, 'loanx Material', MortgageMaterial.name),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                 },
//                 child: Text(LocaleKeys.close.tr()),
//               ),
//             ],
//           ));
// }

// DataRow buildDataRow(BuildContext context, String title, String value) {
//   return DataRow(
//     cells: [
//       DataCell(Text(title,
//           style: TextStyle(
//               fontSize: 15, color: Theme.of(context).colorScheme.primary))),
//       DataCell(Text(value,
//           style: TextStyle(
//               fontSize: 15, color: Theme.of(context).colorScheme.secondary))),
//     ],
//   );
// }
