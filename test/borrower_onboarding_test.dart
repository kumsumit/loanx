import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/db/app_settings.dart';

void main() {
  test('borrower-only preference is free and skips plan selection', () async {
    await AppSettings.initForTesting(null);
    addTearDown(AppSettings.clearAll);

    AppSettings.putOnboardingInterest(1); // AccountType.borrower.index

    expect(AppSettings.getUsesBorrowerExperience(), isTrue);
    expect(AppSettings.getSelectedPlan(), 'free');
    expect(AppSettings.getPlanSelectionCompleted(), isFalse);
  });

  test(
    'lender and both preferences remain eligible for plan selection',
    () async {
      await AppSettings.initForTesting(null);
      addTearDown(AppSettings.clearAll);

      AppSettings.putOnboardingInterest(0);
      expect(AppSettings.getUsesBorrowerExperience(), isFalse);
      AppSettings.putOnboardingInterest(2);
      expect(AppSettings.getUsesBorrowerExperience(), isFalse);
    },
  );
}
