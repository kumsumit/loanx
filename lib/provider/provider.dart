import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mortgage/algo/damerau_lavenstien.dart';
import 'package:mortgage/db/fastdb.dart';
import 'package:mortgage/service/database_helper.dart';
import 'package:mortgage/model/family_relation.dart';
import 'package:mortgage/model/item.dart';
import 'package:mortgage/model/mortgage.dart';
import 'package:mortgage/model/mortgage_material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:sqflite_sqlcipher/sqlite_api.dart';
part 'provider.g.dart';

final authProvider = StateProvider<bool>((ref) => false);

@Riverpod(keepAlive: true)
class ThemeModeManager extends _$ThemeModeManager {
  @override
  ThemeMode build() {
    return ThemeMode.values[FastDB.getThemeMode()];
  }

  Future<void> set() async {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    FastDB.putThemeMode(state.index);
    await FastDB.flush();
  }
}

@Riverpod(keepAlive: true)
class FontSize extends _$FontSize {
  @override
  double build() {
    return FastDB.getFontSize();
  }

  Future<void> set() async {
    state = ref.read(sliderFontSizeProvider);
    FastDB.putFontSize(state);
    await FastDB.flush();
  }
}

@riverpod
class HoldingPeriod extends _$HoldingPeriod {
  @override
  int build() {
    return FastDB.getHoldingPeriod();
  }

  Future<void> set(int val) async {
    state = val;
    FastDB.putHoldingPeriod(state);
    await FastDB.flush();
  }
}


@riverpod
class ScheduledBackUpTimeHour extends _$ScheduledBackUpTimeHour {
  @override
  int build() {
    return FastDB.getScheduledBackUpTimeHour();
  }

  void set(int scheduledBackUpTimeHour){
    state = scheduledBackUpTimeHour;
    FastDB.putScheduledBackUpTimeHour(scheduledBackUpTimeHour);
  }
}

@riverpod
class ScheduledBackUpTimeMinute extends _$ScheduledBackUpTimeMinute {
  @override
  int build() {
    return FastDB.getScheduledBackUpTimeMinute();
  }

  void set(int scheduledBackUpTimeMinute){
    state = scheduledBackUpTimeMinute;
    FastDB.putScheduledBackUpTimeMinute(scheduledBackUpTimeMinute);
  }
}

@riverpod
class BackupStatus extends _$BackupStatus {
  @override
  bool build() {
    return false;
  }

  void set(bool backupStatus){
    state = backupStatus;
  }
}

@riverpod
class SliderFontSize extends _$SliderFontSize {
  @override
  double build() => FastDB.getFontSize();

  void set(double newValue) {
    state = newValue;
  }
}

@riverpod
class MortgageSelectionList extends _$MortgageSelectionList {
  @override
  List<int> build() => [];

  void add(int id) {
    state = [...state, id];
  }

  void remove(int id) {
    state = state.where((e) => e != id).toList();
  }
}

@riverpod
class SearchBarStatus extends _$SearchBarStatus {
  @override
  bool build() => false;

  void toogle() {
    state = !state;
  }
}

@Riverpod(keepAlive: true)
class AppColor extends _$AppColor {
  @override
  String build() => FastDB.getAppColor();

  Future<void> set() async {
    state = ref.read(pickerColorProvider);
    FastDB.putAppColor(state);
    await FastDB.flush();
  }

  Future<void> setFromLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // File rotatedImage =
      //     await FlutterExifRotation.rotateImage(path: image.path);
      final scheme = await ColorScheme.fromImageProvider(
        provider: FileImage(File(image.path)),
        brightness: Brightness.light,
      );
      ref.read(pickerColorProvider.notifier).set(scheme.primary);
      await set();
    } else {
      final LostDataResponse response = await picker.retrieveLostData();
      if (!response.isEmpty) {
        final List<XFile>? files = response.files;
        if (files != null) {
          // File rotatedImage =
          //     await FlutterExifRotation.rotateImage(path: files.first.path);
          final scheme = await ColorScheme.fromImageProvider(
            provider: FileImage(File(files.first.path)),
            brightness: Brightness.light,
          );
          ref.read(pickerColorProvider.notifier).set(scheme.primary);
          await set();
        }
      }
    }
  }
}

@riverpod
class PickerColor extends _$PickerColor {
  @override
  String build() => FastDB.getAppColor();

  void set(Color color) {
    state = color.value.toRadixString(16).substring(2);
    debugPrint(state);
  }
}

@riverpod
Future<String> appVersion(Ref ref) async {
  return (await PackageInfo.fromPlatform()).version;
}

final databaseProvider =
    Provider<Database>((ref) => throw UnimplementedError());

