import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/domain/country_catalog.dart';
import 'package:loanx/extension/loan_enum_localization.dart';
import 'package:loanx/extension/system_value_localization.dart';
import 'package:loanx/model/family_relation.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/model/mortgage_material.dart';
import 'package:loanx/model/weight_unit.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/service/currency_presentation.dart';
import 'package:loanx/widget/phone.dart';
import 'package:loanx/widget/snackbar.dart';
import 'package:loanx/widget/styled_dropdown.dart';
import 'package:loanx/widget/styled_text.dart';
import 'package:loanx/widget/styled_textfield.dart';

class LoanInput extends HookConsumerWidget {
  final Loan? loan;

  /// The reusable local-loan form. Borrower entry points should use
  /// `BorrowerLoanInput`, which passes this explicitly instead of depending on
  /// an onboarding preference.
  final bool? isBorrowerLoan;
  const LoanInput({super.key, this.loan, this.isBorrowerLoan});

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
    final borrowing = isBorrowerLoan ?? AppSettings.getUsesBorrowerExperience();
    final appBarTitle = loan == null
        ? borrowing
              ? 'Add loan from lender'.tr()
              : LocaleKeys.addLoanRecord.tr()
        : LocaleKeys.editLoanRecord.tr();
    final isDialogOpen = useState<bool>(false);
    final isSaving = useState<bool>(false);
    final familyRelations = ref.watch(familyRelationListProvider);
    final mortgageMaterials = ref.watch(mortgageMaterialListProvider);
    final weightUnits = ref.watch(weightUnitListProvider);
    final currentFamilyRelation = useState<FamilyRelation?>(null);
    final currentMortgageMaterial = useState<MortgageMaterial?>(null);
    final interestType = useState<InterestType>(
      InterestType.values[loan == null
          ? AppSettings.getInterestType()
          : loan!.interestType],
    );
    final interestFrequency = useState<InterestFrequency>(
      InterestFrequency.values[loan == null
          ? AppSettings.getInterestFrequency()
          : loan!.interestFrequency],
    );
    final mortgageTermYears = useState<int>(
      (loan?.mortgageTermYears ?? AppSettings.getHoldingPeriod()).clamp(1, 30),
    );
    final lockInDays = useState<int>(
      loan?.lockInDays ?? AppSettings.getDefaultLockInDays(),
    );
    final initialInterestRate =
        loan?.interestRate ??
        ref.read(interestRateProvider) ??
        AppSettings.getInterestRate();
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
        loan?.earlyRedemptionCharge ??
        AppSettings.getDefaultEarlyRedemptionCharge();
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
    final currency = useState<String>(
      loan?.currency ?? CurrencyPresentation.defaultCurrency,
    );
    useListenable(loanAmountController);
    final weightController = useTextEditingController(
      text: loan != null && loan!.weight > 0
          ? loan!.weight.toStringAsFixed(2)
          : '',
    );
    final mortgageWeight = useState<double>(loan?.weight ?? 0);
    final weightUnit = useState<String>(loan?.weightUnit ?? 'g');
    final weightUnitName = _weightUnitName(weightUnits.value, weightUnit.value);
    final earlyRedemptionChargeController = useTextEditingController(
      text: lockInDays.value > 0 && initialEarlyRedemptionCharge > 0
          ? initialEarlyRedemptionCharge.toStringAsFixed(2)
          : '',
    );
    final earlyRedemptionCharge = useState<double>(
      lockInDays.value > 0 ? initialEarlyRedemptionCharge : 0,
    );
    final lockInDaysController = useTextEditingController(
      text: lockInDays.value.toString(),
    );
    final additionalDetailsController = useTextEditingController(
      text: loan?.additionalDetails ?? '',
    );
    final termsAndConditionsController = useTextEditingController(
      text:
          loan?.termsAndConditions ??
          AppSettings.getDefaultTermsAndConditions(),
    );
    // This form is reused each time the add/edit route is opened. Persisting
    // its offset in PageStorage can make a new loan form reopen halfway down
    // the page, with the first fields hidden above the app bar.
    final scrollController = useScrollController(keepScrollOffset: false);
    final currentInterestRate =
        interestRateWhole.value + (interestRateFraction.value / 100);
    final lockInSummary = lockInDays.value == 0
        ? LocaleKeys.noLockIn.tr()
        : '${lockInDays.value} days · ${CurrencyPresentation.format(earlyRedemptionCharge.value, currency.value)}';

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
              // Container(
              //   padding: const EdgeInsets.all(18),
              //   decoration: BoxDecoration(
              //     color: Theme.of(context).colorScheme.primaryContainer,
              //     borderRadius: BorderRadius.circular(20),
              //   ),
              //   child: Row(
              //     children: [
              //       Icon(
              //         loan == null
              //             ? Icons.add_card_rounded
              //             : Icons.edit_note_rounded,
              //         color: Theme.of(context).colorScheme.primary,
              //         size: 32,
              //       ),
              //       const SizedBox(width: 14),
              //       Expanded(
              //         child: Column(
              //           crossAxisAlignment: CrossAxisAlignment.start,
              //           children: [
              //             Text(
              //               loan == null
              //                   ? 'Create a loan record'
              //                   : 'Update loan details',
              //               style: Theme.of(context).textTheme.titleMedium,
              //             ),
              //             const SizedBox(height: 2),
              //             Text(
              //               'Add the terms and borrower information below.',
              //               style: Theme.of(context).textTheme.bodyMedium,
              //             ),
              //           ],
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              // const SizedBox(height: 24),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: loan != null,
                  maintainState: true,
                  leading: const Icon(Icons.tune_rounded),
                  title: Text(LocaleKeys.loanTerms.tr()),
                  subtitle: Text(
                    '${interestType.value.localizedLabel} · '
                    '${currentInterestRate.toStringAsFixed(2)}% ${interestFrequency.value.localizedLabel} · '
                    '${mortgageTermYears.value} years · $lockInSummary',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        LocaleKeys.interestType.tr(),
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    RadioGroup<InterestType>(
                      groupValue: interestType.value,
                      onChanged: (value) {
                        if (value != null) interestType.value = value;
                      },
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _InterestRadioOption<InterestType>(
                            value: InterestType.simple,
                            label: LocaleKeys.simple.tr(),
                          ),
                          _InterestRadioOption<InterestType>(
                            value: InterestType.compound,
                            label: LocaleKeys.compound.tr(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        LocaleKeys.interestRate.tr(),
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
                        Expanded(
                          child: Text(
                            LocaleKeys.mortgageTerm.tr(),
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          LocaleKeys.yearsCount.tr(
                            namedArgs: {
                              'count': mortgageTermYears.value.toString(),
                            },
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: mortgageTermYears.value.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: LocaleKeys.yearsCount.tr(
                        namedArgs: {
                          'count': mortgageTermYears.value.toString(),
                        },
                      ),
                      onChanged: (value) {
                        mortgageTermYears.value = value.round();
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        LocaleKeys.interestFrequency2.tr(),
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
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _InterestRadioOption<InterestFrequency>(
                              value: InterestFrequency.monthly,
                              label: LocaleKeys.monthly.tr(),
                            ),
                            _InterestRadioOption<InterestFrequency>(
                              value: InterestFrequency.quarterly,
                              label: LocaleKeys.quarterly.tr(),
                            ),
                            _InterestRadioOption<InterestFrequency>(
                              value: InterestFrequency.yearly,
                              label: LocaleKeys.yearly.tr(),
                            ),
                            _InterestRadioOption<InterestFrequency>(
                              value: InterestFrequency.halfYearly,
                              label: LocaleKeys.halfYearly.tr(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: lockInDaysController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: LocaleKeys.lockInPeriod.tr(),
                        suffixText: 'days'.tr(),
                        helperText:
                            'Enter 0 for no lock-in. A fixed charge applies if the item is redeemed early.'
                                .tr(),
                        helperMaxLines: 2,
                      ),
                      validator: (value) {
                        final days = int.tryParse(value?.trim() ?? '');
                        if (days == null || days < 0) {
                          return 'Enter a valid number of days'.tr();
                        }
                        return null;
                      },
                      onChanged: (value) {
                        lockInDays.value = int.tryParse(value.trim()) ?? 0;
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
                        decoration: InputDecoration(
                          labelText: LocaleKeys.earlyRedemptionCharge.tr(),
                          hintText: LocaleKeys.fixedAmount.tr(),
                          prefixText:
                              '${CurrencyPresentation.countryForCurrency(currency.value).symbol} ',
                        ),
                        validator: (value) {
                          if (lockInDays.value == 0) return null;
                          final charge = double.tryParse(value?.trim() ?? '');
                          if (charge == null || charge <= 0) {
                            return LocaleKeys.enterAChargeGreaterThanZero.tr();
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
                borrowing
                    ? 'Lender information'.tr()
                    : LocaleKeys.borrowerInformation.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (borrowing) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.person_outline_rounded),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You can record a loan from a lender who is not registered with LoanX. Their information stays in your local loan record.'
                                .tr(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              PhoneWidget(
                key: ValueKey(loan?.id),
                labelText: borrowing
                    ? 'Lender mobile number'.tr()
                    : LocaleKeys.borrowerMobileNumber.tr(),
                textEditingController: phoneNumberController,
                hint: borrowing
                    ? 'Lender mobile number'.tr()
                    : LocaleKeys.borrowerMobileNumber.tr(),
                initialValue: PhoneNumber(
                  isoCode: "IN",
                  nsn: _nationalPhoneNumber(loan?.phoneNumber ?? ''),
                ),
              ),
              StyledTextField(
                failedValidationMessage:
                    (borrowing
                            ? 'Lender name cannot be empty'
                            : LocaleKeys.borrowerNameCanTBeEmpty)
                        .tr(),
                textEditingController: depositorController,
                hintText: borrowing
                    ? 'Lender name'.tr()
                    : LocaleKeys.borrowerName.tr(),
                labelText: borrowing
                    ? 'Lender name'.tr()
                    : LocaleKeys.borrowerName.tr(),
              ),
              StyledTextField(
                failedValidationMessage: LocaleKeys.addressCanTBeEmpty.tr(),
                textEditingController: addressController,
                hintText: borrowing
                    ? 'Lender address'.tr()
                    : LocaleKeys.borrowerAddress.tr(),
                labelText: borrowing
                    ? 'Lender address'.tr()
                    : LocaleKeys.borrowerAddress.tr(),
              ),
              StyledTextField(
                failedValidationMessage: LocaleKeys.referenceNameCanTBeEmpty
                    .tr(),
                textEditingController: relativeNameController,
                hintText: LocaleKeys.referenceName.tr(),
                labelText: LocaleKeys.referenceName.tr(),
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
                    hintText: LocaleKeys.familyRelation.tr(),
                    labelText: LocaleKeys.familyRelation.tr(),
                    onAddPressed: () {
                      isDialogOpen.value = true;
                      showAddDialog(
                        context,
                        ref,
                        LocaleKeys.addFamilyRelation2.tr(),
                        LocaleKeys.enterTheFamilyRelation2.tr(),
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
                failedValidationMessage: LocaleKeys.principalAmountCanTBeEmpty
                    .tr(),
                textEditingController: loanAmountController,
                hintText: LocaleKeys.principalAmount.tr(),
                labelText: LocaleKeys.principalAmount.tr(),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _CurrencyField(
                currency: currency.value,
                enabled: loan == null,
                onChanged: (value) => currency.value = value,
              ),
              if (loan != null)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Currency is fixed once a loan is created.'),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: LocaleKeys.mortgageWeight.tr(),
                        hintText: LocaleKeys.weight.tr(),
                        prefixIcon: Icon(Icons.scale_outlined),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final parsedWeight = double.tryParse(text);
                        if (parsedWeight == null || parsedWeight <= 0) {
                          return LocaleKeys.enterAValidWeight.tr();
                        }
                        return null;
                      },
                      onChanged: (value) {
                        mortgageWeight.value =
                            double.tryParse(value.trim()) ?? 0;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 116,
                    child: weightUnits.when(
                      data: (units) {
                        final symbols = units
                            .map((unit) => unit.symbol)
                            .toSet();
                        final selected = symbols.contains(weightUnit.value)
                            ? weightUnit.value
                            : (units.isEmpty
                                  ? weightUnit.value
                                  : units.first.symbol);
                        return DropdownButtonFormField<String>(
                          initialValue: selected,
                          decoration: InputDecoration(
                            labelText: LocaleKeys.unit.tr(),
                          ),
                          items: [
                            for (final unit in units)
                              DropdownMenuItem(
                                value: unit.symbol,
                                child: Text(unit.symbol),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) weightUnit.value = value;
                          },
                        );
                      },
                      loading: () => InputDecorator(
                        decoration: InputDecoration(
                          labelText: LocaleKeys.unit.tr(),
                        ),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (_, _) => InputDecorator(
                        decoration: InputDecoration(
                          labelText: LocaleKeys.unit.tr(),
                        ),
                        child: Text(weightUnit.value),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (mortgageWeight.value > 0) ...[
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.analytics_outlined),
                    title: Text(
                      LocaleKeys.loanValuePerUnit.tr(
                        namedArgs: {'unit': weightUnitName},
                      ),
                    ),
                    trailing: Text(
                      CurrencyPresentation.format(
                        (_parseDouble(loanAmountController.text) /
                            mortgageWeight.value),
                        currency.value,
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
                    hintText: LocaleKeys.pledgedMaterial.tr(),
                    labelText: LocaleKeys.pledgedMaterial.tr(),
                    onAddPressed: () {
                      isDialogOpen.value = true;
                      showAddDialog(
                        context,
                        ref,
                        LocaleKeys.addPledgedMaterial.tr(),
                        LocaleKeys.enterTheMaterialName.tr(),
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
                textEditingController: termsAndConditionsController,
                hintText: LocaleKeys.enterRepaymentCustodyOrOtherConditions
                    .tr(),
                labelText: LocaleKeys.termsAndConditionsOptional.tr(),
                maxLines: 4,
              ),
              StyledTextField(
                textEditingController: additionalDetailsController,
                hintText: LocaleKeys.notesOptional.tr(),
                labelText: LocaleKeys.notesOptional.tr(),
                maxLines: 3,
              ),
              Consumer(
                builder: (context, ref, child) {
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        if (isSaving.value) return;
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
                              'Select a family relation and pledged material'
                                  .tr(),
                            );
                            return;
                          }
                          final principal = _parseDouble(
                            loanAmountController.text,
                          );
                          if (principal <= 0) {
                            showErrorSnackBar(
                              context,
                              LocaleKeys.enterAPrincipalAmountGreaterThanZero
                                  .tr(),
                            );
                            return;
                          }
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
                            weightUnit: weightUnit.value,
                            mortgageTermYears: mortgageTermYears.value,
                            interestType: interestType.value,
                            interestRate: currentInterestRate,
                            interestFrequency: interestFrequency.value,
                            lockInDays: lockInDays.value,
                            earlyRedemptionCharge: earlyCharge,
                            currency: currency.value,
                            notes: additionalDetailsController.text.trim(),
                            termsAndConditions: termsAndConditionsController
                                .text
                                .trim(),
                          );
                          if (!confirmed || !context.mounted) return;
                          isSaving.value = true;
                          int status;
                          try {
                            status = await ref
                                .read(loanListProvider.notifier)
                                .add(
                                  loan,
                                  depositorController.text.trim(),
                                  phoneNumberController.text.trim(),
                                  relativeNameController.text.trim(),
                                  addressController.text.trim(),
                                  principal,
                                  weight,
                                  weightUnit.value,
                                  currentInterestRate,
                                  interestType.value.index,
                                  interestFrequency.value.index,
                                  mortgageTermYears.value,
                                  lockInDays.value,
                                  earlyCharge,
                                  additionalDetailsController.text.trim(),
                                  termsAndConditionsController.text.trim(),
                                  relation.id!,
                                  material.id!,
                                  currency.value,
                                  borrowing,
                                );
                          } catch (error, stackTrace) {
                            debugPrint('Unable to save loan: $error');
                            debugPrintStack(stackTrace: stackTrace);
                            if (context.mounted) {
                              showErrorSnackBar(
                                context,
                                LocaleKeys.unableToSaveLoan.tr(
                                  namedArgs: {'error': '$error'},
                                ),
                              );
                            }
                            return;
                          } finally {
                            if (context.mounted) isSaving.value = false;
                          }
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
                                  LocaleKeys.loanCreatedSuccessfully.tr(),
                                );
                              } else {
                                showSnackBar(
                                  context,
                                  LocaleKeys.loanUpdatedSuccessfully.tr(),
                                );
                              }
                            }
                          }
                        }
                      },
                      icon: isSaving.value
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        isSaving.value
                            ? LocaleKeys.saving.tr()
                            : loan == null
                            ? LocaleKeys.createLoan.tr()
                            : LocaleKeys.saveChanges.tr(),
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
    required String weightUnit,
    required int mortgageTermYears,
    required InterestType interestType,
    required double interestRate,
    required InterestFrequency interestFrequency,
    required int lockInDays,
    required double earlyRedemptionCharge,
    required String currency,
    required String notes,
    required String termsAndConditions,
  }) async {
    final money = CurrencyPresentation.formatter(currency);
    final details = <MapEntry<String, String>>[
      MapEntry('Borrower', borrowerName),
      MapEntry('Phone', phoneNumber),
      MapEntry('Address', address),
      MapEntry('Reference', '$referenceName · $relation'),
      MapEntry('Principal', money.format(principal)),
      MapEntry('Pledged item', pledgedMaterial),
      if (mortgageWeight > 0)
        MapEntry(
          'Mortgage weight',
          '${mortgageWeight.toStringAsFixed(2)} $weightUnit',
        ),
      if (mortgageWeight > 0)
        MapEntry(
          'Loan value per $weightUnit',
          money.format(principal / mortgageWeight),
        ),
      MapEntry(
        'Mortgage term',
        LocaleKeys.yearsCount.tr(
          namedArgs: {'count': mortgageTermYears.toString()},
        ),
      ),
      MapEntry(
        'Interest',
        '${interestRate.toStringAsFixed(2)}% · ${interestType.localizedLabel}',
      ),
      MapEntry('Interest frequency', interestFrequency.localizedLabel),
      MapEntry(
        'Lock-in period',
        lockInDays == 0
            ? LocaleKeys.noLockIn.tr()
            : LocaleKeys.daysCount.tr(
                namedArgs: {'count': lockInDays.toString()},
              ),
      ),
      if (lockInDays > 0)
        MapEntry(
          'Early redemption charge',
          money.format(earlyRedemptionCharge),
        ),
      if (notes.isNotEmpty) MapEntry('Notes', notes),
      if (termsAndConditions.isNotEmpty)
        MapEntry('Terms and conditions', termsAndConditions),
    ];

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.fact_check_outlined),
            title: Text(
              isEditing
                  ? LocaleKeys.verifyUpdatedLoanDetails.tr()
                  : LocaleKeys.verifyLoanDetails.tr(),
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
                                .tr()
                          : 'Review these details with the borrower. Create the record only after both of you agree.'
                                .tr(),
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
                child: Text(LocaleKeys.goBack.tr()),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  isEditing
                      ? LocaleKeys.confirmSave.tr()
                      : LocaleKeys.confirmCreate.tr(),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _weightUnitName(List<WeightUnit>? units, String symbol) {
    if (units == null) return symbol;
    for (final unit in units) {
      if (unit.symbol == symbol) return unit.localizedName.toLowerCase();
    }
    return symbol;
  }

  List<DropdownMenuItem<MortgageMaterial>> buildMenuMortgageMaterials(
    List<MortgageMaterial> mortgageMaterials,
    BuildContext context,
  ) => [
    for (var mortgageMaterial in mortgageMaterials)
      DropdownMenuItem(
        value: mortgageMaterial,
        child: Text(
          mortgageMaterial.localizedName,
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
          familyRelation.localizedName,
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
            child: Text(LocaleKeys.submit.tr()),
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

class _CurrencyField extends StatelessWidget {
  const _CurrencyField({
    required this.currency,
    required this.enabled,
    required this.onChanged,
  });

  final String currency;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = _currenciesByCode[currency];
    return InkWell(
      onTap: enabled
          ? () async {
              final selectedCurrency = await _showCurrencyPicker(context);
              if (selectedCurrency != null) onChanged(selectedCurrency);
            }
          : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Currency',
          prefixIcon: const Icon(Icons.currency_exchange_outlined),
          suffixIcon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? null : Theme.of(context).disabledColor,
          ),
        ),
        isEmpty: selected == null,
        child: Text(
          selected == null ? currency : _currencyLabel(selected),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<String?> _showCurrencyPicker(BuildContext context) async {
    final searchController = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) {
          final query = searchController.text.trim().toLowerCase();
          final currencies = _currenciesByCode.values.where((item) {
            if (query.isEmpty) return true;
            return item.name.toLowerCase().contains(query) ||
                item.symbol.toLowerCase().contains(query) ||
                item.currency.toLowerCase().contains(query);
          }).toList();

          final height = MediaQuery.sizeOf(context).height * .72;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
            ),
            child: SizedBox(
              height: height.clamp(360, 620),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.currency_exchange_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select currency',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Choose the currency used for this loan',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Search currency',
                      hintText: 'Search by name, symbol, or code',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                searchController.clear();
                                setState(() {});
                              },
                            ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: .55),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: currencies.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 42,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No currencies found',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Try a different name or code.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: currencies.length,
                            itemBuilder: (context, index) {
                              final item = currencies[index];
                              final isSelected = item.currency == currency;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Material(
                                  color: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 3,
                                    ),
                                    leading: Container(
                                      width: 46,
                                      height: 46,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        item.symbol,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      _currencyLabel(item),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? Icon(
                                            Icons.check_circle_rounded,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          )
                                        : const Icon(
                                            Icons.chevron_right_rounded,
                                          ),
                                    onTap: () => Navigator.of(
                                      sheetContext,
                                    ).pop(item.currency),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();
    return result;
  }
}

final _currenciesByCode = <String, CountryConfig>{
  for (final country in CountryCatalog.all) country.currency: country,
};

String _currencyLabel(CountryConfig currency) {
  return '${currency.name}. ${currency.symbol} (${currency.currency})';
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
          label.tr(),
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

class _InterestRadioOption<T> extends StatelessWidget {
  const _InterestRadioOption({required this.value, required this.label});

  final T value;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<T>(value: value),
        StyledSubtitle(label),
      ],
    ),
  );
}
