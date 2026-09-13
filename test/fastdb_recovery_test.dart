import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/service/database_helper.dart';

void main() {
  test('AppSettings persists through the ToStore KV port', () async {
    await DatabaseHelper.instance.close();
    await AppSettings.init();
    AppSettings.putInterestRate(7.5);
    await AppSettings.flush();
    expect(AppSettings.getInterestRate(), 7.5);
  });
}
