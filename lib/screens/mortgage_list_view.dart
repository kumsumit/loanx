import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/model/mortgage_material.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/loan_details.dart';
import 'package:loanx/widget/snackbar.dart';

class MortgageListView extends StatelessWidget {
  const MortgageListView({super.key});

  Widget _mortgageBuilder(BuildContext context, Loan loan, MortgageMaterial mortgageMaterial) {
    return Consumer(builder: (context, ref, child) {
      final loanSelectionList = ref.read(loanSelectionListProvider);
      return GestureDetector(
        onHorizontalDragEnd: (details) async {
          if (details.velocity.pixelsPerSecond.dx > 0 && !loan.isFinished()) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("Confirmation"),
                content: Text(
                    "Are you sure want you have returned this mortgage to the borrower and clear the loan?"),
                actionsAlignment: MainAxisAlignment.spaceEvenly,
                actions: [
                  OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text("Cancel")),
                  OutlinedButton(
                      child: const Text('Ok'),
                      onPressed: () async {
                        loan.toggleFinished();
                        await ref
                            .read(loanListProvider.notifier)
                            .updateLoan(loan);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          showSnackBar(context,
                              "Now, you can give mortgage to the borrower");
                        }
                      }),
                ],
              ),
            );
          }
        },
        onDoubleTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => MortgageDetails(loan: loan)));
        },
        onLongPress: () {
          debugPrint(loan.id.toString());
          debugPrint(loanSelectionList.length.toString());
          debugPrint(loanSelectionList.contains(loan.id).toString());
          if (loanSelectionList.contains(loan.id)) {
            ref.read(loanSelectionListProvider.notifier).remove(loan.id ?? 0);
          } else {
            ref.read(loanSelectionListProvider.notifier).add(loan.id ?? 0);
          }
        },
        child: ColoredBox(
          color: loanSelectionList.contains(loan.id)
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          child: Row(
            children: <Widget>[
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: Colors.black12))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 18.0, horizontal: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${loan.depositorName} (mortgage: ${mortgageMaterial.name})',
                          style: loan.isFinished()
                              ? const TextStyle(
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough)
                              : const TextStyle(fontSize: 15.0),
                          // Provide a Key for the integration test
                          key: Key('list_item_${loan.id}'),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text(
                            loan.getStateText(),
                            style: const TextStyle(
                              fontSize: 12.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Consumer(builder: (context, ref, child) {
      final loans = ref.watch(loanListProvider);
      final mortgageMaterials = ref.watch(mortgageMaterialListProvider);
      return mortgageMaterials.when(
          data: (mortgageMaterialList) {
            if (mortgageMaterialList.isEmpty) {
              return Center(
                  child: Text(
                "No data found",
                style: TextStyle(
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.secondary),
              ));
            }
            return loans.when(
                data: (loanList) {
                  if (loanList.isEmpty) {
                    return Center(
                        child: Text(
                      "No data found",
                      style: TextStyle(
                          fontSize: 20,
                          color: Theme.of(context).colorScheme.secondary),
                    ));
                  }
                  return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: loanList.length,
                      itemBuilder: (context, index) {
                        final loan = loanList[index];
                        final mortgageMaterial = mortgageMaterialList
                            .firstWhere((item) => item.id == loan.mortgageMaterialId);
                        return _mortgageBuilder(context, loan, mortgageMaterial);
                      });
                },
                error: (e, b) => Center(
                        child: Text(
                      "An Error occurred",
                      style: TextStyle(
                          fontSize: 20,
                          color: Theme.of(context).colorScheme.secondary),
                    )),
                loading: () => Center(child: CircularProgressIndicator()));
          },
          error: (e, b) => Center(
                  child: Text(
                "Loading ...",
                style: TextStyle(
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.secondary),
              )),
          loading: () => Center(
                child: CircularProgressIndicator(),
              ));
    }));
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
//             title: Text('loanx Details'),
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
//                 child: const Text('Close'),
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
