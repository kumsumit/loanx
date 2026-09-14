import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:flutter/material.dart';
import 'package:loanx/domain/country_catalog.dart';

class PhoneWidget extends StatefulWidget {
  final void Function(PhoneNumber)? onChanged;
  final String labelText;
  final TextEditingController? textEditingController;
  final String hint;
  final PhoneNumber initialValue;
  final AutovalidateMode autovalidateMode;
  final FocusNode? focusNode;
  final void Function()? onTap;
  final void Function()? onSubmit;

  const PhoneWidget({
    super.key,
    this.focusNode,
    this.onChanged,
    required this.labelText,
    required this.hint,
    required this.initialValue,
    this.textEditingController,
    this.onTap,
    this.onSubmit,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  State<PhoneWidget> createState() => _PhoneWidgetState();
}

class _PhoneWidgetState extends State<PhoneWidget> {
  final TextEditingController _fallbackController = TextEditingController();

  TextEditingController get _effectiveController =>
      widget.textEditingController ?? _fallbackController;

  void _syncController(String value) {
    final controller = _effectiveController;
    if (controller.text == value) return;

    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  void initState() {
    super.initState();
    _syncController(widget.initialValue.nsn);
  }

  @override
  void didUpdateWidget(covariant PhoneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousPhone = oldWidget.initialValue.nsn;
    final currentPhone = widget.initialValue.nsn;
    if (previousPhone != currentPhone && currentPhone.isNotEmpty) {
      _syncController(currentPhone);
    }
  }

  @override
  void dispose() {
    _fallbackController.dispose();
    super.dispose();
  }

  final List<Country> countries = CountryCatalog.phoneCountries;
  @override
  Widget build(BuildContext context) {
    return MaterialInternationalPhoneNumber(
      defaultCountry: CountryCatalog.byCode(
        widget.initialValue.isoCode,
      ).phoneCountry,
      filterFunction: (value) {
        return countries
            .where(
              (country) =>
                  country.name.toLowerCase().contains(value.toLowerCase()),
            )
            .toList();
      },
      countries: countries,
      onTap: widget.onTap,
      onSubmit: widget.onSubmit,
      focusNode: widget.focusNode,
      textFieldController: _effectiveController,
      keyboardAction: TextInputAction.done,
      searchBoxDecoration: InputDecoration(
        isDense: true,
        hintText: LocaleKeys.searchCountryByNameOrCode.tr(),
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.secondary),
        labelText: LocaleKeys.searchCountry.tr(),
        border: const OutlineInputBorder(),
        errorStyle: TextStyle(fontSize: 11),
      ),
      inputDecoration: InputDecoration(
        // isDense: true,
        // contentPadding: EdgeInsets.symmetric(
        //   horizontal: 5,
        //   vertical: 5,
        // ),
        hintText: widget.hint,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        label: FittedBox(
          child: Text(
            widget.labelText,
            maxLines: 2,
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primaryFixedDim,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
        errorStyle: TextStyle(fontSize: 11),
      ),
      errorMessage: LocaleKeys.provideAValidNumber.tr(),
      onInputChanged: (phoneNumber) {
        widget.onChanged?.call(phoneNumber);
      },
      // locale: Get.locale!.languageCode,
      selectorConfig: SelectorConfig(
        // trailingPadding: 5,
        // leadingPadding: 5,
        setSelectorButtonAsPrefixIcon: true,
        selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
        titleStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        subtitleStyle: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      ignoreBlank: false,
      autoValidateMode: widget.autovalidateMode,
      flagStyle: TextStyle(fontSize: 20),
      textStyle: TextStyle(
        color: Theme.of(context).colorScheme.secondary,
        fontSize: 16,
      ),
      selectorTextStyle: TextStyle(
        color: Theme.of(context).colorScheme.secondary,
      ),
      initialValue: widget.initialValue,
      formatInput: true,
      keyboardType: TextInputType.phone,
      inputBorder: const OutlineInputBorder(),
    );
  }
}
