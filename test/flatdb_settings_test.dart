import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/db/flat_buffers.dart' as fb;
import 'package:loanx/db/flatdb_generated.dart';

void main() {
  test('lock-in defaults round-trip through settings storage', () {
    final settings = FlatDbObjectBuilder(
      defaultLockInDays: 15,
      defaultEarlyRedemptionCharge: 750.50,
      defaultTermsAndConditions: 'Repayment is due within 12 months.',
      defaultUpiId: 'shop@bank',
    );

    final restored = FlatDb(settings.toBytes());

    expect(restored.defaultLockInDays, 15);
    expect(restored.defaultEarlyRedemptionCharge, 750.50);
    expect(
      restored.defaultTermsAndConditions,
      'Repayment is due within 12 months.',
    );
    expect(restored.defaultUpiId, 'shop@bank');
  });

  test('older settings default to no lock-in', () {
    final builder = fb.Builder();
    builder.startTable(21);
    builder.addInt8(6, 1);
    final offset = builder.endTable();
    builder.finish(offset);

    final restored = FlatDb(builder.buffer);

    expect(restored.defaultLockInDays, 0);
    expect(restored.defaultEarlyRedemptionCharge, 0);
    expect(restored.defaultTermsAndConditions, isNull);
    expect(restored.defaultUpiId, isNull);
  });
}
