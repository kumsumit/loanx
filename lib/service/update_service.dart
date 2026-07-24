import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:loanx/widget/snackbar.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

Future<void> checkForUpdates(BuildContext context, bool showSnack) async {
  final shorebirdUpdater = ShorebirdUpdater();

  if (shorebirdUpdater.isAvailable) {
    try {
      final status = await shorebirdUpdater.checkForUpdate();

      switch (status) {
        case UpdateStatus.outdated:
          await shorebirdUpdater.update();
          if (context.mounted) {
            showSnackBar(
              context,
              'Update downloaded. Restart the app to apply it.',
            );
          }
          return;
        case UpdateStatus.restartRequired:
          if (showSnack && context.mounted) {
            showSnackBar(context, 'Restart the app to apply the update.');
          }
          return;
        case UpdateStatus.upToDate:
        case UpdateStatus.unavailable:
          break;
      }
    } on Object catch (error) {
      debugPrint('Shorebird update check failed: $error');
    }
  }

  // Shorebird patches cannot contain native-code changes. On Android, retain
  // the Play Store updater as a fallback for full application releases.
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          return;
        }
        if (updateInfo.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          return;
        }
      }
    } on Object catch (error) {
      debugPrint('Play Store update check failed: $error');
    }
  }

  if (showSnack && context.mounted) {
    showSnackBar(context, 'No updates available');
  }
}
