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
  static final String interestRate = 'interestRate';
  static final String interestType = 'interestType';
  static final String interestFrequency = 'interestFrequency';
  static final String additionalDetails = 'additionalDetails';
  static final String dateCreated = 'dateCreated';
  static final String dateFinished = 'dateFinished';
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
  double interestRate;
  int interestType;
  int interestFrequency;
  String additionalDetails;
  DateTime dateCreated;
  DateTime? dateFinished;
  int familyRelationId;
  int mortgageMaterialId;

  Loan({
    this.id,
    required this.depositorName,
    required this.phoneNumber,
    required this.relativeName,
    required this.address,
    required this.loanAmount,
    required this.interestRate,
    required this.interestType,
    required this.interestFrequency,
    required this.additionalDetails,
    required this.familyRelationId,
    required this.mortgageMaterialId,
    DateTime? dateCreated,
    this.dateFinished,
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
    } else {
      dateFinished = DateTime.now();
    }
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
    int? interestType,
    int? interestFrequency,
    String? additionalDetails,
    DateTime? dateCreated,
    DateTime? dateFinished,
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
    interestRate: interestRate ?? this.interestRate,
    interestType: interestType ?? this.interestType,
    interestFrequency: interestFrequency ?? this.interestFrequency,
    additionalDetails: additionalDetails ?? this.additionalDetails,
    dateCreated: dateCreated ?? this.dateCreated,
    dateFinished: dateFinished ?? this.dateFinished,
    familyRelationId: familyRelationId ?? this.familyRelationId,
    mortgageMaterialId: mortgageMaterialId ?? this.mortgageMaterialId,
  );

  static Loan fromJson(Map<String, Object?> json) => Loan(
    id: json[LoanFields.id] as int,
    depositorName: json[LoanFields.depositorName] as String,
    phoneNumber: json[LoanFields.phoneNumber] as String,
    relativeName: json[LoanFields.relativeName] as String,
    address: json[LoanFields.address] as String,
    loanAmount: json[LoanFields.loanAmount] as double,
    interestRate: json[LoanFields.interestRate] as double,
    interestType: json[LoanFields.interestType] as int,
    interestFrequency: json[LoanFields.interestFrequency] as int,
    additionalDetails: json[LoanFields.additionalDetails] as String,
    dateCreated: DateTime.parse(json[LoanFields.dateCreated] as String),
    dateFinished: json[LoanFields.dateFinished] == null
        ? null
        : DateTime.parse(json[LoanFields.dateFinished] as String),
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
    LoanFields.interestRate: interestRate,
    LoanFields.interestType: interestType,
    LoanFields.interestFrequency: interestFrequency,
    LoanFields.additionalDetails: additionalDetails,
    LoanFields.dateCreated: DateFormat(
      'yyyy-MM-dd kk:mm:ss',
    ).format(dateCreated),
    LoanFields.dateFinished: dateFinished == null
        ? null
        : DateFormat('yyyy-MM-dd kk:mm:ss').format(dateFinished!),
    LoanFields.familyRelationId: familyRelationId,
    LoanFields.mortgageMaterialId: mortgageMaterialId,
  };

  double calculateCollectable() {
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
      return loanAmount * pow((1 + (interestRate / 100) * n), duration / n);
    }
    return 0.0;
  }
}

enum InterestType { simple, compound }

enum InterestFrequency { monthly, quarterly, halfYearly, yearly }
