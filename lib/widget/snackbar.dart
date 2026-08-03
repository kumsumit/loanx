import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
// import 'package:fluttertoast/fluttertoast.dart';

// showToast(String message) {
//   Fluttertoast.showToast(
//     msg: message,
//     toastLength: Toast.LENGTH_SHORT,
//     gravity: ToastGravity.BOTTOM,
//     timeInSecForIosWeb: 1,
//     backgroundColor: Colors.black,
//     textColor: Colors.white,
//     fontSize: 16.0,
//   );
// }

void showErrorSnackBar(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final displayMessage = kReleaseMode
      ? 'Something went wrong. Please try again.'
      : message;
  final overlayEntry = OverlayEntry(
    builder: (context) => Align(
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: SlideInSnackbar(
          message: displayMessage,
          color: Theme.of(context).colorScheme.onError,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);

  // Remove the snackbar after a delay
  Future.delayed(Duration(seconds: 2), () {
    overlayEntry.remove();
  });
}

void showSnackBar(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => Align(
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: SlideInSnackbar(
          message: message,
          color: Theme.of(context).colorScheme.onPrimary,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);

  // Remove the snackbar after a delay
  Future.delayed(Duration(seconds: 3), () {
    overlayEntry.remove();
  });
}

class SlideInSnackbar extends HookWidget {
  final String message;
  final Color color;
  final Color backgroundColor;
  const SlideInSnackbar({
    super.key,
    required this.message,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 300),
    )..forward();
    final offsetAnimation = Tween<Offset>(
      begin: Offset(0, -1.0),
      end: Offset(0, 0.0),
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    return SlideTransition(
      position: offsetAnimation,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: colors.onSurface.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(message, style: TextStyle(color: color, fontSize: 16)),
      ),
    );
  }
}
