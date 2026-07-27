import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/loan_details.dart';
import 'package:loanx/widget/styled_text.dart';

class SearchAppBar extends HookWidget {
  const SearchAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final SuggestionsController<Loan> suggestionsController = useMemoized(
      () => SuggestionsController<Loan>(),
    );
    final filter = useState<int>(1);
    return Padding(
      // Keep the expanded search controls compact so they fit above the
      // portfolio summary on short screens.
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  return TypeAheadField<Loan>(
                    suggestionsController: suggestionsController,
                    suggestionsCallback: (searchTerm) =>
                        suggestionsCallback(searchTerm, filter.value, ref),
                    builder: (context, controller, focusNode) {
                      return TextField(
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Search loans',
                          hintText: 'Borrower, reference, or material',
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                      );
                    },
                    emptyBuilder: (context) {
                      return ListTile(
                        tileColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainer,
                        title: Text(
                          "No matching loans",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error) {
                      return ListTile(
                        title: Text(
                          "An error occurred",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      );
                    },
                    itemBuilder: (context, loan) {
                      final m = ref.watch(mortgageMaterialListProvider);
                      return m.when(
                        data: (data) {
                          if (data.isEmpty) {
                            return Center(child: Text("No data found"));
                          }
                          return ListTile(
                            title: Text(loan.depositorName),
                            leading: Text(
                              data
                                  .firstWhere(
                                    (mo) => mo.id == loan.mortgageMaterialId,
                                  )
                                  .name,
                            ),
                          );
                        },
                        error: (_, o) =>
                            Center(child: Text("An error occurred")),
                        loading: () =>
                            Center(child: CircularProgressIndicator()),
                      );
                    },
                    onSelected: (loan) {
                      ref
                          .read(mortgageMaterialListProvider)
                          .when(
                            data: (data) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LoanDetails(loan: loan),
                                ),
                              );
                            },
                            error: (_, e) {},
                            loading: () {},
                          );
                    },
                  );
                },
              ),
            ),
            Consumer(
              builder: (context, ref, child) {
                final loanListNotifier = ref.read(loanListProvider.notifier);
                return PopupMenuButton<int>(
                  tooltip: 'Search filters',
                  icon: const Icon(Icons.tune_rounded),
                  onSelected: (value) async {
                    if (value == 3) {
                      final date = await showDateSelectorDialog(context);
                      if (date != null) {
                        suggestionsController.suggestions = loanListNotifier
                            .searchLoansByDateCreated(date);
                        suggestionsController.open();
                      }
                    } else if (value == 4) {
                      final dateRange = await showDateRangeSelectorDialog(
                        context,
                      );
                      if (dateRange != null) {
                        suggestionsController.suggestions = loanListNotifier
                            .searchLoansByDateRange(dateRange);
                        suggestionsController.open();
                      }
                    } else if (value == 5) {
                      final mortgageMaterialType =
                          await showMortageMaterialTypeSelectorDialog(context);
                      if (mortgageMaterialType != null) {
                        suggestionsController.suggestions = loanListNotifier
                            .searchLoansByMortgageMaterialId(
                              mortgageMaterialType,
                            );
                        suggestionsController.open();
                      }
                    }
                    filter.value = value;
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem<int>(
                        value: 1,
                        child: StyledSubtitle('Depositor Name'),
                      ),
                      PopupMenuItem<int>(
                        value: 2,
                        child: StyledSubtitle('Relative Name'),
                      ),
                      PopupMenuItem<int>(
                        value: 3,
                        child: StyledSubtitle('Date Of Loan'),
                      ),
                      PopupMenuItem<int>(
                        value: 4,
                        child: StyledSubtitle('Date Range Of Loan'),
                      ),
                      PopupMenuItem<int>(
                        value: 5,
                        child: StyledSubtitle('Mortgage Material Type'),
                      ),
                    ];
                  },
                );
              },
            ),
            //   if(kDebugMode)
            //  ColorButton()
          ],
        ),
      ),
    );
  }

  Future<DateTime?> showDateSelectorDialog(BuildContext context) async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialEntryMode: DatePickerEntryMode.calendar,
    );
  }

  Future<DateTimeRange?> showDateRangeSelectorDialog(
    BuildContext context,
  ) async {
    DateTime now = DateTime.now();
    DateTime fiveYearsBack = DateTime(now.year - 5, now.month, now.day);
    DateTime fiveYearsAhead = DateTime(now.year + 5, now.month, now.day);
    return await showDateRangePicker(
      context: context,
      firstDate: fiveYearsBack,
      lastDate: fiveYearsAhead,
    );
  }

  Future<int?> showMortageMaterialTypeSelectorDialog(
    BuildContext context,
  ) async {
    return await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select pledged material'),
          content: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, child) {
                final mortgageMaterialTypes = ref.watch(
                  mortgageMaterialListProvider,
                );

                return mortgageMaterialTypes.when(
                  data: (data) => ListView.builder(
                    shrinkWrap: true,
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(data[index].name),
                        onTap: () {
                          Navigator.of(context).pop(data[index].id);
                        },
                      );
                    },
                  ),
                  error: (_, _) => Center(child: Text("An error occurred")),
                  loading: () => Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<Loan> suggestionsCallback(String searchTerm, int filter, WidgetRef ref) {
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
