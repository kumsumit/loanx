import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/provider/provider.dart';

class SearchAppBar extends HookWidget {
  const SearchAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final SuggestionsController<Loan> suggestionsController =
        useMemoized(() => SuggestionsController<Loan>());
    final filter = useState<int>(1);
    return Padding(
      padding: EdgeInsets.only(left: 20.0, bottom: 10.0),
      child: Center(
          child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Consumer(builder: (context, ref, child) {
            final loanListNotifier = ref.read(loanListProvider.notifier);
            return PopupMenuButton<int>(
              icon: Icon(Icons.filter_alt_outlined,
                  color: Theme.of(context).colorScheme.secondary),
              onSelected: (value) async {
                if (value == 3) {
                  final date = await showDateSelectorDialog(context);
                  if (date != null) {
                    suggestionsController.suggestions =
                        loanListNotifier.searchLoansByDateCreated(date);
                    suggestionsController.open();
                  }
                } else if (value == 4) {
                  final dateRange = await showDateRangeSelectorDialog(context);
                  if (dateRange != null) {
                    suggestionsController.suggestions =
                        loanListNotifier.searchLoansByDateRange(dateRange);
                    suggestionsController.open();
                  }
                } else if (value == 5) {
                  final mortgageMaterialType =
                      await showMortageMaterialTypeSelectorDialog(context);
                  if (mortgageMaterialType != null) {
                    suggestionsController.suggestions = loanListNotifier
                        .searchLoansByMortgageMaterialId(mortgageMaterialType);
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
            .read(loanListProvider.notifier)
            .searchLoansByDepositorName(searchTerm);
      case 2:
        return ref
            .read(loanListProvider.notifier)
            .searchLoansByRelativeName(searchTerm);
    }
    return [];
  }
}
