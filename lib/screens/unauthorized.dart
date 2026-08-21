import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/screens/dashboard.dart';
import 'package:loanx/widget/app_state_page.dart';

class AuthFailurePage extends ConsumerWidget {
  const AuthFailurePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppStatePage(
      icon: Icons.lock_outline_rounded,
      title: 'Authentication failed'.tr(),
      message:
          'We could not verify your identity. Unlock your device and try again.'
              .tr(),
      isError: true,
      actions: [
        FilledButton.icon(
          onPressed: () {
            ref
                .read(authenticateProvider)
                .when(
                  data: (authenticated) {
                    if (authenticated && context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DashBoard(),
                        ),
                      );
                    }
                  },
                  error: (_, _) {},
                  loading: () {},
                );
          },
          icon: const Icon(Icons.refresh_rounded),
          label: Text('Try again'.tr()),
        ),
        TextButton.icon(
          onPressed: SystemNavigator.pop,
          icon: const Icon(Icons.close_rounded),
          label: Text('Close app'.tr()),
        ),
      ],
    );
  }
}
