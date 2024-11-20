import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/extension/string.dart';
import 'package:mortgage/model/item.dart';
import 'package:mortgage/model/loan.dart';
import 'package:mortgage/model/mortgage.dart';
import 'package:mortgage/provider/provider.dart';

class MortgageDetails extends ConsumerWidget {
  const MortgageDetails(
      {super.key, required this.mortgage, required this.item});
  final Mortgage mortgage;
  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(familyRelationListProvider).when(
        data: (familyRelationList) {
          return ref.watch(mortgageMaterialListProvider).when(
              data: (mortgageMaterialList) {
                final familyRelation = familyRelationList.firstWhere(
                    (familyRelation) =>
                        familyRelation.id == mortgage.familyRelationId);
                final mortgageMaterial = mortgageMaterialList.firstWhere(
                    (mortgageMaterial) =>
                        mortgageMaterial.id == mortgage.mortgageMaterialId);
                final loan = Loan(
                    principal: mortgage.loanAmount,
                    interestRate: mortgage.interestRate,
                    duration:
                        DateTime.now().difference(mortgage.dateCreated).inDays,
                    interestType: InterestType.simple,
                    compoundingFrequency: CompoundingFrequency.monthly);
                final double interest = loan.calculateInterest();
                return Scaffold(
                  appBar: AppBar(title: Text('Mortgage Details')),
                  body: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columns: [
                          DataColumn(label: SizedBox()),
                          DataColumn(label: SizedBox()),
                        ],
                        rows: [
                          buildDataRow(context, 'Depositor Name',
                              mortgage.depositorName),
                          buildDataRow(
                              context, 'Relative Name', mortgage.relativeName),
                          buildDataRow(context, 'Address', mortgage.address),
                          buildDataRow(context, 'Loan Amount',
                              mortgage.loanAmount.toStringAsFixed(2)),
                          buildDataRow(context, 'Calculated Interest',
                              interest.toStringAsFixed(2)),
                          buildDataRow(context, 'Interest Rate',
                              mortgage.interestRate.toString()),
                          buildDataRow(
                              context,
                              'Interest Type',
                              InterestType.values[mortgage.interestType].name
                                  .toSentenceCase()),
                          if (InterestType.values[mortgage.interestType] ==
                              InterestType.compound)
                            buildDataRow(
                                context,
                                'Compounding Frequency',
                                CompoundingFrequency
                                    .values[mortgage.compoundingFrequency].name
                                    .toSentenceCase()),
                          buildDataRow(
                              context, 'Weight', mortgage.weight.toString()),
                          buildDataRow(context, 'Additional Details',
                              mortgage.additionalDetails),
                          buildDataRow(context, 'Item', item.name),
                          buildDataRow(
                              context, 'Family Relation', familyRelation.name),
                          buildDataRow(context, 'Mortgage Material',
                              mortgageMaterial.name),
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

  DataRow buildDataRow(BuildContext context, String title, String value) {
    return DataRow(
      cells: [
        DataCell(Text(title,
            style: TextStyle(
                fontSize: 15, color: Theme.of(context).colorScheme.primary))),
        DataCell(Text(value,
            style: TextStyle(
                fontSize: 15, color: Theme.of(context).colorScheme.secondary))),
      ],
    );
  }
}
