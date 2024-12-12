import 'dart:math';

class Loan {
  final double principal;
  final double interestRate;
  final int duration;
  final InterestType interestType;
  final InterestFrequency interestFrequency;

  Loan({
    required this.principal,
    required this.interestRate,
    required this.duration,
    required this.interestType,
    required this.interestFrequency,
  });

  double calculateCollectable() {
    int n;
    switch (interestFrequency) {
      case InterestFrequency.monthly:
        n = 30;
        break;
      case InterestFrequency.quarterly:
        n = 120;
        break;
      case InterestFrequency.halfYearly:
        n = 182;
        break;
      default:
        n = 365;
    }
    if (interestType == InterestType.simple) {
      return principal * (interestRate / 100) * duration/n;
    } else if (interestType == InterestType.compound) {
      return principal * pow((1 + (interestRate / 100) * n),  duration/n);
    }
    return 0.0;
  }
}

enum InterestType {
  simple,
  compound,
}

enum InterestFrequency {
  monthly,
  quarterly,
  halfYearly,
  yearly,
}
