import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/model/mortgage_material.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/loan_details.dart';
import 'package:loanx/screens/add_loan.dart';
import 'package:loanx/service/contact_service.dart';
import 'package:loanx/widget/empty_state.dart';
import 'package:loanx/widget/snackbar.dart';

enum LoanStatusFilter {
  all,
  active,
  completed;

  String get label => switch (this) {
    LoanStatusFilter.all => 'All loans'.tr(),
    LoanStatusFilter.active => 'Active'.tr(),
    LoanStatusFilter.completed => 'Completed'.tr(),
  };
}

class MortgageListView extends StatelessWidget {
  const MortgageListView({super.key, this.filter = LoanStatusFilter.all});

  final LoanStatusFilter filter;

  Widget _mortgageBuilder(
    BuildContext context,
    Loan loan,
    MortgageMaterial mortgageMaterial,
  ) {
    return Consumer(
      builder: (context, ref, child) {
        final loanSelectionList = ref.watch(loanSelectionListProvider);
        final selected = loanSelectionList.contains(loan.id);
        final colors = Theme.of(context).colorScheme;
        final amount = NumberFormat.currency(
          locale: context.locale.toString(),
          symbol: '₹',
          decimalDigits: 0,
        ).format(loan.loanAmount);
        return GestureDetector(
          onHorizontalDragEnd: (details) async {
            if (details.velocity.pixelsPerSecond.dx > 0 && !loan.isFinished()) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text("Confirmation".tr()),
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
                      child: Text("Cancel".tr()),
                    ),
                    OutlinedButton(
                      child: Text('Ok'.tr()),
                      onPressed: () async {
                        loan.toggleFinished();
                        await ref
                            .read(loanListProvider.notifier)
                            .updateLoan(loan);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          showSnackBar(
                            context,
                            "Now, you can give mortgage to the borrower".tr(),
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
            duration: const Duration(milliseconds: 180),
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
            child: Row(
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
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
                      const SizedBox(height: 4),
                      Text(
                        loan.weight > 0
                            ? '${mortgageMaterial.name} · ${loan.weight.toStringAsFixed(2)} ${loan.weightUnit}'
                            : mortgageMaterial.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            loan.isFinished()
                                ? Icons.check_circle_rounded
                                : Icons.schedule_rounded,
                            size: 15,
                            color: loan.isFinished()
                                ? colors.onSurfaceVariant
                                : colors.primary,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              loan.isFinished()
                                  ? 'Completed'.tr()
                                  : DateFormat(
                                      'd MMM yyyy',
                                    ).format(loan.dateCreated),
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
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      tooltip: 'Save contact'.tr(),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      color: colors.onSurfaceVariant,
                      onPressed: loan.phoneNumber.trim().isEmpty
                          ? null
                          : () async {
                              final opened = await ContactService.createContact(
                                name: loan.depositorName,
                                phoneNumber: loan.phoneNumber,
                              );
                              if (context.mounted && !opened) {
                                showSnackBar(
                                  context,
                                  'Could not open the contact editor'.tr(),
                                );
                              }
                            },
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
                title: 'Set up your loan materials'.tr(),
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
                        ? 'noFilteredLoans'.tr(
                            namedArgs: {'filter': filter.label.toLowerCase()},
                          )
                        : 'No loans yet'.tr(),
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
                            label: Text('Create a loan'.tr()),
                          ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: filteredLoans.length,
                  itemBuilder: (context, index) {
                    final loan = filteredLoans[index];
                    final mortgageMaterial = mortgageMaterialList.firstWhere(
                      (item) => item.id == loan.mortgageMaterialId,
                    );
                    return _mortgageBuilder(context, loan, mortgageMaterial);
                  },
                );
              },
              error: (e, b) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Loans could not be loaded'.tr(),
                message: 'Please restart the app and try again.'.tr(),
              ),
              loading: () => Center(child: CircularProgressIndicator()),
            );
          },
          error: (e, b) => EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Materials could not be loaded'.tr(),
            message: 'Please restart the app and try again.'.tr(),
          ),
          loading: () => Center(child: CircularProgressIndicator()),
        );
      },
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
//             title: Text('loanx Details'.tr()),
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
//                 child: Text('Close'.tr()),
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
