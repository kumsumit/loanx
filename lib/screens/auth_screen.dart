import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mortgage/provider/provider.dart';
import 'package:mortgage/service/auth_service.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = AuthService();

    void authenticate() async {
      ref.read(authProvider.notifier).state = false;
      final isAuthenticated = await authService.authenticate();
      ref.read(authProvider.notifier).state = isAuthenticated;
    }

    authenticate(); // Trigger authentication on app start
    final appColor = ref.watch(appColorProvider);
    return Scaffold(
      backgroundColor:
          Color(int.parse('FF${appColor.substring(1)}', radix: 16)),
      body: Center(
        child: Column(
          mainAxisAlignment : MainAxisAlignment.center,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                SizedBox(width: 10),
                Text('Authenticating...',style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 20)),
              ],
            ),
            Image.asset("assets/logo.webp"),
          ],
        ),
      ),
    );
  }
}
