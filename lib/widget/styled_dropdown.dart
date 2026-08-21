import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class StyledDropdown<T> extends StatelessWidget {
  final T? selectedValue;
  final void Function(T?) onChanged;
  final List<DropdownMenuItem<T>> items;
  final String hintText;
  final String labelText;
  final VoidCallback? onAddPressed;
  const StyledDropdown({
    super.key,
    this.selectedValue,
    required this.onChanged,
    required this.items,
    required this.hintText,
    required this.labelText,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: DropdownButtonFormField<T>(
              validator: (value) {
                if (value == null) {
                  return 'Please select an option'.tr();
                }
                return null;
              },
              initialValue: selectedValue,
              hint: Text(hintText),
              decoration: InputDecoration(labelText: labelText),
              items: items,
              onChanged: onChanged,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
          if (onAddPressed != null) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onAddPressed,
              tooltip: 'addNamedItem'.tr(namedArgs: {'item': labelText}),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ],
      ),
    );
  }
}
