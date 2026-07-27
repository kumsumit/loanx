class LoanChangeFields {
  static const id = 'id';
  static const loanId = 'loanId';
  static const description = 'description';
  static const createdAt = 'createdAt';
}

class LoanChange {
  static const tableName = 'loanChanges';

  const LoanChange({
    this.id,
    required this.loanId,
    required this.description,
    required this.createdAt,
  });

  final int? id;
  final int loanId;
  final String description;
  final DateTime createdAt;

  factory LoanChange.fromJson(Map<String, Object?> json) => LoanChange(
    id: json[LoanChangeFields.id] as int?,
    loanId: json[LoanChangeFields.loanId] as int,
    description: json[LoanChangeFields.description] as String,
    createdAt: DateTime.parse(json[LoanChangeFields.createdAt] as String),
  );

  Map<String, Object?> toJson() => {
    LoanChangeFields.id: id,
    LoanChangeFields.loanId: loanId,
    LoanChangeFields.description: description,
    LoanChangeFields.createdAt: createdAt.toIso8601String(),
  };
}
