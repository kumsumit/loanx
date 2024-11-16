import 'package:flutter/material.dart';

class StyledTextField extends StatelessWidget {
  const StyledTextField({
    super.key,
    required this.textEditingController,
    required this.hintText,
    required this.labelText,
    this.keyboardType = TextInputType.text,
    required this.onTap,
  });
  final TextEditingController textEditingController;
  final String hintText;
  final String labelText;
  final TextInputType keyboardType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: textEditingController,
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primaryFixedDim,
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(10.0),
          ),
          // prefixIcon: Icon(Icons.text_fields, color: Colors.blue),
          // suffixIcon: Icon(Icons.check_circle, color: Colors.green),
        ),
        keyboardType: keyboardType,
        onTap: onTap,
      ),
    );
  }
}