@Riverpod(keepAlive: true)
class FamilyRelationList extends _$FamilyRelationList {
  late Database db;

  @override
  List<FamilyRelation> build() {
    readAllFamilyRelations();
    return [];
  }

  Future<void> readAllFamilyRelations() async {
    db = await DatabaseHelper.instance.database;
    final orderBy = '${FamilyRelationFields.id} ASC';
    final result = await db.query(FamilyRelation.tableName, orderBy: orderBy);
    state = result.map((json) => FamilyRelation.fromJson(json)).toList();
  }

  Future<FamilyRelation> readFamilyRelation(int id) async {
    final maps = await db.query(
      FamilyRelation.tableName,
      columns: FamilyRelationFields.values,
      where: '${FamilyRelationFields.id} = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return FamilyRelation.fromJson(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<int> add(String name) async {
    if (state
        .any((element) => element.name.toLowerCase() == name.toLowerCase())) {
      return -1;
    }
    FamilyRelation familyRelation =
        FamilyRelation(name: name, isAddedByUser: 1);
    final id =
        await db.insert(FamilyRelation.tableName, familyRelation.toJson());
    if (id > 0) {
      familyRelation = familyRelation.copy(id: id);
      state = [...state, familyRelation];
      return id;
    }
    return -1;
  }

  Future<void> delete(int id) async {
    final rid = await db.delete(
      FamilyRelation.tableName,
      where: '${FamilyRelationFields.id} = ?',
      whereArgs: [id],
    );
    if (rid > 0) {
      state = state.where((familyRelation) => familyRelation.id != id).toList();
    }
  }

  Future<void> bulkDelete(List<int> ids) async {
    final batch = db.batch();
    for (int id in ids) {
      batch.delete(
        FamilyRelation.tableName,
        where: '${FamilyRelationFields.id} = ?',
        whereArgs: [id],
      );
    }
    final results = await batch.commit();
    state = state
        .where((familyRelation) => !results.contains(familyRelation.id))
        .toList();
  }

  Future<void> update(FamilyRelation familyRelation) async {
    final id = await db.update(
      FamilyRelation.tableName,
      familyRelation.toJson(),
      where: '${FamilyRelationFields.id} = ?',
      whereArgs: [familyRelation.id],
    );
    if (id > 0) {
      state = [
        for (final s in state)
          if (s.id == familyRelation.id) familyRelation else s
      ];
    }
  }
}

@Riverpod(keepAlive: true)
class MortgageMaterialList extends _$MortgageMaterialList {
  late Database db;

  @override
  List<MortgageMaterial> build() {
    readAllMortgageMaterials();
    return [];
  }

  Future<void> readAllMortgageMaterials() async {
    db = await DatabaseHelper.instance.database;
    final orderBy = '${MortgageMaterialFields.id} ASC';
    final result = await db.query(MortgageMaterial.tableName, orderBy: orderBy);
    state = result.map((json) => MortgageMaterial.fromJson(json)).toList();
  }

  Future<MortgageMaterial> readMortgageMaterial(int id) async {
    final maps = await db.query(
      MortgageMaterial.tableName,
      columns: MortgageMaterialFields.values,
      where: '${MortgageMaterialFields.id} = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return MortgageMaterial.fromJson(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<int> add(String name) async {
    if (state
        .any((element) => element.name.toLowerCase() == name.toLowerCase())) {
      return -1;
    }
    MortgageMaterial mortgageMaterial =
        MortgageMaterial(name: name, isAddedByUser: 1);
    final id =
        await db.insert(MortgageMaterial.tableName, mortgageMaterial.toJson());
    if (id > 0) {
      mortgageMaterial = mortgageMaterial.copy(id: id);
      state = [...state, mortgageMaterial];
      return id;
    }
    return -1;
  }

  Future<void> delete(int id) async {
    final rid = await db.delete(
      MortgageMaterial.tableName,
      where: '${MortgageMaterialFields.id} = ?',
      whereArgs: [id],
    );
    if (rid > 0) {
      state =
          state.where((mortgageMaterial) => mortgageMaterial.id != id).toList();
    }
  }

  Future<void> bulkDelete(List<int> ids) async {
    final batch = db.batch();
    for (int id in ids) {
      batch.delete(
        MortgageMaterial.tableName,
        where: '${MortgageMaterialFields.id} = ?',
        whereArgs: [id],
      );
    }
    final results = await batch.commit();
    state = state.where((item) => !results.contains(item.id)).toList();
  }

  Future<void> update(MortgageMaterial mortgageMaterial) async {
    final id = await db.update(
      MortgageMaterial.tableName,
      mortgageMaterial.toJson(),
      where: '${ItemFields.id} = ?',
      whereArgs: [mortgageMaterial.id],
    );
    if (id > 0) {
      state = [
        for (final s in state)
          if (s.id == mortgageMaterial.id) mortgageMaterial else s
      ];
    }
  }
}

@Riverpod(keepAlive: true)
class ItemList extends _$ItemList {
  late Database db;

