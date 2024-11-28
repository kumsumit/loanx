import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mortgage/algo/damerau_lavenstien.dart';
import 'package:mortgage/db/fastdb.dart';
import 'package:mortgage/model/family_relation.dart';
import 'package:mortgage/model/item.dart';
import 'package:mortgage/model/loan.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mortgage/model/mortgage.dart';
import 'package:mortgage/model/mortgage_material.dart';
import 'package:mortgage/service/database_helper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
part 'provider.g.dart';

final dailyBackUpUpload = 'dailyBackupUpload';
// final dailyBackUpDownload = 'dailyBackupDownload';

final networkCheckerProvider = StreamProvider<bool>((ref) {
  final internetChecker = InternetConnection.createInstance(
    customCheckOptions: [
      InternetCheckOption(uri: Uri.parse('https://drive.google.com')),
    ],
  );
  return internetChecker.onStatusChange.map((status) {
    return status == InternetStatus.connected;
  });
});

@Riverpod(keepAlive: true)
Future<bool> authenticate(Ref ref) async {
  if(!FastDB.getSecure()){
    return true;
  }
  final LocalAuthentication localAuthentication = LocalAuthentication();
  try {
    final bool canAuthenticateWithBiometrics =
        await localAuthentication.canCheckBiometrics;
    if (canAuthenticateWithBiometrics) {
      return await localAuthentication.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          // biometricOnly: true,
        ),
      );
    } else if (await localAuthentication.isDeviceSupported()) {
      return await localAuthentication.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: false,
        ),
      );
    }
  } on PlatformException catch (e) {
    debugPrint(e.toString());
    return false;
  }
  return false;
}

@riverpod
class DriveAccessToken extends _$DriveAccessToken {
  @override 
  String build() => FastDB.getDriveAccessToken();
  
  void set(String token) {
    state = token;
  }

  void remove() {
    state = "";
  }

}


@riverpod
class BackUpRegistered extends _$BackUpRegistered {
  @override
  bool build() => FastDB.getIsBackUpRegistered();

  void set(bool isRegistered) {
    state = isRegistered;
    FastDB.putIsBackUpRegistered(isRegistered);
  }
}

@riverpod
class DisplayName extends _$DisplayName {
  @override
  String build() => FastDB.getDisplayName();

  void set(String displayName) {
    state = displayName;
  }

  void remove() {
    state = "";
  }
}

@riverpod
class PhotoUrl extends _$PhotoUrl {
  @override
  String build() => FastDB.getPhotourl();

  void set(String photoUrl) {
    state = photoUrl;
  }

  void remove() {
    state = "";
  }
}

@riverpod
class Email extends _$Email {
  @override
  String build() => FastDB.getEmail();

  void set(String email) {
    state = email;
  }

  void remove() {
    state = "";
  }
}

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

@riverpod
class HoldingPeriod extends _$HoldingPeriod {
  @override
  int build() {
    return FastDB.getHoldingPeriod();
  }

  void set(int val) {
    state = val;
    FastDB.putHoldingPeriod(state);
  }
}

@riverpod
class ScheduledBackUpTimeHour extends _$ScheduledBackUpTimeHour {
  @override
  int build() {
    return FastDB.getScheduledBackUpTimeHour();
  }

  void set(int scheduledBackUpTimeHour) {
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

  void set(int scheduledBackUpTimeMinute) {
    state = scheduledBackUpTimeMinute;
    FastDB.putScheduledBackUpTimeMinute(scheduledBackUpTimeMinute);
  }
}

@riverpod
class InterestTypeStatus extends _$InterestTypeStatus {
  @override
  InterestType build() {
    return InterestType.values[FastDB.getInterestType()];
  }

  void set(InterestType interestType) {
    state = interestType;
    FastDB.putInterestType(interestType.index);
  }
}

@riverpod
class CompoundingFrequencyStatus extends _$CompoundingFrequencyStatus {
  @override
  CompoundingFrequency build() {
    return CompoundingFrequency.values[FastDB.getCompoundingFrequency()];
  }

  void set(CompoundingFrequency compundingFrequency) {
    state = compundingFrequency;
    FastDB.putCompoundingFrequency(compundingFrequency.index);
  }
}

@riverpod
class BackupStatus extends _$BackupStatus {
  @override
  bool build() {
    return false;
  }

