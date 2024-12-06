
import 'package:flutter/material.dart';

class StyledText extends StatelessWidget {
  const StyledText(this.text,{super.key, this.maxLines = 1});
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
        )
        // style: TextStyle(
        //             color: Theme.of(context).colorScheme.onSurface,
        //           )
        );
  }
}

class StyledHeading extends StatelessWidget {
  const StyledHeading(this.text,{super.key, this.maxLines = 1});
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: Theme.of( context).textTheme.titleLarge!.fontSize,
        )
        // style: TextStyle(
        //             color: Theme.of(context).colorScheme.onSurface,
        //           )
        );
  }
}


class StyledSubtitle extends StatelessWidget {
  const StyledSubtitle(this.text,{super.key, this.fontSize,  this.maxLines = 1});
  final String text;
  final double? fontSize;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontSize: fontSize,
        )
        );
  }
}


class StyledIcon extends StatelessWidget {
  const StyledIcon(this.icon,{super.key,  this.size = 20});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: Theme.of(context).colorScheme.primary);
  }
}