import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/db/fastdb.dart';
import 'package:mortgage/model/family_relation.dart';
import 'package:mortgage/model/item.dart';
import 'package:mortgage/model/loan.dart';
import 'package:mortgage/model/mortgage.dart';
import 'package:mortgage/model/mortgage_material.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/widget/snackbar.dart';
// import 'package:mortgage/widget/notched_dropdown.dart';
import 'package:mortgage/widget/styled_dropdown.dart';
import 'package:mortgage/widget/styled_textfield.dart';

// import '../algo/damerau_lavenstien.dart';

/// Interface to add a new or update an existing mortgage.
///
/// Supports adding or changing the text and setting the associated tag of
/// a task.
class MortgageInput extends HookConsumerWidget {
  final Mortgage? mortgage;

  /// If [mortgageId] is not null, the id of the mortgage to edit.
  /// Otherwise, will create a new task.
  const MortgageInput({super.key, this.mortgage});

  double _parseDouble(String input) {
    try {
      return double.parse(input);
    } catch (e) {
      try {
        return int.parse(input).toDouble();
      } catch (ie) {
        return 0.0;
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final appBarTitle = mortgage == null ? "Add Mortgage" : "Edit Mortgage";
    final isDialogOpen = useState<bool>(false);
    final items = ref.watch(itemListProvider);
    final familyRelations = ref.watch(familyRelationListProvider);
    final mortgageMaterials = ref.watch(mortgageMaterialListProvider);
    final currentItem = useState<Item?>(null);
    final currentFamilyRelation = useState<FamilyRelation?>(null);
    final currentMortgageMaterial = useState<MortgageMaterial?>(null);
    final interestType = useState<InterestType>(InterestType.values[
        mortgage == null ? FastDB.getInterestType() : mortgage!.interestType]);
    final interestFrequency = useState<InterestFrequency>(
        InterestFrequency.values[mortgage == null
            ? FastDB.getInterestFrequency()
            : mortgage!.interestFrequency]);
    final depositorController =
        useTextEditingController(text: mortgage?.depositorName ?? '');
    final addressController =
        useTextEditingController(text: mortgage?.address ?? '');
    final relativeNameController =
        useTextEditingController(text: mortgage?.relativeName ?? '');
    final loanAmountController =
        useTextEditingController(text: mortgage?.loanAmount.toString() ?? '');
    final interestRateController = useTextEditingController(
        text: mortgage?.interestRate.toString() ??
            ref.read(interestRateProvider).toString());
    final weightController =
        useTextEditingController(text: mortgage?.weight.toString() ?? '');
    final additionalDetailsController =
        useTextEditingController(text: mortgage?.additionalDetails ?? '');
    final scrollController = useScrollController();

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
          padding: EdgeInsets.only(left: 20, right: 20),
          child: Form(
            key: formKey,
            child: ListView(controller: scrollController, children: <Widget>[
              SizedBox(
                height: 10,
              ),
              items.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return SizedBox();
                    }
                    return StyledDropdown<Item>(
                      selectedValue: currentItem.value,
                      items: buildMenuItems(data, context),
                      onChanged: (value) {
                        if (value != null) {
                          currentItem.value = value;
                        }
                      },
                      hintText: "Item Name",
                      labelText: "Item Name",
                      onAddPressed: () {
                        isDialogOpen.value = true;
                        showAddDialog(
                            context,
                            ref,
                            'Add item',
                            'Enter the item name',
                            ref.read(itemListProvider.notifier).add);
                      },
                    );
                  },
                  error: (_, __) => Center(
                        child: Text("An Error occured"),
                      ),
                  loading: () => Center(child: CircularProgressIndicator())),
              mortgageMaterials.when(
                data: (data) {
                  return StyledDropdown<MortgageMaterial>(
                    selectedValue: currentMortgageMaterial.value,
                    items: buildMenuMortgageMaterials(data, context),
                    onChanged: (value) {
                      if (value != null) {
                        currentMortgageMaterial.value = value;
                      }
                    },
                    hintText: "Mortgage Material",
                    labelText: "Mortgage Material",
                    onAddPressed: () {
                      isDialogOpen.value = true;
                      showAddDialog(
                          context,
                          ref,
                          'Add Mortgage Material',
                          'Enter the mortgage material',
                          ref.read(mortgageMaterialListProvider.notifier).add);
                    },
                  );
                },
                error: (_, __) {
                  return const SizedBox();
                },
                loading: () => const SizedBox(),
              ),
              StyledTextField(
                failedValidationMessage: "Weight can't be empty",
                textEditingController: weightController,
                hintText: "Weight (in Grams)",
                labelText: "Weight",
                keyboardType: TextInputType.number,
              ),
              StyledTextField(
                failedValidationMessage: "Depositor Name can't be empty",
                textEditingController: depositorController,
                hintText: "Depositor Name",
                labelText: "Depositor Name",
              ),
              StyledTextField(
                failedValidationMessage: "Address can't be empty",
                textEditingController: addressController,
                hintText: "Depositor Address",
                labelText: "Depositor Address",
              ),
              StyledTextField(
                failedValidationMessage: "Relative Name can't be empty",
                textEditingController: relativeNameController,
                hintText: "Relative Name",
                labelText: "Relative Name",
              ),
              familyRelations.when(
                data: (data) {
                  return StyledDropdown<FamilyRelation>(
                    selectedValue: currentFamilyRelation.value,
                    items: buildMenuRelationTypes(data, context),
                    onChanged: (value) {
                      if (value != null) {
                        currentFamilyRelation.value = value;
                      }
                    },
                    hintText: "Family Relation",
                    labelText: "Family Relation",
                    onAddPressed: () {
                      isDialogOpen.value = true;
                      showAddDialog(
                          context,
                          ref,
                          'Add Family Relation',
                          'Enter the family relation',
                          ref.read(familyRelationListProvider.notifier).add);
                    },
                  );
                },
                error: (_, __) {
                  return const SizedBox();
                },
                loading: () => const SizedBox(),
              ),
              StyledTextField(
                failedValidationMessage: "Loan Amount can't be empty",
                textEditingController: loanAmountController,
                hintText: "Loan Amount",
                labelText: "Loan Amount",
                keyboardType: TextInputType.number,
              ),
              StyledTextField(
                failedValidationMessage: "Interest Rate can't be empty",
                textEditingController: interestRateController,
                hintText: "Interest Rate (in %)",
                labelText: "Interest Rate",
                keyboardType: TextInputType.number,
              ),
              StyledDropdown<InterestType>(
                  selectedValue: interestType.value,
                  labelText: 'Interest Type',
                  hintText: 'Interest Type',
                  items: [
                    DropdownMenuItem(
                      value: InterestType.simple,
                      child: Text('Simple Interest',
                          style: TextStyle(
                              fontSize: 15.0,
                              color: Theme.of(context).colorScheme.secondary)),
                    ),
                    DropdownMenuItem(
                      value: InterestType.compound,
                      child: Text('Compound Interest',
                          style: TextStyle(
                              fontSize: 15.0,
                              color: Theme.of(context).colorScheme.secondary)),
                    ),
                  ],
                  onChanged: (value) {
                    interestType.value = value ?? InterestType.simple;
                  }),
              StyledDropdown<InterestFrequency>(
                hintText: "Interest Frequency",
                labelText: "Interest Frequency",
                selectedValue: interestFrequency.value,
                items: [
                  DropdownMenuItem(
                    value: InterestFrequency.yearly,
                    child: Text('Yearly',
                        style: TextStyle(
                            fontSize: 15.0,
                            color: Theme.of(context).colorScheme.secondary)),
                  ),
                  DropdownMenuItem(
                    value: InterestFrequency.halfYearly,
                    child: Text('Half-Yearly',
                        style: TextStyle(
                            fontSize: 15.0,
                            color: Theme.of(context).colorScheme.secondary)),
                  ),
                  DropdownMenuItem(
                    value: InterestFrequency.quarterly,
                    child: Text('Quarterly',
                        style: TextStyle(
                            fontSize: 15.0,
                            color: Theme.of(context).colorScheme.secondary)),
                  ),
                  DropdownMenuItem(
                    value: InterestFrequency.monthly,
                    child: Text('Monthly',
                        style: TextStyle(
                            fontSize: 15.0,
                            color: Theme.of(context).colorScheme.secondary)),
                  ),
                ],
                onChanged: (value) {
                  interestFrequency.value = value ?? InterestFrequency.yearly;
                },
              ),
              StyledTextField(
                textEditingController: additionalDetailsController,
                hintText: "Additional Details",
                labelText: "Additional Details",
                maxLines: 3,
              ),
              Consumer(builder: (context, ref, child) {
                return Center(
                  child: OutlinedButton(
                    onPressed: () async {
                      if (formKey.currentState != null &&
                          formKey.currentState!.validate()) {
                        await ref.read(mortgageListProvider.notifier).add(
                            depositorController.text,
                            relativeNameController.text,
                            addressController.text,
                            _parseDouble(loanAmountController.text),
                            _parseDouble(interestRateController.text),
                            _parseDouble(weightController.text),
                            interestType.value.index,
                            interestFrequency.value.index,
                            additionalDetailsController.text,
                            currentItem.value!.id!,
                            currentFamilyRelation.value!.id!,
                            currentMortgageMaterial.value!.id!);
                        if (context.mounted) {
                          Navigator.pop(context);
                          showSnackBar(context, "Mortgage Added Successfully");
                        }
                      }
                    },
                    child: const Text('Save'),
                  ),
                );
              }),
              SizedBox(height: 10),
            ]),
          )),
      // resizeToAvoidBottomInset: true,
    );
  }

  List<DropdownMenuItem<Item>> buildMenuItems(
          List<Item> items, BuildContext context) =>
      [
        for (var item in items)
          DropdownMenuItem(
              value: item,
              child: Text(item.name,
                  style: TextStyle(
                      fontSize: 15.0,
                      color: Theme.of(context).colorScheme.secondary)))
      ];
  List<DropdownMenuItem<MortgageMaterial>> buildMenuMortgageMaterials(
          List<MortgageMaterial> mortgageMaterials, BuildContext context) =>
      [
        for (var mortgageMaterial in mortgageMaterials)
          DropdownMenuItem(
              value: mortgageMaterial,
              child: Text(
                mortgageMaterial.name,
                style: TextStyle(
                    fontSize: 15.0,
                    color: Theme.of(context).colorScheme.secondary),
              ))
      ];

  List<DropdownMenuItem<FamilyRelation>> buildMenuRelationTypes(
          List<FamilyRelation> familyRelations, BuildContext context) =>
      [
        for (var familyRelation in familyRelations)
          DropdownMenuItem(
              value: familyRelation,
              child: Text(
                familyRelation.name,
                style: TextStyle(
                    fontSize: 15.0,
                    color: Theme.of(context).colorScheme.secondary),
              ))
      ];

  Future<void> showAddDialog(
      BuildContext context,
      WidgetRef ref,
      String heading,
      String hintText,
      void Function(String text) onAddPressed) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        title: Text(heading),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: hintText),
          controller: controller,
        ),
        actions: [
          TextButton(
            child: const Text('Submit'),
            onPressed: () {
              onAddPressed(controller.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
    // Clear text after dialog is dismissed.
    controller.clear();
  }
}
