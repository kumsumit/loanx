import 'package:flutter/material.dart';
import 'package:flutter_color_picker_plus/flutter_color_picker_plus.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/model/family_relation.dart';
import 'package:mortgage/model/item.dart';
import 'package:mortgage/model/loan.dart';
import 'package:mortgage/model/mortgage.dart';
import 'package:mortgage/model/mortgage_material.dart';
import 'package:mortgage/provider/provider.dart';

class MortgageListView extends StatelessWidget {
  const MortgageListView({super.key});

  Widget _itemBuilder(
      BuildContext context,
      Mortgage mortgage,
      Iterable<Item> items,
      Iterable<MortgageMaterial> mortgageMaterials,
      Iterable<FamilyRelation> familyRelations) {
    return Consumer(builder: (context, ref, child) {
      final item = items.firstWhere((item) => item.id == mortgage.itemId);
      return GestureDetector(
        onDoubleTap: () {
          final familyRelation = familyRelations.firstWhere((familyRelation) =>
              familyRelation.id == mortgage.familyRelationId);
          final mortgageMaterial = mortgageMaterials.firstWhere(
              (mortgageMaterial) =>
                  mortgageMaterial.id == mortgage.mortgageMaterialId);

          showDescriptionDialog(context, mortgage, item, familyRelation, mortgageMaterial);
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
                    ref.read(mortgageListProvider.notifier).update(mortgage);
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
      final mortgages = ref.watch(mortgageListProvider);
      final items = ref.watch(itemListProvider);
      final mortgageMaterials = ref.watch(mortgageMaterialListProvider);
      final familyRelations = ref.watch(familyRelationListProvider);
      if (mortgages.isEmpty ||
          items.isEmpty ||
          mortgageMaterials.isEmpty ||
          familyRelations.isEmpty) return Center(child: CircularProgressIndicator());
      return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          itemCount: mortgages.length,
          itemBuilder: (c, i) {
            return _itemBuilder(
                c, mortgages[i], items, mortgageMaterials, familyRelations);
          });
    }));
  }
}