  void set(bool backupStatus) {
    state = backupStatus;
  }
}

@riverpod
class BackupDownloadStatus extends _$BackupDownloadStatus {
  @override
  bool build() {
    return false;
  }

  void set(bool backupStatus) {
    state = backupStatus;
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
  const mortgage = MethodChannel('mortgage');
  return await mortgage.invokeMethod('versionName') +
      '.' +
      (await mortgage.invokeMethod('versionCode')).toString();
}

@Riverpod(keepAlive: true)
class DB extends _$DB {
  @override
  Future<Database> build() async {
    return await DatabaseHelper.instance.database;
  }
}

@Riverpod(keepAlive: true)
class FamilyRelationList extends _$FamilyRelationList {
  late Database db;

  @override
  Future<List<FamilyRelation>> build() async {
    return await readAllFamilyRelations();
  }

  Future<List<FamilyRelation>> readAllFamilyRelations() async {
    db = ref.watch(dBProvider).value!;
    final orderBy = '${FamilyRelationFields.id} DESC';
    final result = await db.query(FamilyRelation.tableName, orderBy: orderBy);
    return result.map((json) => FamilyRelation.fromJson(json)).toList();
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
    if (state.value == null || state.value!.isEmpty) {
      FamilyRelation familyRelation =
          FamilyRelation(name: name, isAddedByUser: 1);
      final id =
          await db.insert(FamilyRelation.tableName, familyRelation.toJson());
      if (id > 0) {
        familyRelation = familyRelation.copy(id: id);
        await updateDBTime();
        state = AsyncData([familyRelation]);
        return id;
      }
    } else if (state.value!
        .any((element) => element.name.toLowerCase() == name.toLowerCase())) {
      return -1;
    } else {
      FamilyRelation familyRelation =
          FamilyRelation(name: name, isAddedByUser: 1);
      final id =
          await db.insert(FamilyRelation.tableName, familyRelation.toJson());
      if (id > 0) {
        familyRelation = familyRelation.copy(id: id);
        await updateDBTime();
        state = AsyncData([familyRelation, ...state.value!]);
        return id;
      }
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
      await updateDBTime();
      if (state.value != null) {
        state = AsyncData(state.value!
            .where((familyRelation) => familyRelation.id != id)
            .toList());
      }
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
    await updateDBTime();
    if (state.value != null) {
      state = AsyncData(state.value!
          .where((familyRelation) => !results.contains(familyRelation.id))
          .toList());
    }
  }

  Future<void> updateData(FamilyRelation familyRelation) async {
    final id = await db.update(
      FamilyRelation.tableName,
      familyRelation.toJson(),
      where: '${FamilyRelationFields.id} = ?',
      whereArgs: [familyRelation.id],
    );
    if (id > 0) {
      await updateDBTime();
      state = AsyncData([
        for (final s in state.value!)
          if (s.id == familyRelation.id) familyRelation else s
      ]);
    }
  }
}

@Riverpod(keepAlive: true)
class MortgageMaterialList extends _$MortgageMaterialList {
  late Database db;

  @override
  Future<List<MortgageMaterial>> build() async {
    return await readAllMortgageMaterials();
  }

  Future<List<MortgageMaterial>> readAllMortgageMaterials() async {
    db = ref.watch(dBProvider).value!;
    final orderBy = '${MortgageMaterialFields.id} DESC';
    final result = await db.query(MortgageMaterial.tableName, orderBy: orderBy);
    return result.map((json) => MortgageMaterial.fromJson(json)).toList();
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
    if (state.value == null || state.value!.isEmpty) {
      MortgageMaterial mortgageMaterial =
          MortgageMaterial(name: name, isAddedByUser: 1);
      final id = await db.insert(
          MortgageMaterial.tableName, mortgageMaterial.toJson());
      if (id > 0) {
        mortgageMaterial = mortgageMaterial.copy(id: id);
        await updateDBTime();
        state = AsyncData([mortgageMaterial]);
        return id;
      }
    } else if (state.value!
        .any((element) => element.name.toLowerCase() == name.toLowerCase())) {
      return -1;
    } else if (state.value != null && state.value!.isNotEmpty) {
      MortgageMaterial mortgageMaterial =
          MortgageMaterial(name: name, isAddedByUser: 1);
      final id = await db.insert(
          MortgageMaterial.tableName, mortgageMaterial.toJson());
      if (id > 0) {
        await updateDBTime();
        mortgageMaterial = mortgageMaterial.copy(id: id);
        state = AsyncData([mortgageMaterial, ...state.value!]);
        return id;
      }
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
      await updateDBTime();
      state = AsyncData(state.value!
          .where((mortgageMaterial) => mortgageMaterial.id != id)
          .toList());
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
    await updateDBTime();
    state = AsyncData(
        state.value!.where((item) => !results.contains(item.id)).toList());
  }

  Future<void> updateMortagageMaterial(
      MortgageMaterial mortgageMaterial) async {
    final id = await db.update(
      MortgageMaterial.tableName,
      mortgageMaterial.toJson(),
      where: '${ItemFields.id} = ?',
      whereArgs: [mortgageMaterial.id],
    );
    if (id > 0) {
      await updateDBTime();
      state = AsyncData([
        for (final s in state.value!)
          if (s.id == mortgageMaterial.id) mortgageMaterial else s
      ]);
    }
  }
}

@Riverpod(keepAlive: true)
class ItemList extends _$ItemList {
  late Database db;

