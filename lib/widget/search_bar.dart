// import 'package:flutter/foundation.dart';
// import 'color_button.dart';
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
              emptyBuilder: (context) {
                return ListTile(
                  tileColor: Theme.of(context).colorScheme.surfaceContainer,
                  title: Text(
                    "No data found",
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary),
                  ),
                );
              },
              errorBuilder: (context, error) {
                return ListTile(
                  title: Text(
                    "An error occurred",
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary),
                  ),
                );
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
          //   if(kDebugMode)
          //  ColorButton()
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
}
