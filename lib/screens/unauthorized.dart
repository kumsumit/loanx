import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import to use SystemNavigator.pop
import 'package:flutter_hooks/flutter_hooks.dart';

class AuthFailurePage extends HookWidget {
  const AuthFailurePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Authentication Failed'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FadeTransition(
                opacity: animation,
                child: Icon(
                  Icons.lock_outline,
                  color: Colors.red,
                  size: 100,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Authentication Failed',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Unfortunately, we couldn\'t log you in. Please check your credentials and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  SystemNavigator.pop(); // Exit the application
                },
                icon: Icon(Icons.exit_to_app),
                label: Text('Exit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Updated backgroundColor
                  foregroundColor: Colors.white, // Updated foregroundColor
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: TextStyle(
                    fontSize: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  // Implement the logic to retry authentication or navigate to the login page
                },
                icon: Icon(Icons.replay),
                label: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, // Updated backgroundColor
                  foregroundColor: Colors.white, // Updated foregroundColor
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: TextStyle(
                    fontSize: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
