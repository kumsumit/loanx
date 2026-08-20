import 'dart:math';

import 'package:intl/intl.dart';

class LoanFields {
  static final List<String> values = [id, depositorName];

  static final String id = 'id';
  static final String depositorName = 'depositorName';
  static final String phoneNumber = "phoneNumber";
  static final String relativeName = 'relativeName';
  static final String address = 'address';
  static final String loanAmount = 'loanAmount';
  static final String weight = 'weight';
  static final String weightUnit = 'weightUnit';
  static final String interestRate = 'interestRate';
  static final String interestType = 'interestType';
  static final String interestFrequency = 'interestFrequency';
  static final String mortgageTermYears = 'mortgageTermYears';
  static final String lockInDays = 'lockInDays';
  static final String earlyRedemptionCharge = 'earlyRedemptionCharge';
  static final String additionalDetails = 'additionalDetails';
  static final String dateCreated = 'dateCreated';
  static final String dateFinished = 'dateFinished';
  static final String completedBy = 'completedBy';
  static final String settlementAmount = 'settlementAmount';
  static final String completionReference = 'completionReference';
  static final String completionNotes = 'completionNotes';
  static final String familyRelationId = "familyRelationId";
  static final String mortgageMaterialId = "mortgageMaterialId";
}

class Loan {
  static final String tableName = 'loans';
  final int? id;
  String depositorName;
  String phoneNumber;
  String relativeName;
  String address;
  double loanAmount;
  double weight;
  String weightUnit;
  double interestRate;
  int interestType;
  int interestFrequency;
  int mortgageTermYears;
  int lockInDays;
  double earlyRedemptionCharge;
  String additionalDetails;
  DateTime dateCreated;
  DateTime? dateFinished;
  String completedBy;
  double? settlementAmount;
  String completionReference;
  String completionNotes;
  int familyRelationId;
  int mortgageMaterialId;

  Loan({
    this.id,
    required this.depositorName,
    required this.phoneNumber,
    required this.relativeName,
    required this.address,
    required this.loanAmount,
    this.weight = 0,
    this.weightUnit = 'g',
    required this.interestRate,
    required this.interestType,
    required this.interestFrequency,
    this.mortgageTermYears = 5,
    this.lockInDays = 0,
    this.earlyRedemptionCharge = 0,
    required this.additionalDetails,
    required this.familyRelationId,
    required this.mortgageMaterialId,
    DateTime? dateCreated,
    this.dateFinished,
    this.completedBy = '',
    this.settlementAmount,
    this.completionReference = '',
    this.completionNotes = '',
  }) : dateCreated = dateCreated ?? DateTime.now();

  String get dateCreatedFormat =>
      DateFormat('dd.MM.yy HH:mm:ss').format(dateCreated);

  String get dateFinishedFormat =>
      DateFormat('dd.MM.yy HH:mm:ss').format(dateFinished!);

  /// Returns true if the task has a [dateFinished] value.
  bool isFinished() {
    return dateFinished != null;
  }

  void toggleFinished() {
    if (isFinished()) {
      dateFinished = null;
      completedBy = '';
      settlementAmount = null;
      completionReference = '';
      completionNotes = '';
    } else {
      dateFinished = DateTime.now();
    }
  }

  void complete({
    required String receivedBy,
    required double amountReceived,
    String reference = '',
    String notes = '',
  }) {
    dateFinished = DateTime.now();
    completedBy = receivedBy;
    settlementAmount = amountReceived;
    completionReference = reference;
    completionNotes = notes;
  }

  String getStateText() {
    String text;
    if (isFinished()) {
      text = 'Finished on $dateFinishedFormat';
    } else {
      text = 'Created on $dateCreatedFormat';
    }
    return text;
  }

  Loan copy({
    int? id,
    String? depositorName,
    String? phoneNumber,
    String? relativeName,
    String? address,
    double? loanAmount,
    double? interestRate,
    double? weight,
    String? weightUnit,
    int? interestType,
    int? interestFrequency,
    int? mortgageTermYears,
    int? lockInDays,
    double? earlyRedemptionCharge,
    String? additionalDetails,
    DateTime? dateCreated,
    DateTime? dateFinished,
    String? completedBy,
    double? settlementAmount,
    String? completionReference,
    String? completionNotes,
    int? mortgageId,
    int? familyRelationId,
    int? mortgageMaterialId,
  }) => Loan(
    id: id ?? this.id,
    depositorName: depositorName ?? this.depositorName,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    relativeName: relativeName ?? this.relativeName,
    address: address ?? this.address,
    loanAmount: loanAmount ?? this.loanAmount,
    weight: weight ?? this.weight,
    weightUnit: weightUnit ?? this.weightUnit,
    interestRate: interestRate ?? this.interestRate,
    interestType: interestType ?? this.interestType,
    interestFrequency: interestFrequency ?? this.interestFrequency,
    mortgageTermYears: mortgageTermYears ?? this.mortgageTermYears,
    lockInDays: lockInDays ?? this.lockInDays,
    earlyRedemptionCharge: earlyRedemptionCharge ?? this.earlyRedemptionCharge,
    additionalDetails: additionalDetails ?? this.additionalDetails,
    dateCreated: dateCreated ?? this.dateCreated,
    dateFinished: dateFinished ?? this.dateFinished,
    completedBy: completedBy ?? this.completedBy,
    settlementAmount: settlementAmount ?? this.settlementAmount,
    completionReference: completionReference ?? this.completionReference,
    completionNotes: completionNotes ?? this.completionNotes,
    familyRelationId: familyRelationId ?? this.familyRelationId,
    mortgageMaterialId: mortgageMaterialId ?? this.mortgageMaterialId,
  );

