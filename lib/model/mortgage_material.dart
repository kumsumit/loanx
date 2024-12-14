class MortgageMaterialFields {
  static const List<String> values = [id, name, isAddedByUser];

  static const String id = 'id';
  static const String name = 'name';
  static const String isAddedByUser = 'isAddedByUser';
}

class MortgageMaterial {
  static const String tableName = 'MortgageMaterials';
  final int? id;
  final String name;
  final int isAddedByUser;

  const MortgageMaterial({
    this.id,
    required this.name,
    this.isAddedByUser = 0,
  });

  MortgageMaterial copy({
    int? id,
    String? name,
    int? isAddedByUser,
  }) =>
      MortgageMaterial(
        id: id ?? this.id,
        name: name ?? this.name,
        isAddedByUser: isAddedByUser ?? this.isAddedByUser,
      );

  static MortgageMaterial fromJson(Map<String, Object?> json) =>
      MortgageMaterial(
        id: json[MortgageMaterialFields.id] as int,
        name: json[MortgageMaterialFields.name] as String,
        isAddedByUser: json[MortgageMaterialFields.isAddedByUser] as int,
      );

  Map<String, Object?> toJson() => {
       MortgageMaterialFields.id: id,
       MortgageMaterialFields.name: name,
       MortgageMaterialFields.isAddedByUser: isAddedByUser,
      };
}
