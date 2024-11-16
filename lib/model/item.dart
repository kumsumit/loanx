class ItemFields {
  static const List<String> values = [id, name, isAddedByUser];
  static const String id = 'id';
  static const String name = 'name';
  static const String isAddedByUser = 'isAddedByUser';
}

class Item {
  static const String tableName = 'items';
  final int? id;
  final String name;
  final int isAddedByUser;

  const Item({
    this.id,
    required this.name,
    this.isAddedByUser = 0,
  });

  Item copy({
    int? id,
    String? name,
    int? isAddedByUser,
  }) =>
      Item(
        id: id ?? this.id,
        name: name ?? this.name,
        isAddedByUser: isAddedByUser ?? this.isAddedByUser,
      );

  static Item fromJson(Map<String, Object?> json) => Item(
        id: json[ItemFields.id] as int,
        name: json[ItemFields.name] as String,
        isAddedByUser: json[ItemFields.isAddedByUser] as int,
      );

  Map<String, Object?> toJson() => {
        ItemFields.id: id,
        ItemFields.name: name,
        ItemFields.isAddedByUser: isAddedByUser,
      };
}
