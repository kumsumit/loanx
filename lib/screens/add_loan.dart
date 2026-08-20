import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/db/fastdb.dart';
import 'package:loanx/extension/string.dart';
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

  String _nationalPhoneNumber(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    // Older records may contain the Indian country code as part of the
    // display-formatted value. The phone input expects the national number.
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    return digits;
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
    final interestType = useState<InterestType>(
      InterestType.values[loan == null
          ? FastDB.getInterestType()
          : loan!.interestType],
    );
    final interestFrequency = useState<InterestFrequency>(
      InterestFrequency.values[loan == null
          ? FastDB.getInterestFrequency()
          : loan!.interestFrequency],
    );
    final mortgageTermYears = useState<int>(
      (loan?.mortgageTermYears ?? FastDB.getHoldingPeriod()).clamp(1, 30),
    );
    final lockInDays = useState<int>(
      loan?.lockInDays ?? FastDB.getDefaultLockInDays(),
    );
    final initialInterestRate =
        loan?.interestRate ??
        ref.read(interestRateProvider) ??
        FastDB.getInterestRate();
    final interestRateWhole = useState<int>(
      initialInterestRate.floor().clamp(0, 50),
    );
    final interestRateFraction = useState<int>(
      ((initialInterestRate - initialInterestRate.floor()) * 100).round().clamp(
        0,
        99,
      ),
    );
    final interestRateWholeController = useMemoized(
      () => FixedExtentScrollController(initialItem: interestRateWhole.value),
    );
    final interestRateFractionController = useMemoized(
      () =>
          FixedExtentScrollController(initialItem: interestRateFraction.value),
    );
    useEffect(() {
      return () {
        interestRateWholeController.dispose();
        interestRateFractionController.dispose();
      };
    }, [interestRateWholeController, interestRateFractionController]);
    final initialEarlyRedemptionCharge =
        loan?.earlyRedemptionCharge ?? FastDB.getDefaultEarlyRedemptionCharge();
    final depositorController = useTextEditingController(
      text: loan?.depositorName ?? '',
    );
    final phoneNumberController = useTextEditingController(
      text: loan?.phoneNumber ?? '',
    );
    final addressController = useTextEditingController(
      text: loan?.address ?? '',
    );
    final relativeNameController = useTextEditingController(
      text: loan?.relativeName ?? '',
    );
    final loanAmountController = useTextEditingController(
      text: loan?.loanAmount.toString() ?? '',
    );
    useListenable(loanAmountController);
    final weightController = useTextEditingController(
      text: loan != null && loan!.weight > 0
          ? loan!.weight.toStringAsFixed(2)
          : '',
    );
    final mortgageWeight = useState<double>(loan?.weight ?? 0);
    final earlyRedemptionChargeController = useTextEditingController(
      text: lockInDays.value > 0 && initialEarlyRedemptionCharge > 0
          ? initialEarlyRedemptionCharge.toStringAsFixed(2)
          : '',
    );
    final earlyRedemptionCharge = useState<double>(
      lockInDays.value > 0 ? initialEarlyRedemptionCharge : 0,
    );
    final additionalDetailsController = useTextEditingController(
      text: loan?.additionalDetails ?? '',
    );
    final scrollController = useScrollController();
    final currentInterestRate =
        interestRateWhole.value + (interestRateFraction.value / 100);
    final lockInSummary = lockInDays.value == 0
        ? 'No lock-in'
        : '${lockInDays.value} days · ₹${earlyRedemptionCharge.value.toStringAsFixed(2)}';

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      body: Padding(
        padding: EdgeInsets.only(left: 20, right: 20),
        child: Form(
          key: formKey,
          child: ListView(
            controller: scrollController,
            children: <Widget>[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      loan == null
                          ? Icons.add_card_rounded
                          : Icons.edit_note_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loan == null
                                ? 'Create a loan record'
                                : 'Update loan details',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Add the terms and borrower information below.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: loan != null,
                  maintainState: true,
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Loan terms'),
                  subtitle: Text(
                    '${interestType.value.name.toSentenceCase()} · '
                    '${currentInterestRate.toStringAsFixed(2)}% ${interestFrequency.value.name.toSentenceCase()} · '
                    '${mortgageTermYears.value} years · $lockInSummary',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Interest type',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    RadioGroup<InterestType>(
                      groupValue: interestType.value,
                      onChanged: (value) {
                        if (value != null) interestType.value = value;
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Radio<InterestType>(value: InterestType.simple),
                          StyledSubtitle('Simple'),
                          SizedBox(width: 20),
                          Radio<InterestType>(value: InterestType.compound),
                          StyledSubtitle('Compound'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Interest rate',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            child: CupertinoPicker(
                              itemExtent: 32,
                              scrollController: interestRateWholeController,
                              selectionOverlay:
                                  const CupertinoPickerDefaultSelectionOverlay(
                                    background: Colors.transparent,
                                    capEndEdge: false,
                                  ),
                              onSelectedItemChanged: (val) {
                                interestRateWhole.value = val;
                              },
                              children: List.generate(
                                51,
                                (index) => StyledSubtitle(index.toString()),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 5),
                        Center(child: StyledSubtitle(".", fontSize: 20)),
                        SizedBox(width: 5),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            child: CupertinoPicker(
                              itemExtent: 32,
                              scrollController: interestRateFractionController,
                              selectionOverlay:
                                  const CupertinoPickerDefaultSelectionOverlay(
                                    background: Colors.transparent,
                                    capStartEdge: false,
                                  ),
                              onSelectedItemChanged: (val) {
                                interestRateFraction.value = val;
                              },
                              children: List.generate(
                                100,
                                (index) => StyledSubtitle(index.toString()),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 5),
                        Center(child: StyledSubtitle("%", fontSize: 20)),
                        SizedBox(width: 5),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Mortgage term',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('${mortgageTermYears.value} years'),
                      ],
                    ),
                    Slider(
                      value: mortgageTermYears.value.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: '${mortgageTermYears.value} years',
                      onChanged: (value) {
                        mortgageTermYears.value = value.round();
                      },
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Interest frequency',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.secondary,
                          width: 1,
                        ),
                      ),
                      child: RadioGroup<InterestFrequency>(
                        groupValue: interestFrequency.value,
                        onChanged: (value) {
                          if (value != null) interestFrequency.value = value;
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Radio<InterestFrequency>(
                                  value: InterestFrequency.monthly,
                                ),
                                StyledSubtitle('Monthly'),
                                SizedBox(width: 20),
                                Radio<InterestFrequency>(
                                  value: InterestFrequency.quarterly,
                                ),
                                StyledSubtitle('Quarterly'),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Radio<InterestFrequency>(
                                  value: InterestFrequency.yearly,
                                ),
                                StyledSubtitle('Yearly'),
                                SizedBox(width: 20),
                                Radio<InterestFrequency>(
                                  value: InterestFrequency.halfYearly,
                                ),
                                StyledSubtitle('Half-Yearly'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: lockInDays.value,
                      decoration: const InputDecoration(
                        labelText: 'Lock-in period',
                        helperText:
                            'A fixed charge applies if the item is redeemed early.',
                        helperMaxLines: 2,
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('No lock-in')),
                        DropdownMenuItem(value: 7, child: Text('7 days')),
                        DropdownMenuItem(value: 15, child: Text('15 days')),
                      ],
                      onChanged: (value) {
                        lockInDays.value = value ?? 0;
                        if (lockInDays.value == 0) {
                          earlyRedemptionChargeController.clear();
                          earlyRedemptionCharge.value = 0;
                        }
                      },
                    ),
                    if (lockInDays.value > 0) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: earlyRedemptionChargeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Early redemption charge',
                          hintText: 'Fixed amount',
                          prefixText: '₹ ',
                        ),
                        validator: (value) {
                          if (lockInDays.value == 0) return null;
                          final charge = double.tryParse(value?.trim() ?? '');
                          if (charge == null || charge <= 0) {
                            return 'Enter a charge greater than zero';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          earlyRedemptionCharge.value =
                              double.tryParse(value.trim()) ?? 0;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Borrower information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              StyledTextField(
                failedValidationMessage: "Borrower name can't be empty",
                textEditingController: depositorController,
                hintText: "Borrower name",
                labelText: "Borrower name",
              ),
              PhoneWidget(
                key: ValueKey(loan?.id),
                labelText: "Borrower mobile number",
                textEditingController: phoneNumberController,
                hint: "Borrower mobile number",
                initialValue: PhoneNumber(
                  isoCode: "IN",
                  nsn: _nationalPhoneNumber(loan?.phoneNumber ?? ''),
                ),
              ),
              StyledTextField(
                failedValidationMessage: "Address can't be empty",
                textEditingController: addressController,
                hintText: "Borrower address",
                labelText: "Borrower address",
              ),
              StyledTextField(
                failedValidationMessage: "Reference name can't be empty",
                textEditingController: relativeNameController,
                hintText: "Reference name",
                labelText: "Reference name",
              ),
              familyRelations.when(
                data: (data) {
                  if (data.isEmpty) {
                    return const SizedBox();
                  }

                  // Keep the user's choice when this widget rebuilds. Previously
                  // this was reset to the first item on every build, which made
                  // every selection appear as the first relation (for example,
                  // "Chacha").
                  final selectedRelation = data.where(
                    (item) => item.id == currentFamilyRelation.value?.id,
                  );
                  if (selectedRelation.isEmpty) {
                    currentFamilyRelation.value = loan == null
                        ? data.first
                        : data.firstWhere(
                            (item) => item.id == loan!.familyRelationId,
                            orElse: () => data.first,
                          );
                  } else {
                    // Use the instance from the current items list, as required
                    // by DropdownButtonFormField when provider data refreshes.
                    currentFamilyRelation.value = selectedRelation.first;
                  }
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
                        ref.read(familyRelationListProvider.notifier).add,
                      );
                    },
                  );
                },
                error: (_, _) {
                  return const SizedBox();
                },
                loading: () => const SizedBox(),
              ),
              StyledTextField(
                failedValidationMessage: "Principal amount can't be empty",
                textEditingController: loanAmountController,
                hintText: "Principal amount",
                labelText: "Principal amount",
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Mortgage weight',
                  hintText: 'Weight of the pledged item',
                  suffixText: 'grams',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final weight = double.tryParse(text);
                  if (weight == null || weight <= 0) {
                    return 'Enter a valid weight greater than zero';
                  }
                  return null;
                },
                onChanged: (value) {
                  mortgageWeight.value = double.tryParse(value.trim()) ?? 0;
                },
              ),
              if (mortgageWeight.value > 0) ...[
                const SizedBox(height: 8),
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.analytics_outlined),
                    title: const Text('Loan value per gram'),
                    subtitle: const Text('A quick valuation reference'),
                    trailing: Text(
                      NumberFormat.currency(
                        locale: 'en_IN',
                        symbol: '₹',
                        decimalDigits: 2,
                      ).format(
                        (_parseDouble(loanAmountController.text) /
                            mortgageWeight.value),
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              mortgageMaterials.when(
                data: (data) {
                  if (data.isEmpty) {
                    return const SizedBox();
                  }

                  // As above, only choose a default when the existing choice is
                  // unavailable. Do not overwrite a selection on rebuild.
                  final selectedMaterial = data.where(
                    (item) => item.id == currentMortgageMaterial.value?.id,
                  );
                  if (selectedMaterial.isEmpty) {
                    currentMortgageMaterial.value = loan == null
                        ? data.first
                        : data.firstWhere(
                            (item) => item.id == loan!.mortgageMaterialId,
                            orElse: () => data.first,
                          );
                  } else {
                    currentMortgageMaterial.value = selectedMaterial.first;
                  }
                  return StyledDropdown<MortgageMaterial>(
                    selectedValue: currentMortgageMaterial.value,
                    items: buildMenuMortgageMaterials(data, context),
                    onChanged: (value) {
                      if (value != null) {
                        currentMortgageMaterial.value = value;
                      }
                    },
                    hintText: "Pledged material",
                    labelText: "Pledged material",
                    onAddPressed: () {
                      isDialogOpen.value = true;
                      showAddDialog(
                        context,
                        ref,
                        'Add pledged material',
                        'Enter the material name',
                        ref.read(mortgageMaterialListProvider.notifier).add,
                      );
                    },
                  );
                },
                error: (_, _) {
                  return const SizedBox();
                },
                loading: () => const SizedBox(),
              ),
              StyledTextField(
                textEditingController: additionalDetailsController,
                hintText: "Notes (optional)",
                labelText: "Notes (optional)",
                maxLines: 3,
              ),
              Consumer(
                builder: (context, ref, child) {
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        if (formKey.currentState != null &&
                            formKey.currentState!.validate()) {
                          final relation = currentFamilyRelation.value;
                          final material = currentMortgageMaterial.value;
                          if (relation == null ||
                              relation.id == null ||
                              material == null ||
                              material.id == null) {
                            showSnackBar(
                              context,
                              'Select a family relation and pledged material',
                            );
                            return;
                          }
                          final principal = _parseDouble(
                            loanAmountController.text,
                          );
                          final earlyCharge = lockInDays.value == 0
                              ? 0.0
                              : _parseDouble(
                                  earlyRedemptionChargeController.text,
                                );
                          final weight = _parseDouble(weightController.text);
                          final confirmed = await _confirmSave(
                            context,
                            isEditing: loan != null,
                            borrowerName: depositorController.text.trim(),
                            phoneNumber: phoneNumberController.text.trim(),
                            address: addressController.text.trim(),
                            referenceName: relativeNameController.text.trim(),
                            relation: relation.name,
                            principal: principal,
                            pledgedMaterial: material.name,
                            mortgageWeight: weight,
                            mortgageTermYears: mortgageTermYears.value,
                            interestType: interestType.value,
                            interestRate: currentInterestRate,
                            interestFrequency: interestFrequency.value,
                            lockInDays: lockInDays.value,
                            earlyRedemptionCharge: earlyCharge,
                            notes: additionalDetailsController.text.trim(),
                          );
                          if (!confirmed || !context.mounted) return;
                          final status = await ref
                              .read(loanListProvider.notifier)
                              .add(
                                loan,
                                depositorController.text,
                                phoneNumberController.text,
                                relativeNameController.text,
                                addressController.text,
                                principal,
                                weight,
                                currentInterestRate,
                                interestType.value.index,
                                interestFrequency.value.index,
                                mortgageTermYears.value,
                                lockInDays.value,
                                earlyCharge,
                                additionalDetailsController.text,
                                relation.id!,
                                material.id!,
                              );
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
                                  context,
                                  "Loan created successfully",
                                );
                              } else {
                                showSnackBar(
                                  context,
                                  "Loan updated successfully",
                                );
                              }
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        loan == null ? 'Create loan' : 'Save changes',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      // resizeToAvoidBottomInset: true,
    );
  }

  Future<bool> _confirmSave(
    BuildContext context, {
    required bool isEditing,
    required String borrowerName,
    required String phoneNumber,
    required String address,
    required String referenceName,
    required String relation,
    required double principal,
    required String pledgedMaterial,
    required double mortgageWeight,
    required int mortgageTermYears,
    required InterestType interestType,
    required double interestRate,
    required InterestFrequency interestFrequency,
    required int lockInDays,
    required double earlyRedemptionCharge,
    required String notes,
  }) async {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final details = <MapEntry<String, String>>[
      MapEntry('Borrower', borrowerName),
      MapEntry('Phone', phoneNumber),
      MapEntry('Address', address),
      MapEntry('Reference', '$referenceName · $relation'),
      MapEntry('Principal', currency.format(principal)),
      MapEntry('Pledged item', pledgedMaterial),
      if (mortgageWeight > 0)
        MapEntry('Mortgage weight', '${mortgageWeight.toStringAsFixed(2)} g'),
      if (mortgageWeight > 0)
        MapEntry(
          'Loan value per gram',
          currency.format(principal / mortgageWeight),
        ),
      MapEntry('Mortgage term', '$mortgageTermYears years'),
      MapEntry(
        'Interest',
        '${interestRate.toStringAsFixed(2)}% · ${interestType.name.toSentenceCase()}',
      ),
      MapEntry('Interest frequency', interestFrequency.name.toSentenceCase()),
      MapEntry(
        'Lock-in period',
        lockInDays == 0 ? 'No lock-in' : '$lockInDays days',
      ),
      if (lockInDays > 0)
        MapEntry(
          'Early redemption charge',
          currency.format(earlyRedemptionCharge),
        ),
      if (notes.isNotEmpty) MapEntry('Notes', notes),
    ];

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.fact_check_outlined),
            title: Text(
              isEditing ? 'Verify updated loan details' : 'Verify loan details',
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing
                          ? 'Review the updated details with the borrower. Save the changes only after both of you agree.'
                          : 'Review these details with the borrower. Create the record only after both of you agree.',
                    ),
                    const SizedBox(height: 16),
                    for (final detail in details)
                      _ConfirmationDetail(
                        label: detail.key,
                        value: detail.value,
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Go back'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.check_rounded),
                label: Text(isEditing ? 'Confirm & save' : 'Confirm & create'),
              ),
            ],
          ),
        ) ??
        false;
  }

  List<DropdownMenuItem<MortgageMaterial>> buildMenuMortgageMaterials(
    List<MortgageMaterial> mortgageMaterials,
    BuildContext context,
  ) => [
    for (var mortgageMaterial in mortgageMaterials)
      DropdownMenuItem(
        value: mortgageMaterial,
        child: Text(
          mortgageMaterial.name,
          style: TextStyle(
            fontSize: 15.0,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
  ];

  List<DropdownMenuItem<FamilyRelation>> buildMenuRelationTypes(
    List<FamilyRelation> familyRelations,
    BuildContext context,
  ) => [
    for (var familyRelation in familyRelations)
      DropdownMenuItem(
        value: familyRelation,
        child: Text(
          familyRelation.name,
          style: TextStyle(
            fontSize: 15.0,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
  ];

  Future<void> showAddDialog(
    BuildContext context,
    WidgetRef ref,
    String heading,
    String hintText,
    void Function(String text) onAddPressed,
  ) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
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

class _ConfirmationDetail extends StatelessWidget {
  const _ConfirmationDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