  @override
  List<Item> build() {
    readAllItems();
    return [];
  }

  Future<void> readAllItems() async {
    db = await DatabaseHelper.instance.database;
    final orderBy = '${ItemFields.id} ASC';
    final result = await db.query(Item.tableName, orderBy: orderBy);
    state = result.map((json) => Item.fromJson(json)).toList();
  }

  Future<Item> readItem(int id) async {
    final maps = await db.query(
      Item.tableName,
      columns: ItemFields.values,
      where: '${ItemFields.id} = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Item.fromJson(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<int> add(String name) async {
    if (state
        .any((element) => element.name.toLowerCase() == name.toLowerCase())) {
      return -1;
    }
    Item item = Item(name: name, isAddedByUser: 1);
    final id = await db.insert(Item.tableName, item.toJson());
    if (id > 0) {
      item = item.copy(id: id);
      state = [...state, item];
      return id;
    }
    return -1;
  }

  Future<void> bulkDelete(List<int> ids) async {
    final batch = db.batch();
    for (int id in ids) {
      batch.delete(
        Item.tableName,
        where: '${ItemFields.id} = ?',
        whereArgs: [id],
      );
    }
    final results = await batch.commit();
    state = state.where((item) => !results.contains(item.id)).toList();
  }

  Future<void> update(Item item) async {
    final id = await db.update(
      Item.tableName,
      item.toJson(),
      where: '${ItemFields.id} = ?',
      whereArgs: [item.id],
    );
    if (id > 0) {
      state = [
        for (final s in state)
          if (s.id == item.id) item else s
      ];
    }
  }

  Future<void> delete(int id) async {
    final rid = await db.delete(
      Item.tableName,
      where: '${ItemFields.id} = ?',
      whereArgs: [id],
    );
    if (rid > 0) {
      state = state.where((item) => item.id != id).toList();
    }
  }
}

@Riverpod(keepAlive: true)
class MortgageList extends _$MortgageList {
  late Database db;

  @override
  List<Mortgage> build() {
    readAllMortgages();
    return [];
  }

  Future<void> readAllMortgages() async {
    db = await DatabaseHelper.instance.database;
    final orderBy = '${MortgageFields.id} ASC';
    final result = await db.query(Mortgage.tableName, orderBy: orderBy);
    state = result.map((json) => Mortgage.fromJson(json)).toList();
  }

  List<Mortgage> searchMortgagesByItemId(int itemId) {
    return state.where((item) => item.itemId == itemId).toList();
  }

  List<Mortgage> searchMortgagesByMortgageMaterialId(int mortgageMaterialId) {
    return state
        .where((item) => item.mortgageMaterialId == mortgageMaterialId)
        .toList();
  }

  List<Mortgage> searchMortgagesByDateCreated(DateTime dateCreated) {
    return state
        .where((item) =>
            item.dateCreated.year == dateCreated.year &&
            item.dateCreated.month == dateCreated.month &&
            item.dateCreated.day == dateCreated.day)
        .toList();
  }

  List<Mortgage> searchMortgagesByDateRange(DateTimeRange dateTimeRange) {
    return state
        .where((item) =>
            item.dateCreated.isAfter(dateTimeRange.start) &&
            item.dateCreated.isBefore(dateTimeRange.end))
        .toList();
  }

  Future<void> searchMortgagesByItemIdDB(int itemId) async {
    final orderBy = '${MortgageFields.id} ASC';
    final result = await db.query(Mortgage.tableName,
        where: '${MortgageFields.itemId} = ?',
        whereArgs: [itemId],
        orderBy: orderBy);
    state = result.map((json) => Mortgage.fromJson(json)).toList();
  }

  Future<void> readAllMortgagesByMortgageMaterialId(
      int mortgageMaterialId) async {
    final orderBy = '${MortgageFields.id} ASC';
    final result = await db.query(Mortgage.tableName,
        where: '${MortgageFields.mortgageMaterialId} = ?',
        whereArgs: [mortgageMaterialId],
        orderBy: orderBy);
    state = result.map((json) => Mortgage.fromJson(json)).toList();
  }

