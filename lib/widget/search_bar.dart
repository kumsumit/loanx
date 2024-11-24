import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/model/mortgage.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/screens/mortgage_details.dart';

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
                final m = ref.watch(itemListProvider);
                return m.when(
                    data: (data) {
                      if (data.isEmpty) {
                        return Center(child: Text("No data found"));
                      }
                      return ListTile(
                        title: Text(mortgage.depositorName),
                        leading: Text(data
                            .firstWhere((mo) => mo.id == mortgage.itemId)
                            .name),
                      );
                    },
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
                    suggestionsController.open();
                  }
                } else if (value == 4) {
                  final dateRange = await showDateRangeSelectorDialog(context);
                  if (dateRange != null) {
                    suggestionsController.suggestions = ref
                        .read(mortgageListProvider.notifier)
                        .searchMortgagesByDateRange(dateRange);
                    suggestionsController.open();
                  }
                } else if (value == 5) {
                  final itemType = await showItemTypeSelectorDialog(context);
                  debugPrint(itemType.toString());
                  if (itemType != null) {
                    suggestionsController.suggestions = ref
                        .read(mortgageListProvider.notifier)
                        .searchMortgagesByItemId(itemType);
                    suggestionsController.open();
                  }
                } else if (value == 6) {
                  final mortgageMaterialType =
                      await showMortageMaterialTypeSelectorDialog(context);
                  if (mortgageMaterialType != null) {
                    suggestionsController.suggestions = ref
                        .read(mortgageListProvider.notifier)
                        .searchMortgagesByMortgageMaterialId(
                            mortgageMaterialType);
                    suggestionsController.open();
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
        ],
      )),
    );
  }

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
    debugPrint(searchTerm);
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
    return [];
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
}
