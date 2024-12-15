import 'package:intl/intl.dart';

class MortgageFields {
  static final List<String> values = [id, depositorName];

  static final String id = 'id';
  static final String depositorName = 'depositorName';
  static final String relativeName = 'relativeName';
  static final String address = 'address';
  static final String loanAmount = 'loanAmount';
  static final String interestRate = 'interestRate';
  static final String weight = 'weight';
  static final String interestType = 'interestType';
  static final String interestFrequency = 'interestFrequency';
  static final String additionalDetails = 'additionalDetails';
  static final String dateCreated = 'dateCreated';
  static final String dateFinished = 'dateFinished';
  static final String itemId = 'itemId';
  static final String familyRelationId = "familyRelationId";
  static final String mortgageMaterialId = "MortgageMaterialId";
}

class Mortgage {
  static final String tableName = 'mortgages';
  final int? id;
  String depositorName;
  String relativeName;
  String address;
  double loanAmount;
  double interestRate;
  double weight;
  int interestType;
  int interestFrequency;
  String additionalDetails;
  DateTime dateCreated;
  DateTime? dateFinished;
  int itemId;
  int familyRelationId;
  int mortgageMaterialId;

  Mortgage(
      {this.id,
      required this.depositorName,
      required this.relativeName,
      required this.address,
      required this.loanAmount,
      required this.interestRate,
      required this.weight,
      required this.interestType,
      required this.interestFrequency,
      required this.additionalDetails,
      required this.itemId,
      required this.familyRelationId,
      required this.mortgageMaterialId,
      DateTime? dateCreated})
      : dateCreated = dateCreated ?? DateTime.now();

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

  Mortgage copy(
          {int? id,
          String? depositorName,
          String? relativeName,
          String? address,
          double? loanAmount,
          double? interestRate,
          double? weight,
          int? interestType,
          int? interestFrequency,
          String? additionalDetails,
          DateTime? dateCreated,
          int? itemId,
          int? familyRelationId,
          int? mortgageMaterialId}) =>
      Mortgage(
          id: id ?? this.id,
          depositorName: depositorName ?? this.depositorName,
          relativeName: relativeName ?? this.relativeName,
          address: address ?? this.address,
          loanAmount: loanAmount ?? this.loanAmount,
          interestRate: interestRate ?? this.interestRate,
          weight: weight ?? this.weight,
          interestType: interestType ?? this.interestType,
          interestFrequency: interestFrequency ?? this.interestFrequency,
          additionalDetails: additionalDetails ?? this.additionalDetails,
          dateCreated: dateCreated ?? this.dateCreated,
          itemId: itemId ?? this.itemId,
          familyRelationId: familyRelationId ?? this.familyRelationId,
          mortgageMaterialId: mortgageMaterialId ?? this.mortgageMaterialId);

  static Mortgage fromJson(Map<String, Object?> json) => Mortgage(
      id: json[MortgageFields.id] as int,
      depositorName: json[MortgageFields.depositorName] as String,
      relativeName: json[MortgageFields.relativeName] as String,
      address: json[MortgageFields.address] as String,
      loanAmount: json[MortgageFields.loanAmount] as double,
      interestRate: json[MortgageFields.interestRate] as double,
      weight: json[MortgageFields.weight] as double,
      interestType: json[MortgageFields.interestType] as int,
      interestFrequency: json[MortgageFields.interestFrequency] as int,
      additionalDetails: json[MortgageFields.additionalDetails] as String,
      dateCreated: DateTime.parse(json[MortgageFields.dateCreated] as String),
      itemId: json[MortgageFields.itemId] as int,
      familyRelationId: json[MortgageFields.familyRelationId] as int,
      mortgageMaterialId: json[MortgageFields.mortgageMaterialId] as int);

  Map<String, Object?> toJson() => {
        MortgageFields.id: id,
        MortgageFields.depositorName: depositorName,
        MortgageFields.relativeName: relativeName,
        MortgageFields.address: address,
        MortgageFields.loanAmount: loanAmount,
        MortgageFields.interestRate: interestRate,
        MortgageFields.weight: weight,
        MortgageFields.interestType: interestType,
        MortgageFields.interestFrequency: interestFrequency,
        MortgageFields.additionalDetails: additionalDetails,
        MortgageFields.dateCreated:
            DateFormat('yyyy-MM-dd kk:mm:ss').format(dateCreated),
        MortgageFields.itemId: itemId,
        MortgageFields.familyRelationId: familyRelationId,
        MortgageFields.mortgageMaterialId: mortgageMaterialId
      };
}
