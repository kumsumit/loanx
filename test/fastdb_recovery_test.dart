import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/service/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppSettings persists through the ToStore KV port', () async {
    await DatabaseHelper.instance.close();
    await AppSettings.initForTesting(Directory.systemTemp);
    AppSettings.putInterestRate(7.5);
    await AppSettings.flush();
    expect(AppSettings.getInterestRate(), 7.5);
  });
}
