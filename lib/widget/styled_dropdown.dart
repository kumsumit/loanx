import 'package:flutter/material.dart';

class StyledDropdown<T> extends StatelessWidget {
  final T? selectedValue;
  final void Function(T?) onChanged;
  final List<DropdownMenuItem<T>> items;
  final String hintText;
  final String labelText;
  final VoidCallback? onAddPressed;
  // final VoidCallback onTap;
  const StyledDropdown({
    super.key,
    this.selectedValue,
    required this.onChanged,
    required this.items,
    required this.hintText,
    required this.labelText,
    this.onAddPressed,
    // required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: DropdownButtonFormField<T>(
        validator: (value) {
          if (value == null) {
            return 'Please select an option';
          }
          return null;
        },
        value: selectedValue,
        hint: Text(hintText),
        // onTap: onTap,
        decoration: InputDecoration(
          suffixIcon: onAddPressed != null
              ? IconButton(onPressed: onAddPressed, icon: const Icon(Icons.add))
              : null,
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
        items: items,
        onChanged: onChanged,
        icon: Icon(
          Icons.arrow_drop_down,
        ),
        // dropdownColor: Colors.white,
        style: TextStyle(
            // color: Colors.blue,
            fontSize: 16),
      ),
    );
  }
}
