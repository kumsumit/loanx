import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loanx/widget/app_state_page.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStatePage(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      message:
          'LoanX could not finish loading your workspace. Close the app and try again.',
      isError: true,
      actions: [
        FilledButton.icon(
          onPressed: SystemNavigator.pop,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Close LoanX'),
        ),
      ],
    );
  }
}