  List<Mortgage> searchMortgagesByDepositorName(String searchTerm) {
    String lowerKeyword = searchTerm.toLowerCase();

    // Perform the search
    List<Mortgage> exactMatches = [];
    List<Mortgage> partialMatches = [];
    List<Mortgage> fuzzyMatches = [];

    for (Mortgage book in state) {
      String title = book.depositorName.toLowerCase();

      // Exact match
      if (title == lowerKeyword) {
        exactMatches.add(book);
        continue;
      }

      if (title.startsWith(lowerKeyword)) {
        partialMatches.add(book);
        continue;
      }

      // Partial match using 'contains'
      if (title.contains(lowerKeyword)) {
        partialMatches.add(book);
        continue;
      }

      // Fuzzy match using Damerau-Levenshtein distance
      int distance = damerauLevenshteinDistance(title, lowerKeyword);
      double similarity =
          1.0 - (distance / max(title.length, lowerKeyword.length));
      if (similarity >= 0.7) {
        fuzzyMatches.add(book);
      }
    }

    // Prioritize exact matches, then partial, then fuzzy
    return [...exactMatches, ...partialMatches, ...fuzzyMatches];
  }

  List<Mortgage> searchMortgagesByRelativeName(String searchTerm) {
    String lowerKeyword = searchTerm.toLowerCase();

    // Perform the search
    List<Mortgage> exactMatches = [];
    List<Mortgage> partialMatches = [];
    List<Mortgage> fuzzyMatches = [];

    for (Mortgage book in state) {
      String title = book.relativeName.toLowerCase();

      // Exact match
      if (title == lowerKeyword) {
        exactMatches.add(book);
        continue;
      }

      // Partial match using 'contains'
      if (title.contains(lowerKeyword)) {
        partialMatches.add(book);
        continue;
      }

      // Fuzzy match using Damerau-Levenshtein distance
      int distance = damerauLevenshteinDistance(title, lowerKeyword);
      double similarity =
          1.0 - (distance / max(title.length, lowerKeyword.length));
      if (similarity >= 0.7) {
        fuzzyMatches.add(book);
      }
    }

    // Prioritize exact matches, then partial, then fuzzy
    return [...exactMatches, ...partialMatches, ...fuzzyMatches];
  }

  Future<void> searchMortgagesByDepositorNameDB(String searchTerm) async {
    final orderBy = '${MortgageFields.id} ASC';
    final result = await db.query(Mortgage.tableName,
        where: '${MortgageFields.depositorName} LIKE ?',
        whereArgs: ['%$searchTerm%'],
        orderBy: orderBy);
    state = result.map((json) => Mortgage.fromJson(json)).toList();
  }

  Future<void> searchMortgagesByRelativeNameDB(String searchTerm) async {
    final orderBy = '${MortgageFields.id} ASC';
    final result = await db.query(Mortgage.tableName,
        where: '${MortgageFields.relativeName} LIKE ?',
        whereArgs: ['%$searchTerm%'],
        orderBy: orderBy);
    state = result.map((json) => Mortgage.fromJson(json)).toList();
  }

  Future<int> add(
    String depositorName,
    String relativeName,
    String address,
    double loanAmount,
    double interestRate,
    double weight,
    int interestType,
    int compoundingFrequency,
    String additionalDetails,
    int itemId,
    int familyRelationId,
    int mortgageMaterialId,
  ) async {
    Mortgage mortgage = Mortgage(
      depositorName: depositorName,
      relativeName: relativeName,
      address: address,
      loanAmount: loanAmount,
      weight: weight,
      interestType: interestType, 
      compoundingFrequency: compoundingFrequency,
      additionalDetails: additionalDetails,
      interestRate: interestRate,
      itemId: itemId,
      familyRelationId: familyRelationId,
      mortgageMaterialId: mortgageMaterialId,
    );
    final id = await db.insert(Mortgage.tableName, mortgage.toJson());
    if (id > 0) {
      mortgage = mortgage.copy(id: id);
      state = [...state, mortgage];
      return id;
    }
    return -1;
  }

  Future<void> update(Mortgage mortgage) async {
    final id = await db.update(
      Mortgage.tableName,
      mortgage.toJson(),
      where: '${MortgageFields.id} = ?',
      whereArgs: [mortgage.id],
    );
    if (id > 0) {
      state = [
        for (final s in state)
          if (s.id == mortgage.id) mortgage else s
      ];
    }
  }

  Future<void> delete(int id) async {
    final rid = await db.delete(
      Mortgage.tableName,
      where: '${MortgageFields.id} = ?',
      whereArgs: [id],
    );
    if (rid > 0) {
      state = state.where((mortgage) => mortgage.id != id).toList();
    }
  }

  Future<void> bulkDelete(List<int> ids) async {
    final batch = db.batch();
    for (int id in ids) {
      batch.delete(
        Mortgage.tableName,
        where: '${MortgageFields.id} = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(continueOnError: true);
    state = state.where((mortgage) => !ids.contains(mortgage.id)).toList();
  }
}
