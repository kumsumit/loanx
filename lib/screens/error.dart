import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import to use SystemNavigator.pop
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:loanx/service/eye_rolling.dart';

class ErrorPage extends HookWidget {
  const ErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(seconds: 5),
    )..repeat();
    final animation = Tween<double>(begin: 0, end: 2 * pi).animate(controller);

    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(
            painter: ShapesPainter(),
            child: Container(),
          ),
          Center(
            child: FadeTransition(
              opacity: animation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      EyeRollingIcon(animation: animation),
                      SizedBox(width: 20),
                      EyeRollingIcon(animation: animation),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Oops!',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Something went wrong.',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {
                      SystemNavigator.pop(); // Exit the application
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, // Updated backgroundColor
                      foregroundColor: Colors.white, // Updated foregroundColor
                      padding:
                          EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      textStyle: TextStyle(
                        fontSize: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShapesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw the gradient background
    var paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.amberAccent, Colors.lightBlueAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    var path = Path();
    path.moveTo(0, size.height * 0.4);
    path.quadraticBezierTo(
        size.width / 2, size.height * 0.6, size.width, size.height * 0.4);
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();
    canvas.drawPath(path, paint);

    // Draw additional shapes
    var rectPaint = Paint()
      ..color = Colors.white.withValues(alpha:0.5)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.4, size.height * 0.6, 100, 50), rectPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