  static Loan fromJson(Map<String, Object?> json) => Loan(
    id: json[LoanFields.id] as int,
    depositorName: json[LoanFields.depositorName] as String,
    phoneNumber: json[LoanFields.phoneNumber] as String,
    relativeName: json[LoanFields.relativeName] as String,
    address: json[LoanFields.address] as String,
    loanAmount: (json[LoanFields.loanAmount] as num).toDouble(),
    weight: (json[LoanFields.weight] as num?)?.toDouble() ?? 0,
    weightUnit: json[LoanFields.weightUnit] as String? ?? 'g',
    interestRate: json[LoanFields.interestRate] as double,
    interestType: json[LoanFields.interestType] as int,
    interestFrequency: json[LoanFields.interestFrequency] as int,
    mortgageTermYears:
        (json[LoanFields.mortgageTermYears] as num?)?.toInt() ?? 5,
    lockInDays: (json[LoanFields.lockInDays] as num?)?.toInt() ?? 0,
    earlyRedemptionCharge:
        (json[LoanFields.earlyRedemptionCharge] as num?)?.toDouble() ?? 0,
    additionalDetails: json[LoanFields.additionalDetails] as String,
    dateCreated: DateTime.parse(json[LoanFields.dateCreated] as String),
    dateFinished: json[LoanFields.dateFinished] == null
        ? null
        : DateTime.parse(json[LoanFields.dateFinished] as String),
    completedBy: json[LoanFields.completedBy] as String? ?? '',
    settlementAmount: (json[LoanFields.settlementAmount] as num?)?.toDouble(),
    completionReference: json[LoanFields.completionReference] as String? ?? '',
    completionNotes: json[LoanFields.completionNotes] as String? ?? '',
    familyRelationId: json[LoanFields.familyRelationId] as int,
    mortgageMaterialId: json[LoanFields.mortgageMaterialId] as int,
  );

  Map<String, Object?> toJson() => {
    LoanFields.id: id,
    LoanFields.depositorName: depositorName,
    LoanFields.phoneNumber: phoneNumber,
    LoanFields.relativeName: relativeName,
    LoanFields.address: address,
    LoanFields.loanAmount: loanAmount,
    LoanFields.weight: weight,
    LoanFields.weightUnit: weightUnit,
    LoanFields.interestRate: interestRate,
    LoanFields.interestType: interestType,
    LoanFields.interestFrequency: interestFrequency,
    LoanFields.mortgageTermYears: mortgageTermYears,
    LoanFields.lockInDays: lockInDays,
    LoanFields.earlyRedemptionCharge: earlyRedemptionCharge,
    LoanFields.additionalDetails: additionalDetails,
    LoanFields.dateCreated: DateFormat(
      'yyyy-MM-dd kk:mm:ss',
    ).format(dateCreated),
    LoanFields.dateFinished: dateFinished == null
        ? null
        : DateFormat('yyyy-MM-dd kk:mm:ss').format(dateFinished!),
    LoanFields.completedBy: completedBy,
    LoanFields.settlementAmount: settlementAmount,
    LoanFields.completionReference: completionReference,
    LoanFields.completionNotes: completionNotes,
    LoanFields.familyRelationId: familyRelationId,
    LoanFields.mortgageMaterialId: mortgageMaterialId,
  };

  double calculateInterest() {
    final duration = (dateFinished ?? DateTime.now())
        .difference(dateCreated)
        .inDays;
    int n;
    switch (InterestFrequency.values[interestFrequency]) {
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
    if (interestType == InterestType.simple.index) {
      return loanAmount * (interestRate / 100) * duration / n;
    } else if (interestType == InterestType.compound.index) {
      final total = loanAmount * pow(1 + (interestRate / 100), duration / n);
      return total - loanAmount;
    }
    return 0.0;
  }

  DateTime get lockInEndsAt => dateCreated.add(Duration(days: lockInDays));

  bool isWithinLockIn({DateTime? at}) {
    if (lockInDays <= 0 || earlyRedemptionCharge <= 0) return false;
    final effectiveDate = at ?? dateFinished ?? DateTime.now();
    return effectiveDate.isBefore(lockInEndsAt);
  }

  double calculateEarlyRedemptionCharge({DateTime? at}) =>
      isWithinLockIn(at: at) ? earlyRedemptionCharge : 0;

  double calculateCollectable() =>
      loanAmount + calculateInterest() + calculateEarlyRedemptionCharge();
}

enum InterestType { simple, compound }

enum InterestFrequency { monthly, quarterly, halfYearly, yearly }
