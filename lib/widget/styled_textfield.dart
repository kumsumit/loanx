import 'package:flutter/material.dart';

class StyledTextField extends StatelessWidget {
  const StyledTextField(
      {super.key,
      required this.textEditingController,
      required this.hintText,
      required this.labelText,
      this.keyboardType = TextInputType.text,
      this.failedValidationMessage,
      this.maxLines = 1});
  final TextEditingController textEditingController;
  final String hintText;
  final String labelText;
  final TextInputType keyboardType;
  final String? failedValidationMessage;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        validator: failedValidationMessage != null
            ? (value) {
                if (value == null || value.isEmpty || value.trim().isEmpty) {
                  return failedValidationMessage;
                }
                return null;
              }
            : null,
        maxLines: maxLines,
        controller: textEditingController,
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText,
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
        ),
        keyboardType: keyboardType,
      ),
    );
  }
}
