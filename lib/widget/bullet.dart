import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// import 'package:loanx/db/fastdb.dart';

class BulletPoint extends StatelessWidget {
  const BulletPoint(this.text, {super.key, this.italic = false});
  final String text;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(width: 8), // Space between bullet and text
          Expanded(
            child: Text(
              text.trExists() ? text.tr() : text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
