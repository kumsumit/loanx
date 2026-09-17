import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/db/app_settings.dart';

void main() {
  test(
    'private profile fields are optional and persist with settings',
    () async {
      await AppSettings.initForTesting(null);
      await AppSettings.clearAll();

      expect(AppSettings.getProfileFullName(), isEmpty);
      expect(AppSettings.getProfileCity(), isEmpty);

      AppSettings.putProfileFullName('Asha Singh');
      AppSettings.putProfileBusinessName('Asha Lending');
      AppSettings.putProfileCity('Pune');
      await AppSettings.flush();
      await AppSettings.reloadForTesting();

      expect(AppSettings.getProfileFullName(), 'Asha Singh');
      expect(AppSettings.getProfileBusinessName(), 'Asha Lending');
      expect(AppSettings.getProfileCity(), 'Pune');
    },
  );
}
