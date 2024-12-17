import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/extension/string.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/provider/provider.dart';

class LoanDetails extends ConsumerWidget {
  const LoanDetails({super.key, required this.loan});
  final Loan loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(familyRelationListProvider).when(
        data: (familyRelationList) {
          return ref.watch(mortgageMaterialListProvider).when(
              data: (mortgageMaterialList) {
                final familyRelation = familyRelationList.firstWhere(
                    (familyRelation) =>
                        familyRelation.id == loan.familyRelationId);
                final mortgageMaterial = mortgageMaterialList.firstWhere(
                    (mortgageMaterial) =>
                        mortgageMaterial.id == loan.mortgageMaterialId);
                final double collectable = loan.calculateCollectable();
                return Scaffold(
                  appBar: AppBar(
                    title: Text('Loan Details'),
                    centerTitle: true,
                  ),
                  body: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView(
                      child: Table(
                        border: TableBorder.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        children: [
                          buildDataRow(
                              context, 'Depositor Name', loan.depositorName),
                          buildDataRow(
                              context, 'Relative Name', loan.relativeName),
                          buildDataRow(context, 'Address', loan.address),
                          buildDataRow(context, 'Loan Amount',
                              loan.loanAmount.toStringAsFixed(2)),
                          loan.interestType == InterestType.compound.index
                              ? buildDataRow(
                                  context,
                                  'Interest',
                                  (collectable - loan.loanAmount)
                                      .toStringAsFixed(2))
                              : buildDataRow(context, 'Interest',
                                  collectable.toStringAsFixed(2)),
                          loan.interestType == InterestType.compound.index
                              ? buildDataRow(context, 'Collectable Amount',
                                  collectable.toStringAsFixed(2))
                              : buildDataRow(
                                  context,
                                  'Collectable Amount',
                                  (loan.loanAmount + collectable)
                                      .toStringAsFixed(2)),
                          buildDataRow(context, 'Interest Rate',
                              loan.interestRate.toString()),
                          buildDataRow(
                              context,
                              'Interest Type',
                              InterestType.values[loan.interestType].name
                                  .toSentenceCase()),
                          if (InterestType.values[loan.interestType] ==
                              InterestType.compound)
                            buildDataRow(
                                context,
                                'Interest Frequency',
                                InterestFrequency
                                    .values[loan.interestFrequency].name
                                    .toSentenceCase()),
                          buildDataRow(
                              context, 'Family Relation', familyRelation.name),
                          buildDataRow(context, 'Mortgage Material',
                              mortgageMaterial.name),
                          buildDataRow(context, 'Additional Details',
                              loan.additionalDetails),
                        ],
                      ),
                    ),
                  ),
                );
              },
              error: (_, q) => Center(
                    child: Text("An error occurred"),
                  ),
              loading: () => Center(
                    child: CircularProgressIndicator(),
                  ));
        },
        error: (_, q) => Center(
              child: Text("An error occurred"),
            ),
        loading: () => Center(
              child: CircularProgressIndicator(),
            ));
  }

  TableRow buildDataRow(BuildContext context, String title, String value) {
    return TableRow(
      // cells:
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(title,
              style: TextStyle(
                  fontSize: 15, color: Theme.of(context).colorScheme.primary)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(value,
              style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.secondary)),
        ),
      ],
    );
  }
}
