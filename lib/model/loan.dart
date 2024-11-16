import 'dart:math';

class Loan {
  final double principal;
  final double interestRate;
  final int duration;
  final InterestType interestType;
  final CompoundingFrequency compoundingFrequency;

  Loan({
    required this.principal,
    required this.interestRate,
    required this.duration,
    required this.interestType,
    required this.compoundingFrequency,
  });

  double calculateInterest() {
    if (interestType == InterestType.simple) {
      return principal * (interestRate / 100) * duration;
    } else if (interestType == InterestType.compound) {
      int n;
      switch (compoundingFrequency) {
        case CompoundingFrequency.monthly:
          n = 12;
          break;
        case CompoundingFrequency.quarterly:
          n = 4;
          break;
        case CompoundingFrequency.halfYearly:
          n = 2;
          break;
        default:
          n = 1;
      }
      return principal * pow((1 + (interestRate / 100) / n), n * duration) - principal;
    }
    return 0.0;
  }
}

enum InterestType {
  simple,
  compound,
}

enum CompoundingFrequency {
  yearly,
  halfYearly,
  quarterly,
  monthly,
}
