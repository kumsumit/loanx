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
}
