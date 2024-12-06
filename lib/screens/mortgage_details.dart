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
                Duration duration = Duration();
                if(mortgage.compoundingFrequency==InterestFrequency){

                  duration = DateTime.now().difference(mortgage.dateCreated);
                }else{

                }
                final loan = Loan(
                    principal: mortgage.loanAmount,
                    interestRate: mortgage.interestRate,
                    duration:
                        DateTime.now().difference(mortgage.dateCreated).inDays,
                    interestType: InterestType.simple,
                    interestFrequency: InterestFrequency.monthly);
                final double interest = loan.calculateInterest();
                return Scaffold(
                  appBar: AppBar(
                    title: Text('Mortgage Details'),
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
                              context, 'Depositor Name', mortgage.depositorName),
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
                                InterestFrequency
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
