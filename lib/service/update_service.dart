import 'package:flutter/widgets.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:mortgage/widget/snackbar.dart';

Future<void> checkForUpdates(BuildContext context) async {
  final isUpdateAvailable = await InAppUpdate.checkForUpdate();
  if (isUpdateAvailable.updateAvailability ==
      UpdateAvailability.updateAvailable) {
    if (isUpdateAvailable.immediateUpdateAllowed) {
      await InAppUpdate.performImmediateUpdate();
    } else if (isUpdateAvailable.flexibleUpdateAllowed) {
      await InAppUpdate.startFlexibleUpdate();
    }
  } else {
    if (context.mounted) {
      showSnackBar(context, "No Updates Available");
    }
  }
}
