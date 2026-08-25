import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/service/upi_validator.dart';

void main() {
  group('isValidUpiId', () {
    test('accepts the supported UPI handles', () {
      expect(isValidUpiId('customer@ybl'), isTrue);
      expect(isValidUpiId('customer@apl'), isTrue);
      expect(isValidUpiId('customer@YBL'), isTrue);
    });

    test('rejects unsupported UPI handles', () {
      expect(isValidUpiId('customer@bank'), isFalse);
      expect(isValidUpiIdFormat('customer@ffg'), isTrue);
      expect(hasSupportedUpiHandle('customer@ffg'), isFalse);
      expect(upiHandle('9978678678@hgh'), 'hgh');
    });

    test('rejects malformed UPI IDs', () {
      expect(isValidUpiId('customer'), isFalse);
      expect(isValidUpiId('@ybl'), isFalse);
      expect(isValidUpiId('customer@ybl@apl'), isFalse);
    });
  });
}
