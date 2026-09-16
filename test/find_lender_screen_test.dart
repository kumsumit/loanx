import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/features/borrower/find_lender_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('searches lenders by the pincode selected by the borrower', (
    tester,
  ) async {
    LenderSearchRequest? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: FindLenderScreen(
          search: (request) async {
            submitted = request;
            return const [
              NearbyLender(
                id: 'lender-1',
                displayName: 'Anita Finance',
                locationLabel: 'Indiranagar, Bengaluru',
                loanRangeLabel: '₹10,000–₹1,00,000',
                verificationLabel: 'Phone verified',
                categories: ['Personal loans'],
              ),
            ];
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('area-pincode')));
    await tester.enterText(
      find.byKey(const Key('lender-area-query')),
      '560038',
    );
    await tester.tap(find.byKey(const Key('search-lenders')));
    await tester.pumpAndSettle();

    expect(submitted?.area, LenderSearchArea.pincode);
    expect(submitted?.query, '560038');
    expect(find.text('Anita Finance'), findsOneWidget);
    expect(find.text('Indiranagar, Bengaluru'), findsOneWidget);
    expect(find.text('Phone verified'), findsOneWidget);
  });

  testWidgets('validates an invalid pincode before searching', (tester) async {
    var searchCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FindLenderScreen(
          search: (_) async {
            searchCount++;
            return const [];
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('area-pincode')));
    await tester.enterText(
      find.byKey(const Key('lender-area-query')),
      'invalid',
    );
    await tester.tap(find.byKey(const Key('search-lenders')));
    await tester.pump();

    expect(searchCount, 0);
    expect(find.text('Enter a valid pincode or postal code'), findsOneWidget);
  });

  testWidgets('shows an honest empty state when no public lenders are found', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: FindLenderScreen(search: (_) async => const [])),
    );

    await tester.enterText(
      find.byKey(const Key('lender-area-query')),
      'Indiranagar',
    );
    await tester.tap(find.byKey(const Key('search-lenders')));
    await tester.pumpAndSettle();

    expect(find.text('No lenders found'), findsOneWidget);
    expect(find.text('Anita Finance'), findsNothing);
  });

  testWidgets('paginates published lenders without duplicating results', (
    tester,
  ) async {
    final requestedCursors = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: FindLenderScreen(
          pageSearch: (request) async {
            requestedCursors.add(request.afterId);
            if (request.afterId.isEmpty) {
              return const NearbyLenderPage([
                NearbyLender(
                  id: 'one',
                  displayName: 'First Lender',
                  locationLabel: 'Bengaluru',
                ),
              ], 'next');
            }
            return const NearbyLenderPage([
              NearbyLender(
                id: 'one',
                displayName: 'First Lender',
                locationLabel: 'Bengaluru',
              ),
              NearbyLender(
                id: 'two',
                displayName: 'Second Lender',
                locationLabel: 'Bengaluru',
              ),
            ], '');
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('lender-area-query')),
      'Bengaluru',
    );
    await tester.tap(find.byKey(const Key('search-lenders')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('load-more-lenders')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('load-more-lenders')), findsOneWidget);
    await tester.tap(find.byKey(const Key('load-more-lenders')));
    await tester.pumpAndSettle();
    expect(requestedCursors, ['', 'next']);
    expect(find.text('Second Lender'), findsOneWidget);
    expect(find.byKey(const Key('load-more-lenders')), findsNothing);
  });
}