  @override
  Future<List<Item>> build() async {
    return await readAllItems();
  }

  Future<List<Item>> readAllItems() async {
    db = ref.watch(dBProvider).value!;
    final orderBy = '${ItemFields.id} DESC';
    final result = await db.query(Item.tableName, orderBy: orderBy);
    return result.map((json) => Item.fromJson(json)).toList();
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
    if (state.value == null || state.value!.isEmpty) {
      Item item = Item(name: name, isAddedByUser: 1);
      final id = await db.insert(Item.tableName, item.toJson());
      if (id > 0) {
        await updateDBTime();
        item = item.copy(id: id);
        state = AsyncData([item]);
        return id;
      }
    }
    if (state.value!
        .any((element) => element.name.toLowerCase() == name.toLowerCase())) {
      return -1;
    }
    Item item = Item(name: name, isAddedByUser: 1);
    final id = await db.insert(Item.tableName, item.toJson());
    if (id > 0) {
      await updateDBTime();
      item = item.copy(id: id);
      state = AsyncData([item, ...state.value!]);
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
    await updateDBTime();
    state = AsyncData(
        state.value!.where((item) => !results.contains(item.id)).toList());
  }

  Future<void> updateItem(Item item) async {
    final id = await db.update(
      Item.tableName,
      item.toJson(),
      where: '${ItemFields.id} = ?',
      whereArgs: [item.id],
    );
    if (id > 0) {
      await updateDBTime();
      state = AsyncData([
        for (final s in state.value!)
          if (s.id == item.id) item else s
      ]);
    }
  }

  Future<void> delete(int id) async {
    final rid = await db.delete(
      Item.tableName,
      where: '${ItemFields.id} = ?',
      whereArgs: [id],
    );
    if (rid > 0) {
      await updateDBTime();
      state = AsyncData(state.value!.where((item) => item.id != id).toList());
    }
  }
}

@Riverpod(keepAlive: true)
class MortgageList extends _$MortgageList {
  late Database db;

  @override
  Future<List<Mortgage>> build() async {
    return await readAllMortgages();
  }

  Future<List<Mortgage>> readAllMortgages() async {
    db = ref.watch(dBProvider).value!;
    final orderBy = '${MortgageFields.dateCreated} DESC';
    final result = await db.query(Mortgage.tableName, orderBy: orderBy);
    return result.map((json) => Mortgage.fromJson(json)).toList();
  }

  List<Mortgage> searchMortgagesByItemId(int itemId) {
    if (state.value == null) return [];
    debugPrint("====================");
    debugPrint(itemId.toString());
    final mor =
        state.value!.where((mortgage) => mortgage.itemId == itemId).toList();
    debugPrint(mor.length.toString());
    return mor;
  }

  List<Mortgage> searchMortgagesByMortgageMaterialId(int mortgageMaterialId) {
    if (state.value == null) return [];
    return state.value!
        .where((item) => item.mortgageMaterialId == mortgageMaterialId)
        .toList();
  }

  List<Mortgage> searchMortgagesByDateCreated(DateTime dateCreated) {
    if (state.value == null) return [];
    return state.value!
        .where((item) =>
            item.dateCreated.year == dateCreated.year &&
            item.dateCreated.month == dateCreated.month &&
            item.dateCreated.day == dateCreated.day)
        .toList();
  }