class ColorCircle extends StatelessWidget {
  const ColorCircle({super.key, required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) {
    return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                )
              ),
            ),
             Text(text,textAlign: TextAlign.center, style: TextStyle( fontSize: 12)),
          ],
        );
  }
}

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
                return ListTile(
                  title: Text(mortgage.depositorName),
                  leading:
                      Text(m.firstWhere((mo) => mo.id == mortgage.itemId).name),
                );
              },
              onSelected: (mortgage) {
                      final item = ref.watch(itemListProvider).firstWhere((item) => item.id == mortgage.itemId);
                      final familyRelation = ref.watch(familyRelationListProvider).firstWhere((familyRelation) => familyRelation.id == mortgage.familyRelationId);
                      final mortgageMaterial = ref.watch(mortgageMaterialListProvider).firstWhere((mortgageMaterial) => mortgageMaterial.id == mortgage.mortgageMaterialId);
              showDescriptionDialog(context, mortgage, item, familyRelation, mortgageMaterial);
              },
            );
          })),
          Consumer(builder: (context, ref, child) {
            return PopupMenuButton<int>(
              icon: Icon(Icons.filter_alt_outlined,
                  color: ref.read(themeModeManagerProvider).index== 1
                      ? Theme.of(context).colorScheme.secondaryFixed
                      : Theme.of(context).colorScheme.primary),
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
          IconButton(
              icon: Icon(Icons.color_lens),
              onPressed: () {
                _showDialog(context);
              })
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

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Row(
          children: [
            const Text('Pick a color!'),
            Consumer(builder: (context, ref, child) {
              return IconButton(
                icon: Icon(Icons.light_mode),
                onPressed: ref.read(themeModeManagerProvider.notifier).set,
              );
            }),
          ],
        ),
        content: Consumer(builder: (context, ref, child) {
          final color = ref.watch(pickerColorProvider);
          return ColorPicker(
              pickerColor:
                  Color(int.parse('FF${color.substring(1)}', radix: 16)),
              onColorChanged: (color) async {
                ref.read(pickerColorProvider.notifier).set(color);
                await ref.read(appColorProvider.notifier).set();
              });
        }),
        actions: <Widget>[
          ElevatedButton(
            child: const Text('Got it'),
            onPressed: () {
              // Navigator.of(context).pop();
              _showBottomSheet(context);
            },
          )
        ],
      ),
    );
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return GridView(
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // Number of columns in the grid
              crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.5,
            ),
            children: [
              ColorCircle(
                  color: Theme.of(context).colorScheme.primary,
                  text: "Primary"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  text: "onPrimary"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  text: "primaryContainer"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  text: "onPrimaryContainer"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.primaryFixed,
                  text: "PrimaryFixed"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onPrimaryFixed,
                  text: "onPrimaryFixed"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.primaryFixedDim,
                  text: "primaryFixedDim"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onPrimaryFixedVariant,
                  text: "onPrimaryFixedVariant"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.secondary,
                  text: "secondary"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onSecondary,
                  text: "onSecondary"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  text: "secondaryContainer"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  text: "onSecondaryContainer"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.secondaryFixed,
                  text: "secondaryFixed"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onSecondaryFixed,
                  text: "onSecondaryFixed"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.secondaryFixedDim,
                  text: "secondaryFixedDim"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onSecondaryFixedVariant,
                  text: "onSecondaryFixedVariant"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.tertiary,
                  text: "tertiary"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onTertiary,
                  text: "onTertiary"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  text: "tertiaryContainer"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  text: "onTertiaryContainer"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.tertiaryFixed,
                  text: "tertiaryFixed"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onTertiaryFixed,
                  text: "onTertiaryFixed"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.tertiaryFixedDim,
                  text: "tertiaryFixedDim"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onTertiaryFixedVariant,
                  text: "onTertiaryFixedVariant"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onSurface,
                  text: "onSurface"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  text: "onSurfaceVariant"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.inversePrimary,
                  text: "inversePrimary"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.inverseSurface,
                  text: "inverseSurface"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.outline,
                  text: "outline"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  text: "outlineVariant"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onError,
                  text: "onError"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  text: "onErrorContainer"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.error, text: "error"),
              ColorCircle(
                  color: Theme.of(context).colorScheme.errorContainer,
                  text: "errorContainer"),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Dismiss the bottom sheet
                },
                child: Text('Close'),
              ),
            ]);
      },
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
              if (items.isEmpty) return SizedBox();
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(items[index].name),
                    onTap: () {
                      Navigator.of(context).pop(index);
                    },
                  );
                },
              );
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
              return ListView.builder(
                itemCount: mortgageMaterialTypes.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(mortgageMaterialTypes[index].name),
                    onTap: () {
                      Navigator.of(context).pop(index);
                    },
                  );
                },
              );
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

showDescriptionDialog( BuildContext context, Mortgage mortgage, Item item, FamilyRelation familyRelation, MortgageMaterial mortgageMaterial) {
  final loan = Loan(principal: mortgage.loanAmount, interestRate: mortgage.interestRate, duration: DateTime.now().difference(mortgage.dateCreated).inDays, interestType: InterestType.simple, compoundingFrequency: CompoundingFrequency.monthly);
  final double interest = loan.calculateInterest();
  debugPrint(interest.toString());
  showDialog(
              context: context,
              builder: (context) => AlertDialog(
                    title: Text('Mortgage Details'),
                    content: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: [
                            DataColumn(label: SizedBox()),
                            DataColumn(label: SizedBox()),
                          ],
                          rows: [
                            DataRow(cells: [
                              DataCell(Text('Calculated Interest')),
                              DataCell(Text(interest.toString()))
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Depositor Name')),
                              DataCell(Text(mortgage.depositorName))
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Relative Name')),
                              DataCell(Text(mortgage.relativeName))
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Address')),
                              DataCell(Text(mortgage.address))
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Loan Amount')),
                              DataCell(Text(mortgage.loanAmount.toString()))
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Interest Rate')),
                              DataCell(Text(mortgage.interestRate.toString()))
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Interest Type')),
                              DataCell(Text(mortgage.interestType.toString()))
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Compounding Frequency')),
                              DataCell(Text(mortgage.compoundingFrequency.toString()))
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Weight')),
                              DataCell(Text(mortgage.weight.toString()))
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Additional Details')),
                              DataCell(Text(mortgage.additionalDetails))
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Item')),
                              DataCell(Text(item.name))
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Family Relation')),
                              DataCell(Text(familyRelation.name))
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Mortgage Material')),
                              DataCell(Text(mortgageMaterial.name))
                            ]),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  ));
}