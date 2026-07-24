import 'package:flutter/material.dart';

class StyledTextField extends StatelessWidget {
  const StyledTextField({
    super.key,
    required this.textEditingController,
    required this.hintText,
    required this.labelText,
    this.keyboardType = TextInputType.text,
    this.failedValidationMessage,
    this.maxLines = 1,
  });
  final TextEditingController textEditingController;
  final String hintText;
  final String labelText;
  final TextInputType keyboardType;
  final String? failedValidationMessage;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
        decoration: InputDecoration(hintText: hintText, labelText: labelText),
        keyboardType: keyboardType,
      ),
    );
  }
}
