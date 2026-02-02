import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/db/fastdb.dart';
import 'package:loanx/model/family_relation.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/model/mortgage_material.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/widget/phone.dart';
import 'package:loanx/widget/snackbar.dart';
import 'package:loanx/widget/styled_dropdown.dart';
import 'package:loanx/widget/styled_text.dart';
import 'package:loanx/widget/styled_textfield.dart';

class LoanInput extends HookConsumerWidget {
  final Loan? loan;
  const LoanInput({super.key, this.loan});

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
    final appBarTitle = loan == null ? "Add Loan Record" : "Edit Loan Record";
    final isDialogOpen = useState<bool>(false);
    final familyRelations = ref.watch(familyRelationListProvider);
    final mortgageMaterials = ref.watch(mortgageMaterialListProvider);
    final currentFamilyRelation = useState<FamilyRelation?>(null);
    final currentMortgageMaterial = useState<MortgageMaterial?>(null);
    final interestType = useState<InterestType>(InterestType
        .values[loan == null ? FastDB.getInterestType() : loan!.interestType]);
    final interestFrequency = useState<InterestFrequency>(
        InterestFrequency.values[loan == null
            ? FastDB.getInterestFrequency()
            : loan!.interestFrequency]);
    final depositorController =
        useTextEditingController(text: loan?.depositorName ?? '');
    final phoneNumberController =
        useTextEditingController(text: loan?.phoneNumber ?? '');
    final addressController =
        useTextEditingController(text: loan?.address ?? '');
    final relativeNameController =
        useTextEditingController(text: loan?.relativeName ?? '');
    final loanAmountController =
        useTextEditingController(text: loan?.loanAmount.toString() ?? '');
    final additionalDetailsController =
        useTextEditingController(text: loan?.additionalDetails ?? '');
    final scrollController = useScrollController();
    List<String> interestRateString =
        (loan?.interestRate ?? ref.read(interestRateProvider))
            .toString()
            .split(".");
    if (interestRateString[1].length > 2) {
      interestRateString[1] = interestRateString[1].substring(0, 2);
    } else if (interestRateString[1].length == 1) {
      interestRateString[1] = "${interestRateString[1]}0";
    }

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        title: Text(appBarTitle),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
          padding: EdgeInsets.only(left: 20, right: 20),
          child: Form(
            key: formKey,
            child: ListView(controller: scrollController, children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<InterestType>(
                    value: InterestType.simple,
                    groupValue: interestType.value,
                    onChanged: (InterestType? value) {
                      if (value != null) {
                        interestType.value = value;
                      }
                    },
                  ),
                  StyledSubtitle('Simple'),
                  SizedBox(width: 20),
                  Radio<InterestType>(
                    value: InterestType.compound,
                    groupValue: interestType.value,
                    onChanged: (InterestType? value) {
                      if (value != null) {
                        interestType.value = value;
                      }
                    },
                  ),
                  StyledSubtitle('Compound'),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.secondary,
                          )),
                      child: CupertinoPicker(
                        itemExtent: 32,
                        scrollController: FixedExtentScrollController(
                            initialItem:
                                int.tryParse(interestRateString[0]) ?? 2),
                        selectionOverlay:
                            const CupertinoPickerDefaultSelectionOverlay(
                          background: Colors.transparent,
                          capEndEdge: false,
                        ),
                        onSelectedItemChanged: (val) {
                          interestRateString[0] = val.toString();
                        },
                        children: List.generate(
                          51,
                          (index) => StyledSubtitle(index.toString()),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Center(
                    child: StyledSubtitle(
                      ".",fontSize: 20,
                    ),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.secondary,
                          )),
                      child: CupertinoPicker(
                        itemExtent: 32,
                        scrollController: FixedExtentScrollController(
                          initialItem:
                              int.tryParse(interestRateString[1]) ?? 51,
                        ),
                        selectionOverlay:
                            const CupertinoPickerDefaultSelectionOverlay(
                          background: Colors.transparent,
                          capStartEdge: false,
                        ),
                        onSelectedItemChanged: (val) {
                          final valStr = val.toString();
                          if (valStr.length > 2) {
                            interestRateString[1] = valStr.substring(0, 2);
                          } else if (interestRateString[1].length == 1) {
                            interestRateString[1] = "0$valStr";
                          }
                        },
                        children: List.generate(
                          100,
                          (index) => StyledSubtitle(index.toString()),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Center(
                    child: StyledSubtitle(
                      "%",fontSize: 20,
                    ),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                ],
              ),
              SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondary,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Radio<InterestFrequency>(
                        value: InterestFrequency.monthly,
                        groupValue: interestFrequency.value,
                        onChanged: (InterestFrequency? value) {
                          if (value != null) {
                            interestFrequency.value = value;
                          }
                        },
                      ),
                      StyledSubtitle('Monthly'),
                      SizedBox(width: 20),
                      Radio<InterestFrequency>(
                        value: InterestFrequency.quarterly,
                        groupValue: interestFrequency.value,
                        onChanged: (InterestFrequency? value) {
                          if (value != null) {
                            interestFrequency.value = value;
                          }
                        },
                      ),
                      StyledSubtitle('Half-Yearly'),
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Radio<InterestFrequency>(
                        value: InterestFrequency.yearly,
                        groupValue: interestFrequency.value,
                        onChanged: (InterestFrequency? value) {
                          if (value != null) {
                            interestFrequency.value = value;
                          }
                        },
                      ),
                      StyledSubtitle('Quarterly'),
                      SizedBox(width: 20),
                      Radio<InterestFrequency>(
                        value: InterestFrequency.halfYearly,
                        groupValue: interestFrequency.value,
                        onChanged: (InterestFrequency? value) {
                          if (value != null) {
                            interestFrequency.value = value;
                          }
                        },
                      ),
                      StyledSubtitle('Yearly'),
                    ])
                  ],
                ),
              ),
              SizedBox(height: 10),
              StyledTextField(
                failedValidationMessage: "Depositor Name can't be empty",
                textEditingController: depositorController,
                hintText: "Depositor Name",
                labelText: "Depositor Name",
              ),
              PhoneWidget(labelText: "Depositor Mobile Number",
              textEditingController: phoneNumberController,
               hint: "Depositor Mobile Number",
                initialValue: PhoneNumber(isoCode: "IN", nsn: "")),
              // StyledTextField(
              //   failedValidationMessage:
              //       "Depositor Mobile Number can't be empty",
              //   textEditingController: phoneNumberController,
              //   hintText: "Depositor Mobile Number",
              //   labelText: "Depositor Mobile Number",
              //   keyboardType: TextInputType.phone,
              // ),
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
                  if (data.isEmpty) {
                    return SizedBox();
                  }
                  currentFamilyRelation.value = loan == null
                      ? data[0]
                      : data.firstWhere(
                          (item) => item.id == loan!.familyRelationId);
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
              mortgageMaterials.when(
                data: (data) {
                  if (data.isEmpty) {
                    return SizedBox();
                  }
                  currentMortgageMaterial.value = loan == null
                      ? data[0]
                      : data.firstWhere(
                          (item) => item.id == loan!.mortgageMaterialId);
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
                        final status = await ref
                            .read(loanListProvider.notifier)
                            .add(
                                loan,
                                depositorController.text,
                                phoneNumberController.text,
                                relativeNameController.text,
                                addressController.text,
                                _parseDouble(loanAmountController.text),
                                _parseDouble(interestRateString.join(".")),
                                interestType.value.index,
                                interestFrequency.value.index,
                                additionalDetailsController.text,
                                currentFamilyRelation.value!.id!,
                                currentMortgageMaterial.value!.id!);
                        if (status > 0) {
                          if (loan != null) {
                          ref
                              .read(loanSelectionListProvider.notifier)
                              .remove(loan!.id ?? 0);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            if (loan == null) {
                              showSnackBar(
                                  context, "Record Added Successfully");
                            } else {
                              showSnackBar(
                                  context, "Record Updated Successfully");
                            }
                          }
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
