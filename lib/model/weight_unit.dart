class WeightUnitFields {
  static const id = 'id';
  static const name = 'name';
  static const symbol = 'symbol';
  static const isAddedByUser = 'isAddedByUser';

  static const values = [id, name, symbol, isAddedByUser];
}

class WeightUnit {
  static const tableName = 'weightUnits';

  final int? id;
  final String name;
  final String symbol;
  final int isAddedByUser;

  const WeightUnit({
    this.id,
    required this.name,
    required this.symbol,
    this.isAddedByUser = 0,
  });

  WeightUnit copy({
    int? id,
    String? name,
    String? symbol,
    int? isAddedByUser,
  }) => WeightUnit(
    id: id ?? this.id,
    name: name ?? this.name,
    symbol: symbol ?? this.symbol,
    isAddedByUser: isAddedByUser ?? this.isAddedByUser,
  );

  static WeightUnit fromJson(Map<String, Object?> json) => WeightUnit(
    id: json[WeightUnitFields.id] as int,
    name: json[WeightUnitFields.name] as String,
    symbol: json[WeightUnitFields.symbol] as String,
    isAddedByUser: json[WeightUnitFields.isAddedByUser] as int,
  );

  Map<String, Object?> toJson() => {
    WeightUnitFields.id: id,
    WeightUnitFields.name: name,
    WeightUnitFields.symbol: symbol,
    WeightUnitFields.isAddedByUser: isAddedByUser,
  };
}
