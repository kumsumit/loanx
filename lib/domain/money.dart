/// Exact monetary value. [minorUnits] is never represented as a floating point
/// number and [scale] is explicit because not every currency has two decimals.
final class Money implements Comparable<Money> {
  const Money({
    required this.minorUnits,
    required this.currency,
    required this.scale,
  }) : assert(scale >= 0 && scale <= 9);

  factory Money.parse(String value, {required String currency, int scale = 2}) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency) || scale < 0 || scale > 9) {
      throw ArgumentError('Invalid currency contract');
    }
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(value.trim());
    if (match == null) throw const FormatException('Invalid monetary value');
    final fraction = match.group(3) ?? '';
    if (fraction.length > scale) {
      throw const FormatException('Amount exceeds currency precision');
    }
    final digits = '${match.group(2)}${fraction.padRight(scale, '0')}';
    var units = BigInt.parse(digits);
    if (match.group(1) == '-') units = -units;
    return Money(minorUnits: units, currency: currency, scale: scale);
  }

  final BigInt minorUnits;
  final String currency;
  final int scale;

  static Money zero(String currency, {int scale = 2}) =>
      Money(minorUnits: BigInt.zero, currency: currency, scale: scale);

  void _requireCompatible(Money other) {
    if (currency != other.currency || scale != other.scale) {
      throw ArgumentError('Money values use different currency contracts');
    }
  }

  Money operator +(Money other) {
    _requireCompatible(other);
    return Money(
      minorUnits: minorUnits + other.minorUnits,
      currency: currency,
      scale: scale,
    );
  }

  Money operator -(Money other) {
    _requireCompatible(other);
    return Money(
      minorUnits: minorUnits - other.minorUnits,
      currency: currency,
      scale: scale,
    );
  }

  Money get negated =>
      Money(minorUnits: -minorUnits, currency: currency, scale: scale);

  @override
  int compareTo(Money other) {
    _requireCompatible(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  String toString() {
    final negative = minorUnits.isNegative;
    final digits = minorUnits.abs().toString().padLeft(scale + 1, '0');
    final value = scale == 0
        ? digits
        : '${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}';
    return '${negative ? '-' : ''}$value';
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(minorUnits, currency, scale);
}

/// Rounds a rational number to the nearest integer, with halves away from zero.
BigInt divideRounded(BigInt numerator, BigInt denominator) {
  if (denominator <= BigInt.zero) {
    throw ArgumentError('Positive denominator required');
  }
  final negative = numerator.isNegative;
  final absolute = numerator.abs();
  final rounded =
      (absolute * BigInt.two + denominator) ~/ (denominator * BigInt.two);
  return negative ? -rounded : rounded;
}
