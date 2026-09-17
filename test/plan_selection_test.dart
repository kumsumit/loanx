import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/features/auth/plan_selection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await AppSettings.clearAll();
  });

  testWidgets('lender onboarding offers free local loan management', (
    tester,
  ) async {
    AppSettings.putOnboardingInterest(0); // lender

    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PlanSelectionScreen(onContinue: () => continued = true),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('free-plan-option')), findsOneWidget);
    expect(find.text('Free lender workspace'), findsOneWidget);

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(continued, isTrue);
    expect(AppSettings.getSelectedPlan(), 'free');
    expect(AppSettings.getPlanSelectionCompleted(), isTrue);
  });

  testWidgets('combined onboarding keeps the Pro-only requirement', (
    tester,
  ) async {
    AppSettings.putOnboardingInterest(2); // both

    await tester.pumpWidget(
      MaterialApp(home: PlanSelectionScreen(onContinue: () {})),
    );
    await tester.pump();

    expect(find.byKey(const Key('free-plan-option')), findsNothing);

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(AppSettings.getSelectedPlan(), 'pro');
  });
}
