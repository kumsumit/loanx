import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loanx/widget/app_state_page.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStatePage(
      icon: Icons.error_outline_rounded,
      title: LocaleKeys.somethingWentWrong.tr(),
      message:
          'LoanX could not finish loading your workspace. Close the app and try again.'
              .tr(),
      isError: true,
      actions: [
        FilledButton.icon(
          onPressed: SystemNavigator.pop,
          icon: const Icon(Icons.close_rounded),
          label: Text(LocaleKeys.closeLoanx.tr()),
        ),
      ],
    );
  }
}
