import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/service/eye_rolling.dart';

class AuthScreen extends HookConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useAnimationController(
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );

    final appColor = ref.watch(appColorProvider);
    return Scaffold(
      backgroundColor:
          Color(int.parse('FF${appColor.substring(1)}', radix: 16)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EyeRollingIcon(animation: animation),
                SizedBox(width: 20),
                EyeRollingIcon(animation: animation),
              ],
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                  image: DecorationImage(
                      image: AssetImage("assets/logo.png"),
                      fit: BoxFit.cover)),
              child: SizedBox(
                width: 250,
                height: 250,
                child: FadeTransition(
                  opacity: animation,
                  child: Icon(
                    Icons.lock_outline,
                    color: Colors.red,
                    size: 100,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
