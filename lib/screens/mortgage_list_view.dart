import 'package:flutter/material.dart';
// import 'package:flutter_color_picker_plus/flutter_color_picker_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:mortgage/extension/string.dart';
import 'package:mortgage/model/item.dart';
// import 'package:mortgage/model/loan.dart';
import 'package:mortgage/model/mortgage.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/screens/mortgage_details.dart';
import 'package:mortgage/widget/snackbar.dart';

class MortgageListView extends StatelessWidget {
  const MortgageListView({super.key});

  Widget _mortgageBuilder(
    BuildContext context,
    Mortgage mortgage,
    Item item,
  ) {
    return Consumer(builder: (context, ref, child) {
      return GestureDetector(
        onHorizontalDragEnd: (details) async {
          if (details.velocity.pixelsPerSecond.dx > 0 && !mortgage.isFinished()) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("Confirmation"),
                content: Text(
                    "Are you sure want you have returned this mortgage to the borrower?"),
                actionsAlignment: MainAxisAlignment.spaceEvenly,
                actions: [
                  OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text("Cancel")),
                  Consumer(builder: (context, ref, child) {
                    return OutlinedButton(
                      child: const Text('Ok'),
                      onPressed: () async {
                        await ref.read(appColorProvider.notifier).set();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          showSnackBar(context,
                              "Now, you can give mortgage to the borrower");
                        }
                      },
                    );
                  }),
                ],
              ),
            );

            mortgage.toggleFinished();
            await ref
                .read(mortgageListProvider.notifier)
                .updateMortgage(mortgage);
          }
        },
        onDoubleTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      MortgageDetails(mortgage: mortgage, item: item)));
        },
        onLongPress: () {
          if (ref.read(mortgageSelectionListProvider).contains(mortgage.id)) {
            ref
                .read(mortgageSelectionListProvider.notifier)
                .remove(mortgage.id ?? 0);
          } else {
            ref
                .read(mortgageSelectionListProvider.notifier)
                .add(mortgage.id ?? 0);
          }
        },
        child: ColoredBox(
          color: ref.watch(mortgageSelectionListProvider).contains(mortgage.id)
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          child: Row(
            children: <Widget>[
              // Checkbox(
              //     value: mortgage.isFinished(),
              //     onChanged: (bool? value) async {
              //       mortgage.toggleFinished();
              //     await  ref
              //           .read(mortgageListProvider.notifier)
              //           .updateMortgage(mortgage);
              //     }),
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
                          '${mortgage.depositorName} (item: ${item.name})',
                          style: mortgage.isFinished()
                              ? const TextStyle(
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough)
                              : const TextStyle(fontSize: 15.0),
                          // Provide a Key for the integration test
                          key: Key('list_item_${mortgage.id}'),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text(
                            mortgage.getStateText(),
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
      final items = ref.watch(itemListProvider);
      final mortgages = ref.watch(mortgageListProvider);
      return items.when(
          data: (itemList) {
            if (itemList.isEmpty) {
              return Center(
                  child: Text(
                "No data found",
                style: TextStyle(
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.secondary),
              ));
            }
            return mortgages.when(
                data: (mortgageList) {
                  if (mortgageList.isEmpty) {
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
                      itemCount: mortgageList.length,
                      itemBuilder: (context, index) {
                        final mortgage = mortgageList[index];
                        final item = itemList
                            .firstWhere((item) => item.id == mortgage.itemId);
                        return _mortgageBuilder(context, mortgage, item);
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

// class ColorCircle extends StatelessWidget {
//   const ColorCircle({super.key, required this.color, required this.text});
//   final Color color;
//   final String text;
//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       children: [
//         SizedBox(
//           height: 40,
//           child: DecoratedBox(
//               decoration: BoxDecoration(
//             color: color,
//             borderRadius: BorderRadius.circular(20),
//           )),
//         ),
//         Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
//       ],
//     );
//   }
// }


// showDescriptionDialog(BuildContext context, Mortgage mortgage, Item item,
//     FamilyRelation familyRelation, MortgageMaterial mortgageMaterial) {
//   final loan = Loan(
//       principal: mortgage.loanAmount,
//       interestRate: mortgage.interestRate,
//       duration: DateTime.now().difference(mortgage.dateCreated).inDays,
//       interestType: InterestType.simple,
//       compoundingFrequency: CompoundingFrequency.monthly);
//   final double interest = loan.calculateInterest();
//   showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//             title: Text('Mortgage Details'),
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
//                         context, 'Depositor Name', mortgage.depositorName),
//                     buildDataRow(
//                         context, 'Relative Name', mortgage.relativeName),
//                     buildDataRow(context, 'Address', mortgage.address),
//                     buildDataRow(
//                         context, 'Loan Amount', mortgage.loanAmount.toStringAsFixed(2)),
//                      buildDataRow(
//                         context, 'Calculated Interest', interest.toStringAsFixed(2)),
//                     buildDataRow(context, 'Interest Rate',
//                         mortgage.interestRate.toString()),
//                     buildDataRow(context, 'Interest Type',
//                        InterestType.values[mortgage.interestType].name.toSentenceCase()),
//                     if (InterestType.values[mortgage.interestType] == InterestType.compound)
//                       buildDataRow(context, 'Compounding Frequency',
//                           CompoundingFrequency.values[mortgage.compoundingFrequency].name.toSentenceCase()),
//                     buildDataRow(context, 'Weight', mortgage.weight.toString()),
//                     buildDataRow(context, 'Additional Details',
//                         mortgage.additionalDetails),
//                     buildDataRow(context, 'Item', item.name),
//                     buildDataRow(
//                         context, 'Family Relation', familyRelation.name),
//                     buildDataRow(
//                         context, 'Mortgage Material', mortgageMaterial.name),
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
