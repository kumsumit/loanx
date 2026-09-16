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
  // Keep an exact decimal representation alongside the legacy numeric field.
  // This avoids losing monetary values in ToStore's file-backed double path.
  static final String loanAmountExact = 'loanAmountExact';
  static final String weight = 'weight';
  static final String weightUnit = 'weightUnit';
  static final String interestRate = 'interestRate';
  static final String interestType = 'interestType';
  static final String interestFrequency = 'interestFrequency';
  static final String mortgageTermYears = 'mortgageTermYears';
  static final String lockInDays = 'lockInDays';
  static final String earlyRedemptionCharge = 'earlyRedemptionCharge';
  static final String additionalDetails = 'additionalDetails';
  static final String termsAndConditions = 'termsAndConditions';
  static final String dateCreated = 'dateCreated';
  static final String dateFinished = 'dateFinished';
  static final String completedBy = 'completedBy';
  static final String settlementAmount = 'settlementAmount';
  static final String completionReference = 'completionReference';
  static final String completionNotes = 'completionNotes';
  static final String currency = 'currency';
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
  String currency;
  double weight;
  String weightUnit;
  double interestRate;
  int interestType;
  int interestFrequency;
  int mortgageTermYears;
  int lockInDays;
  double earlyRedemptionCharge;
  String additionalDetails;
  String termsAndConditions;
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
    this.currency = 'INR',
    this.weight = 0,
    this.weightUnit = 'g',
    required this.interestRate,
    required this.interestType,
    required this.interestFrequency,
    this.mortgageTermYears = 5,
    this.lockInDays = 0,
    this.earlyRedemptionCharge = 0,
    required this.additionalDetails,
    this.termsAndConditions = '',
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
      DateFormat('dd.MM.yy HH:mm:ss').format(dateCreated.toLocal());

  String get dateFinishedFormat =>
      DateFormat('dd.MM.yy HH:mm:ss').format(dateFinished!.toLocal());

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
    if (!amountReceived.isFinite || amountReceived < 0) {
      throw ArgumentError.value(
        amountReceived,
        'amountReceived',
        'Must be finite and nonnegative.',
      );
    }
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
    String? currency,
    double? interestRate,
    double? weight,
    String? weightUnit,
    int? interestType,
    int? interestFrequency,
    int? mortgageTermYears,
    int? lockInDays,
    double? earlyRedemptionCharge,
    String? additionalDetails,
    String? termsAndConditions,
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
    currency: currency ?? this.currency,
    weight: weight ?? this.weight,
    weightUnit: weightUnit ?? this.weightUnit,
    interestRate: interestRate ?? this.interestRate,
    interestType: interestType ?? this.interestType,
    interestFrequency: interestFrequency ?? this.interestFrequency,
    mortgageTermYears: mortgageTermYears ?? this.mortgageTermYears,
    lockInDays: lockInDays ?? this.lockInDays,
    earlyRedemptionCharge: earlyRedemptionCharge ?? this.earlyRedemptionCharge,
    additionalDetails: additionalDetails ?? this.additionalDetails,
    termsAndConditions: termsAndConditions ?? this.termsAndConditions,
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
    loanAmount: _readLoanAmount(json),
    currency: json[LoanFields.currency] as String? ?? 'INR',
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
    termsAndConditions: json[LoanFields.termsAndConditions] as String? ?? '',
    dateCreated: DateTime.parse(
      json[LoanFields.dateCreated] as String,
    ).toLocal(),
    dateFinished: json[LoanFields.dateFinished] == null
        ? null
        : DateTime.parse(json[LoanFields.dateFinished] as String).toLocal(),
    completedBy: json[LoanFields.completedBy] as String? ?? '',
    settlementAmount: (json[LoanFields.settlementAmount] as num?)?.toDouble(),
    completionReference: json[LoanFields.completionReference] as String? ?? '',
    completionNotes: json[LoanFields.completionNotes] as String? ?? '',
    familyRelationId: json[LoanFields.familyRelationId] as int,
    mortgageMaterialId: json[LoanFields.mortgageMaterialId] as int,
  );

  Map<String, Object?> toJson() {
    for (final entry in {
      LoanFields.loanAmount: loanAmount,
      LoanFields.interestRate: interestRate,
      LoanFields.weight: weight,
      LoanFields.earlyRedemptionCharge: earlyRedemptionCharge,
      LoanFields.settlementAmount: ?settlementAmount,
    }.entries) {
      if (!entry.value.isFinite) {
        throw ArgumentError.value(entry.value, entry.key, 'Must be finite.');
      }
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw ArgumentError.value(
        currency,
        LoanFields.currency,
        'Invalid ISO code.',
      );
    }
    return {
      LoanFields.id: id,
      LoanFields.depositorName: depositorName,
      LoanFields.phoneNumber: phoneNumber,
      LoanFields.relativeName: relativeName,
      LoanFields.address: address,
      LoanFields.loanAmount: loanAmount,
      LoanFields.loanAmountExact: loanAmount.toString(),
      LoanFields.currency: currency,
      LoanFields.weight: weight,
      LoanFields.weightUnit: weightUnit,
      LoanFields.interestRate: interestRate,
      LoanFields.interestType: interestType,
      LoanFields.interestFrequency: interestFrequency,
      LoanFields.mortgageTermYears: mortgageTermYears,
      LoanFields.lockInDays: lockInDays,
      LoanFields.earlyRedemptionCharge: earlyRedemptionCharge,
      LoanFields.additionalDetails: additionalDetails,
      LoanFields.termsAndConditions: termsAndConditions,
      LoanFields.dateCreated: dateCreated.toUtc().toIso8601String(),
      LoanFields.dateFinished: dateFinished?.toUtc().toIso8601String(),
      LoanFields.completedBy: completedBy,
      LoanFields.settlementAmount: settlementAmount,
      LoanFields.completionReference: completionReference,
      LoanFields.completionNotes: completionNotes,
      LoanFields.familyRelationId: familyRelationId,
      LoanFields.mortgageMaterialId: mortgageMaterialId,
    };
  }

  static double _readLoanAmount(Map<String, Object?> json) {
    final exact = json[LoanFields.loanAmountExact];
    if (exact is String && exact.trim().isNotEmpty) {
      final parsed = double.tryParse(exact.trim());
      if (parsed != null && parsed.isFinite) return parsed;
    }
    final legacy = json[LoanFields.loanAmount];
    if (legacy is num) return legacy.toDouble();
    throw const FormatException('Loan principal amount is missing or invalid.');
  }

  double calculateInterest() {
    final duration = (dateFinished ?? DateTime.now())
        .difference(dateCreated)
        .inDays
        .clamp(0, 1 << 31);
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
