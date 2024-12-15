class MortgageFields {
  static const List<String> values = [id, name, isAddedByUser];
  static const String id = 'id';
  static const String name = 'name';
  static const String isAddedByUser = 'isAddedByUser';
}

class Mortgage {
  static const String tableName = 'mortgages';
  final int? id;
  final String name;
  final int isAddedByUser;

  const Mortgage({
    this.id,
    required this.name,
    this.isAddedByUser = 0,
  });

  Mortgage copy({
    int? id,
    String? name,
    int? isAddedByUser,
  }) =>
      Mortgage(
        id: id ?? this.id,
        name: name ?? this.name,
        isAddedByUser: isAddedByUser ?? this.isAddedByUser,
      );

  static Mortgage fromJson(Map<String, Object?> json) => Mortgage(
        id: json[MortgageFields.id] as int,
        name: json[MortgageFields.name] as String,
        isAddedByUser: json[MortgageFields.isAddedByUser] as int,
      );

  Map<String, Object?> toJson() => {
        MortgageFields.id: id,
        MortgageFields.name: name,
        MortgageFields.isAddedByUser: isAddedByUser,
      };
}
