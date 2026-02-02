import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:flutter/material.dart';

class PhoneWidget extends StatelessWidget {
  final void Function(PhoneNumber)? onChanged;
  final String labelText;
  final TextEditingController? textEditingController;
  final String hint;
  final PhoneNumber initialValue;
  final AutovalidateMode autovalidateMode;
  final FocusNode? focusNode;
  final void Function()? onTap;
  final void Function()? onSubmit;
   PhoneWidget(
      {super.key,
      this.focusNode,
      this.onChanged,
      required this.labelText,
      required this.hint,
      required this.initialValue,
      this.textEditingController,
      this.onTap,
      this.onSubmit,
      this.autovalidateMode = AutovalidateMode.onUserInteraction});
   final List<Country> countries = [Country(name: "India", alpha2Code: "IN", alpha3Code: "IND", dialCode: "+91"),
     Country(name: "Nepal", alpha2Code: "NP", alpha3Code: "NPL", dialCode: "+977"),
     Country(name: "Bangladesh", alpha2Code: "BD", alpha3Code: "BGD", dialCode: "+880"),
     Country(name: "Bhutan", alpha2Code: "BT", alpha3Code: "BTN", dialCode: "+975"),
   ];
  @override
  Widget build(BuildContext context) {
    return InternationalPhoneNumberInput(
      defaultCountry: countries.first , filterFunction: (value) {
        return countries.where((country) => country.name.toLowerCase().contains(value.toLowerCase())).toList();
      },
      countries: [Country(name: "India", alpha2Code: "IN", alpha3Code: "IND", dialCode: "+91")], 
      onTap: onTap,
      onSubmit: onSubmit,
      focusNode: focusNode,
      textFieldController: textEditingController,
      keyboardAction: TextInputAction.done,
      searchBoxDecoration: InputDecoration(
        isDense: true,
        hintText: "Search Country by name or code",
        hintStyle: TextStyle(
            color:
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
            fontSize: 14),
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.secondary),
        labelText: "Search Country",
        border: const OutlineInputBorder(),
        errorStyle: TextStyle(fontSize: 11),
      ),
      inputDecoration: InputDecoration(
        // isDense: true,
        // contentPadding: EdgeInsets.symmetric(
        //   horizontal: 5,
        //   vertical: 5,
        // ),
        hintText: hint,
        hintStyle: TextStyle(
            color:
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
            fontSize: 14),
        label: FittedBox(
          child: Text(
            labelText,
            maxLines: 2,
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          ),
        ),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.secondary,
            )),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.secondary,
            )),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primaryFixedDim,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
        errorStyle: TextStyle(fontSize: 11),
      ),
      errorMessage: "Provide a valid number",
      onInputChanged: onChanged,
      // locale: Get.locale!.languageCode,
      selectorConfig: SelectorConfig(
        // trailingPadding: 5,
        // leadingPadding: 5,
        setSelectorButtonAsPrefixIcon: true,
        selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
        titleStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        subtitleStyle: TextStyle(color: Theme.of(context).colorScheme.secondary),
      ),
      ignoreBlank: false,
      autoValidateMode: autovalidateMode,
      flagStyle: TextStyle(fontSize: 200),
      textStyle: TextStyle(
          color: Theme.of(context).colorScheme.secondary, fontSize: 16),
      selectorTextStyle: TextStyle(color: Theme.of(context).colorScheme.secondary),
      initialValue: initialValue,
      formatInput: true,
      keyboardType:
          const TextInputType.numberWithOptions(signed: true, decimal: true),
      inputBorder: const OutlineInputBorder(),
    );
  }
}
