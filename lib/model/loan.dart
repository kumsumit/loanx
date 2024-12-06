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

  double calculateInterest() {
    int n;
    switch (interestFrequency) {
      case InterestFrequency.monthly:
        n = 365;
        break;
      case InterestFrequency.quarterly:
        n = 90;
        break;
      case InterestFrequency.halfYearly:
        n = 182;
        break;
      default:
        n = 1;
    }
    if (interestType == InterestType.simple) {
      return principal * (interestRate / 100) * duration ;
    } else if (interestType == InterestType.compound) {
      return principal * pow((1 + (interestRate / 100) / n), n * duration) -
          principal;
    }
    return 0.0;
  }
}

enum InterestType {
  simple,
  compound,
}

enum InterestFrequency {
  yearly,
  halfYearly,
  quarterly,
  monthly,
}
