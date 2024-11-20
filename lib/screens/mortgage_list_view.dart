import 'package:flutter/material.dart';
// import 'package:flutter_color_picker_plus/flutter_color_picker_plus.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:mortgage/extension/string.dart';
import 'package:mortgage/model/item.dart';
// import 'package:mortgage/model/loan.dart';
import 'package:mortgage/model/mortgage.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/screens/mortgage_details.dart';

class MortgageListView extends StatelessWidget {
  const MortgageListView({super.key});

  Widget _mortgageBuilder(
    BuildContext context,
    Mortgage mortgage,
    Item item,
  ) {
    return Consumer(builder: (context, ref, child) {
      return GestureDetector(
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
              Checkbox(
                  value: mortgage.isFinished(),
                  onChanged: (bool? value) async {
                    mortgage.toggleFinished();
                    ref
                        .read(mortgageListProvider.notifier)
                        .updateMortgage(mortgage);
                  }),
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
              return Center(child: Text("No data found", style: TextStyle(fontSize: 20,color : Theme.of(context).colorScheme.secondary),));
            }
            return mortgages.when(
                data: (mortgageList) {
                  if (mortgageList.isEmpty) {
                    return Center(child: Text("No data found",style: TextStyle(fontSize: 20, color : Theme.of(context).colorScheme.secondary),));
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
                error: (e, b) => Center(child: Text("An Error occurred",style: TextStyle(fontSize: 20,color : Theme.of(context).colorScheme.secondary),)),
                loading: () => Center(child: CircularProgressIndicator()));
          },
          error: (e, b) => Center(child: Text("An Error occurred",style: TextStyle(fontSize: 20,color : Theme.of(context).colorScheme.secondary),)),
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

class SearchAppBar extends HookWidget {
  const SearchAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final SuggestionsController<Mortgage> suggestionsController =
        useMemoized(() => SuggestionsController<Mortgage>());
    final filter = useState<int>(1);
    return Padding(
      padding: EdgeInsets.only(left: 20.0, bottom: 10.0),
      child: Center(
          child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Consumer(builder: (context, ref, child) {
            return TypeAheadField<Mortgage>(
              suggestionsController: suggestionsController,
              suggestionsCallback: (searchTerm) =>
                  suggestionsCallback(searchTerm, filter.value, ref),
              builder: (context, controller, focusNode) {
                return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Search Mortgage',
                      suffixIcon: Icon(Icons.search),
                    ));
              },
              itemBuilder: (context, mortgage) {
                final m = ref.watch(mortgageListProvider);
                return m.when(
                    data: (data) => ListTile(
                          title: Text(mortgage.depositorName),
                          leading: Text(data
                              .firstWhere((mo) => mo.id == mortgage.itemId)
                              .depositorName),
                        ),
                    error: (_, o) => Center(child: Text("An error occurred")),
                    loading: () => Center(child: CircularProgressIndicator()));
              },
              onSelected: (mortgage) {
                ref.read(itemListProvider).when(
                    data: (data) {
                      final item =
                          data.firstWhere((item) => item.id == mortgage.itemId);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => MortgageDetails(
                                  mortgage: mortgage, item: item)));
                    },
                    error: (_, e) {},
                    loading: () {});
              },
            );
          })),
          Consumer(builder: (context, ref, child) {
            return PopupMenuButton<int>(
              icon: Icon(Icons.filter_alt_outlined,
                  color: Theme.of(context).colorScheme.secondary),
              onSelected: (value) async {
                if (value == 3) {
                  final date = await showDateSelectorDialog(context);
                  if (date != null) {
                    suggestionsController.suggestions = ref
                        .read(mortgageListProvider.notifier)
                        .searchMortgagesByDateCreated(date);
                    suggestionsController.open(gainFocus: true);
                  }
                } else if (value == 4) {
                  final dateRange = await showDateRangeSelectorDialog(context);
                  if (dateRange != null) {
                    suggestionsController.suggestions = ref
                        .read(mortgageListProvider.notifier)
                        .searchMortgagesByDateRange(dateRange);
                  }
                } else if (value == 5) {
                  final itemType = await showItemTypeSelectorDialog(context);
                  if (itemType != null) {
                    suggestionsController.suggestions = ref
                        .read(mortgageListProvider.notifier)
                        .searchMortgagesByItemId(itemType);
                  }
                  suggestionsController.suggestions = [];
                } else if (value == 6) {
                  final mortgageMaterialType =
                      await showMortageMaterialTypeSelectorDialog(context);
                  if (mortgageMaterialType != null) {
                    suggestionsController.suggestions = ref
                        .read(mortgageListProvider.notifier)
                        .searchMortgagesByMortgageMaterialId(
                            mortgageMaterialType);
                  }
                }

                filter.value = value;
              },
              itemBuilder: (BuildContext context) {
                return [
                  PopupMenuItem<int>(
                    value: 1,
                    child: Text('Depositor Name'),
                  ),
                  PopupMenuItem<int>(
                    value: 2,
                    child: Text('Relative Name'),
                  ),
                  PopupMenuItem<int>(value: 3, child: Text('Date Of Loan')),
                  PopupMenuItem<int>(
                      value: 4, child: Text('Date Range Of Loan')),
                  PopupMenuItem<int>(value: 5, child: Text('Item Type')),
                  PopupMenuItem<int>(
                      value: 6, child: Text('Mortgage Material Type')),
                ];
              },
            );
          }),
          // IconButton(
          //     icon: Icon(Icons.color_lens),
          //     onPressed: () {
          //       _showDialog(context);
          //     })
          // IconButton(
          //     onPressed: () async => await uploadToGoogleDrive(context),
          //     icon: Icon(Icons.upload)),
          // IconButton(
          //     onPressed: listBackupFiles,
          //     icon: Icon(Icons.view_comfortable_outlined)),
          // IconButton(
          //   onPressed: () {
          //     showOverlay(context);
          //   },
          //   icon: Icon(Icons.favorite),
          // ),
        ],
      )),
    );
  }

  // void _showDialog(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
  //       title: Row(
  //         children: [
  //           const Text('Pick a color!'),
  //           Consumer(builder: (context, ref, child) {
  //             return IconButton(
  //               icon: Icon(Icons.light_mode),
  //               onPressed: ref.read(themeModeManagerProvider.notifier).set,
  //             );
  //           }),
  //         ],
  //       ),
  //       content: Consumer(builder: (context, ref, child) {
  //         final color = ref.watch(pickerColorProvider);
  //         return ColorPicker(
  //             pickerColor:
  //                 Color(int.parse('FF${color.substring(1)}', radix: 16)),
  //             onColorChanged: (color) async {
  //               ref.read(pickerColorProvider.notifier).set(color);
  //               await ref.read(appColorProvider.notifier).set();
  //             });
  //       }),
  //       actions: <Widget>[
  //         ElevatedButton(
  //           child: const Text('Got it'),
  //           onPressed: () {
  //             // Navigator.of(context).pop();
  //             _showBottomSheet(context);
  //           },
  //         )
  //       ],
  //     ),
  //   );
  // }

  // void _showBottomSheet(BuildContext context) {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return GridView(
  //           shrinkWrap: true,
  //           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  //             crossAxisCount: 2, // Number of columns in the grid
  //             crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.5,
  //           ),
  //           children: [
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.primary,
  //                 text: "Primary"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onPrimary,
  //                 text: "onPrimary"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.primaryContainer,
  //                 text: "primaryContainer"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onPrimaryContainer,
  //                 text: "onPrimaryContainer"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.primaryFixed,
  //                 text: "PrimaryFixed"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onPrimaryFixed,
  //                 text: "onPrimaryFixed"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.primaryFixedDim,
  //                 text: "primaryFixedDim"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onPrimaryFixedVariant,
  //                 text: "onPrimaryFixedVariant"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.secondary,
  //                 text: "secondary"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onSecondary,
  //                 text: "onSecondary"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.secondaryContainer,
  //                 text: "secondaryContainer"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onSecondaryContainer,
  //                 text: "onSecondaryContainer"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.secondaryFixed,
  //                 text: "secondaryFixed"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onSecondaryFixed,
  //                 text: "onSecondaryFixed"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.secondaryFixedDim,
  //                 text: "secondaryFixedDim"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onSecondaryFixedVariant,
  //                 text: "onSecondaryFixedVariant"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.tertiary,
  //                 text: "tertiary"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onTertiary,
  //                 text: "onTertiary"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.tertiaryContainer,
  //                 text: "tertiaryContainer"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onTertiaryContainer,
  //                 text: "onTertiaryContainer"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.tertiaryFixed,
  //                 text: "tertiaryFixed"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onTertiaryFixed,
  //                 text: "onTertiaryFixed"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.tertiaryFixedDim,
  //                 text: "tertiaryFixedDim"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onTertiaryFixedVariant,
  //                 text: "onTertiaryFixedVariant"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onSurface,
  //                 text: "onSurface"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onSurfaceVariant,
  //                 text: "onSurfaceVariant"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.inversePrimary,
  //                 text: "inversePrimary"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.inverseSurface,
  //                 text: "inverseSurface"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.outline,
  //                 text: "outline"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.outlineVariant,
  //                 text: "outlineVariant"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onError,
  //                 text: "onError"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.onErrorContainer,
  //                 text: "onErrorContainer"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.error, text: "error"),
  //             ColorCircle(
  //                 color: Theme.of(context).colorScheme.errorContainer,
  //                 text: "errorContainer"),
  //             SizedBox(height: 10),
  //             ElevatedButton(
  //               onPressed: () {
  //                 Navigator.pop(context); // Dismiss the bottom sheet
  //               },
  //               child: Text('Close'),
  //             ),
  //           ]);
  //     },
  //   );
  // }

  Future<DateTime?> showDateSelectorDialog(BuildContext context) async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime(2025),
      initialEntryMode: DatePickerEntryMode.calendar,
    );
  }

  Future<DateTimeRange?> showDateRangeSelectorDialog(
      BuildContext context) async {
    DateTime now = DateTime.now();
    DateTime fiveYearsBack = DateTime(now.year - 5, now.month, now.day);
    DateTime fiveYearsAhead = DateTime(now.year + 5, now.month, now.day);
    return await showDateRangePicker(
        context: context, firstDate: fiveYearsBack, lastDate: fiveYearsAhead);
  }

  Future<int?> showItemTypeSelectorDialog(BuildContext context) async {
    return await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select an Item Type'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * .75,
            child: Consumer(builder: (context, ref, child) {
              final items = ref.watch(itemListProvider);
              return items.when(
                  data: (data) {
                    if (data.isEmpty) return SizedBox();
                    return ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(data[index].name),
                          onTap: () {
                            Navigator.of(context).pop(index);
                          },
                        );
                      },
                    );
                  },
                  error: (_, __) => Center(child: Text("An error occurred")),
                  loading: () => Center(child: CircularProgressIndicator()));
            }),
          ),
        );
      },
    );
  }

  Future<int?> showMortageMaterialTypeSelectorDialog(
      BuildContext context) async {
    return await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select an Mortgagae Material Type'),
          content: SingleChildScrollView(
            child: Consumer(builder: (context, ref, child) {
              final mortgageMaterialTypes =
                  ref.watch(mortgageMaterialListProvider);

              return mortgageMaterialTypes.when(
                  data: (data) => ListView.builder(
                        itemCount: data.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(data[index].name),
                            onTap: () {
                              Navigator.of(context).pop(index);
                            },
                          );
                        },
                      ),
                  error: (_, __) => Center(child: Text("An error occurred")),
                  loading: () => Center(child: CircularProgressIndicator()));
            }),
          ),
        );
      },
    );
  }

  suggestionsCallback(String searchTerm, int filter, WidgetRef ref) {
    switch (filter) {
      case 1:
        return ref
            .read(mortgageListProvider.notifier)
            .searchMortgagesByDepositorName(searchTerm);
      case 2:
        return ref
            .read(mortgageListProvider.notifier)
            .searchMortgagesByRelativeName(searchTerm);
    }
  }
}

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
