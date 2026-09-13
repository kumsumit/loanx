import 'dart:math';

import 'package:flutter/material.dart';

class EyeRollingIcon extends StatelessWidget {
  final Animation<double> animation;

  const EyeRollingIcon({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final colors = Theme.of(context).colorScheme;
        return CustomPaint(
          painter: EyePainter(
            animation.value,
            bgColor: colors.surface,
            fgColor: colors.onSurface,
          ),
          child: SizedBox(width: 50, height: 50),
        );
      },
    );
  }
}

class EyePainter extends CustomPainter {
  final double animationValue;
  final Color bgColor;
  final Color fgColor;

  EyePainter(
    this.animationValue, {
    required this.bgColor,
    required this.fgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;

    // Draw the outer eye
    canvas.drawOval(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw the rotating pupil
    paint.color = fgColor;
    double pupilX = size.width / 2 + (size.width / 4) * cos(animationValue);
    double pupilY = size.height / 2 + (size.height / 4) * sin(animationValue);
    canvas.drawCircle(Offset(pupilX, pupilY), size.width / 8, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
