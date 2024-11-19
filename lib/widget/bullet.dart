import 'package:flutter/material.dart';

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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 8), // Space between bullet and text
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 18,
                  fontStyle: italic ? FontStyle.italic : FontStyle.normal),
            ),
          ),
        ],
      ),
    );
  }
}
