import 'package:in_app_update/in_app_update.dart';

  Future<void> checkForUpdates() async {
    final isUpdateAvailable = await InAppUpdate.checkForUpdate();
    if (isUpdateAvailable.updateAvailability ==
        UpdateAvailability.updateAvailable) {
      if (isUpdateAvailable.immediateUpdateAllowed) {
       await InAppUpdate.performImmediateUpdate();
      } else if (isUpdateAvailable.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
      }
    }
  }