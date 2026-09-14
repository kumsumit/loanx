import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/l10n/codegen_loader.g.dart';

void main() {
  const loader = CodegenLoader();

  test('loads every three-letter language code', () async {
    for (final code in ['bho', 'bra', 'mai', 'mni', 'mwr']) {
      final translations = await loader.load('', Locale(code));
      expect(translations, isNotNull, reason: 'Missing catalog for $code');
      expect(translations, contains('Loan details'));
    }
  });

  test('uses language code when locale also has a region', () async {
    final translations = await loader.load('', const Locale('bho', 'IN'));
    expect(translations, isNotNull);
    expect(translations!['Loan details'], isNot('Loan details'));
  });

  test('account interest copy is translated in every locale', () async {
    for (final code in CodegenLoader.mapLocales.keys) {
      final translations = await loader.load('', Locale(code));
      for (final key in [
        'bothLendingAndBorrowing',
        'bothAccountDescription',
        'preferenceCanChangeLater',
      ]) {
        expect(
          translations![key],
          isNotEmpty,
          reason: 'Missing $key translation for $code',
        );
      }
    }
  });
}