  List<Mortgage> searchMortgagesByDateRange(DateTimeRange dateTimeRange) {
    if (state.value == null) return [];
    return state.value!
        .where((item) =>
            item.dateCreated.isAfter(dateTimeRange.start) &&
            item.dateCreated.isBefore(dateTimeRange.end.add(Duration(days: 1))))
        .toList();
  }

  Future<List<Mortgage>> searchMortgagesByItemIdDB(int itemId) async {
    final orderBy = '${MortgageFields.id} ASC';
    final result = await db.query(Mortgage.tableName,
        where: '${MortgageFields.itemId} = ?',
        whereArgs: [itemId],
        orderBy: orderBy);
    return result.map((json) => Mortgage.fromJson(json)).toList();
  }

  Future<List<Mortgage>> readAllMortgagesByMortgageMaterialId(
      int mortgageMaterialId) async {
    final orderBy = '${MortgageFields.id} ASC';
    final result = await db.query(Mortgage.tableName,
        where: '${MortgageFields.mortgageMaterialId} = ?',
        whereArgs: [mortgageMaterialId],
        orderBy: orderBy);
    return result.map((json) => Mortgage.fromJson(json)).toList();
  }

  List<Mortgage> searchMortgagesByDepositorName(String searchTerm) {
    if (state.value == null) return [];
    String lowerKeyword = searchTerm.toLowerCase();

    // Perform the search
    List<Mortgage> exactMatches = [];
    List<Mortgage> partialMatches = [];
    List<Mortgage> fuzzyMatches = [];

    for (Mortgage book in state.value!) {
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
    if (state.value == null) return [];
    String lowerKeyword = searchTerm.toLowerCase();

    // Perform the search
    List<Mortgage> exactMatches = [];
    List<Mortgage> partialMatches = [];
    List<Mortgage> fuzzyMatches = [];

    for (Mortgage book in state.value!) {
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

  Future<List<Mortgage>> searchMortgagesByDepositorNameDB(
      String searchTerm) async {
    final orderBy = '${MortgageFields.id} ASC';
    final result = await db.query(Mortgage.tableName,
        where: '${MortgageFields.depositorName} LIKE ?',
        whereArgs: ['%$searchTerm%'],
        orderBy: orderBy);
    return result.map((json) => Mortgage.fromJson(json)).toList();
  }

  Future<List<Mortgage>> searchMortgagesByRelativeNameDB(
      String searchTerm) async {
    final orderBy = '${MortgageFields.id} ASC';
    final result = await db.query(Mortgage.tableName,
        where: '${MortgageFields.relativeName} LIKE ?',
        whereArgs: ['%$searchTerm%'],
        orderBy: orderBy);
    return result.map((json) => Mortgage.fromJson(json)).toList();
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
      await updateDBTime();
      mortgage = mortgage.copy(id: id);
      if (state.value == null) {
        state = AsyncData([mortgage]);
      } else {
        state = AsyncData([mortgage, ...state.value!]);
      }
      return id;
    }
    return -1;
  }

  Future<void> updateMortgage(Mortgage mortgage) async {
    if (state.value == null) return;
    final id = await db.update(
      Mortgage.tableName,
      mortgage.toJson(),
      where: '${MortgageFields.id} = ?',
      whereArgs: [mortgage.id],
    );
    await updateDBTime();
    if (id > 0) {
      state = AsyncData([
        for (final s in state.value!)
          if (s.id == mortgage.id) mortgage else s
      ]);
    }
  }

  Future<void> delete(int id) async {
    if (state.value == null) return;
    final rid = await db.delete(
      Mortgage.tableName,
      where: '${MortgageFields.id} = ?',
      whereArgs: [id],
    );
    if (rid > 0) {
      await updateDBTime();
      state = AsyncData(
          state.value!.where((mortgage) => mortgage.id != id).toList());
    }
  }

  Future<void> bulkDelete(List<int> ids) async {
    if (state.value == null) return;
    final batch = db.batch();
    for (int id in ids) {
      batch.delete(
        Mortgage.tableName,
        where: '${MortgageFields.id} = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(continueOnError: true);
    await updateDBTime();
    state = AsyncData(
        state.value!.where((mortgage) => !ids.contains(mortgage.id)).toList());
  }
}

Future<void> updateDBTime() async {
  FastDB.putDbUpdateTime(DateTime.now().millisecondsSinceEpoch);
  await FastDB.flush();
}
