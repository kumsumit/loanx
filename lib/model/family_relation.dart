class FamilyRelationFields {
  static const List<String> values = [id, name, isAddedByUser];

  static const String id = 'id';
  static const String name = 'name';
  static const String isAddedByUser = 'isAddedByUser';
}

class FamilyRelation {
  static const String tableName = 'familyRelations';
  final int? id;
  final String name;
  final int isAddedByUser;

  const FamilyRelation({this.id, required this.name, this.isAddedByUser = 0});

  FamilyRelation copy({int? id, String? name, int? isAddedByUser}) =>
      FamilyRelation(
        id: id ?? this.id,
        name: name ?? this.name,
        isAddedByUser: isAddedByUser ?? this.isAddedByUser,
      );

  static FamilyRelation fromJson(Map<String, Object?> json) => FamilyRelation(
    id: json[FamilyRelationFields.id] as int,
    name: json[FamilyRelationFields.name] as String,
    isAddedByUser: json[FamilyRelationFields.isAddedByUser] as int,
  );

  Map<String, Object?> toJson() => {
    FamilyRelationFields.id: id,
    FamilyRelationFields.name: name,
    FamilyRelationFields.isAddedByUser: isAddedByUser,
  };
}
