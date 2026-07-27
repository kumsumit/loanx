import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_color_picker_plus/flutter_color_picker_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:loanx/widget/snackbar.dart';
import 'package:local_auth/local_auth.dart';
import 'package:loanx/algo/damerau_lavenstien.dart';
import 'package:loanx/db/fastdb.dart';
import 'package:loanx/model/family_relation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/model/mortgage_material.dart';
import 'package:loanx/service/database_helper.dart';
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
  if (!FastDB.getSecure()) {
    return true;
  }
  final LocalAuthentication localAuthentication = LocalAuthentication();
  try {
    final bool canAuthenticateWithBiometrics =
        await localAuthentication.canCheckBiometrics;
    if (canAuthenticateWithBiometrics) {
      return await localAuthentication.authenticate(
        localizedReason: 'Please authenticate to access the app',
        persistAcrossBackgrounding: true,
      );
    } else if (await localAuthentication.isDeviceSupported()) {
      return await localAuthentication.authenticate(
        localizedReason: 'Please authenticate to access the app',
      );
    }
  } on PlatformException catch (e) {
    debugPrint(e.toString());
    return false;
  }
  return false;
}

@riverpod
class Secure extends _$Secure {
  @override
  bool build() => FastDB.getSecure();

  Future<void> toggle() async {
    state = !state;
    FastDB.putSecure(state);
    await FastDB.flush();
  }
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

@Riverpod(keepAlive: true)
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
class InterestRate extends _$InterestRate {
  @override
  double build() {
    return FastDB.getInterestRate();
  }

  void set(double interestRate) {
    state = interestRate;
    FastDB.putInterestRate(interestRate);
  }
}

@riverpod
class InterestFrequencyStatus extends _$InterestFrequencyStatus {
  @override
  InterestFrequency build() {
    return InterestFrequency.values[FastDB.getInterestFrequency()];
  }

  void set(InterestFrequency interestFrequency) {
    state = interestFrequency;
    FastDB.putInterestFrequency(interestFrequency.index);
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
class LoanSelectionList extends _$LoanSelectionList {
  @override
  List<int> build() => [];

  void add(int id) {
    state = [...state, id];
  }

  void remove(int id) {
    state = state.where((e) => e != id).toList();
  }

  void clear() {
    state = [];
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

  Future<void> setFromLogo(BuildContext context) async {
    bool isSet = true;
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
      isSet = true;
      if (context.mounted) {
        showSnackBar(context, "App Color Changed");
      }
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
          isSet = true;
          if (context.mounted) {
            showSnackBar(context, "App Color Changed");
          }
        }
      }
    }
    if (!isSet) {
      if (context.mounted) {
        showErrorSnackBar(context, "App Color Not Changed");
      }
    }
  }
}

@riverpod
class PickerColor extends _$PickerColor {
  @override
  String build() => FastDB.getAppColor();

  void set(Color color) {
    // state = color.value.toRadixString(16).substring(2);
    state = color.toHexString();
  }
}

@riverpod
Future<String> appVersion(Ref ref) async {
  return await MethodChannel('loanx').invokeMethod('versionName');
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
    final orderBy = FamilyRelationFields.name;
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
    final currentState = state.value;

    if (currentState != null &&
        currentState.any(
          (element) => element.name.toLowerCase() == name.toLowerCase(),
        )) {
      return -1;
    }

    FamilyRelation familyRelation = FamilyRelation(
      name: name,
      isAddedByUser: 1,
    );
    final id = await db.insert(
      FamilyRelation.tableName,
      familyRelation.toJson(),
    );

    if (id > 0) {
      familyRelation = familyRelation.copy(id: id);
      await updateDBTime();
      state = AsyncData([familyRelation, ...?currentState]);
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
      await updateDBTime();
      if (state.value != null) {
        state = AsyncData(
          state.value!
              .where((familyRelation) => familyRelation.id != id)
              .toList(),
        );
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
      state = AsyncData(
        state.value!
            .where((familyRelation) => !results.contains(familyRelation.id))
            .toList(),
      );
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
          if (s.id == familyRelation.id) familyRelation else s,
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
    final orderBy = MortgageMaterialFields.name;
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
    final currentState = state.value;

    if (currentState != null &&
        currentState.any(
          (element) => element.name.toLowerCase() == name.toLowerCase(),
        )) {
      return -1;
    }

    MortgageMaterial mortgageMaterial = MortgageMaterial(
      name: name,
      isAddedByUser: 1,
    );
    final id = await db.insert(
      MortgageMaterial.tableName,
      mortgageMaterial.toJson(),
    );

    if (id > 0) {
      mortgageMaterial = mortgageMaterial.copy(id: id);
      await updateDBTime();
      state = AsyncData([mortgageMaterial, ...?currentState]);
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
      await updateDBTime();
      state = AsyncData(
        state.value!
            .where((mortgageMaterial) => mortgageMaterial.id != id)
            .toList(),
      );
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
      state.value!.where((item) => !results.contains(item.id)).toList(),
    );
  }

  Future<void> updateMortagageMaterial(
    MortgageMaterial mortgageMaterial,
  ) async {
    final id = await db.update(
      MortgageMaterial.tableName,
      mortgageMaterial.toJson(),
      where: '${MortgageMaterialFields.id} = ?',
      whereArgs: [mortgageMaterial.id],
    );
    if (id > 0) {
      await updateDBTime();
      state = AsyncData([
        for (final s in state.value!)
          if (s.id == mortgageMaterial.id) mortgageMaterial else s,
      ]);
    }
  }
}

@Riverpod(keepAlive: true)
class LoanList extends _$LoanList {
  late Database db;

  @override
  Future<List<Loan>> build() async {
    return await readAllLoans();
  }

  Future<List<Loan>> readAllLoans() async {
    db = ref.watch(dBProvider).value!;
    final orderBy = '${LoanFields.dateCreated} DESC';
    final result = await db.query(Loan.tableName, orderBy: orderBy);
    debugPrint(result.toString());
    return result.map((json) => Loan.fromJson(json)).toList();
  }

  List<Loan> searchLoansByMortgageMaterialId(int mortgageMaterialId) {
    if (state.value == null) return [];
    return state.value!
        .where((loan) => loan.mortgageMaterialId == mortgageMaterialId)
        .toList();
  }

  List<Loan> searchLoansByDateCreated(DateTime dateCreated) {
    if (state.value == null) return [];
    return state.value!
        .where(
          (item) =>
              item.dateCreated.year == dateCreated.year &&
              item.dateCreated.month == dateCreated.month &&
              item.dateCreated.day == dateCreated.day,
        )
        .toList();
  }

  List<Loan> searchLoansByDateRange(DateTimeRange dateTimeRange) {
    if (state.value == null) return [];
    return state.value!
        .where(
          (item) =>
              item.dateCreated.isAfter(dateTimeRange.start) &&
              item.dateCreated.isBefore(
                dateTimeRange.end.add(Duration(days: 1)),
              ),
        )
        .toList();
  }

  Future<List<Loan>> readAllLoansByMortgageMaterialId(
    int mortgageMaterialId,
  ) async {
    final orderBy = '${LoanFields.id} ASC';
    final result = await db.query(
      Loan.tableName,
      where: '${LoanFields.mortgageMaterialId} = ?',
      whereArgs: [mortgageMaterialId],
      orderBy: orderBy,
    );
    return result.map((json) => Loan.fromJson(json)).toList();
  }

  List<Loan> searchLoansByDepositorName(String searchTerm) {
    if (state.value == null) return [];
    String lowerKeyword = searchTerm.toLowerCase();

    // Perform the search
    List<Loan> exactMatches = [];
    List<Loan> partialMatches = [];
    List<Loan> fuzzyMatches = [];

    for (Loan book in state.value!) {
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

  List<Loan> searchLoansByRelativeName(String searchTerm) {
    if (state.value == null) return [];
    String lowerKeyword = searchTerm.toLowerCase();

    // Perform the search
    List<Loan> exactMatches = [];
    List<Loan> partialMatches = [];
    List<Loan> fuzzyMatches = [];

    for (Loan book in state.value!) {
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

  Future<List<Loan>> searchLoansByDepositorNameDB(String searchTerm) async {
    final orderBy = '${LoanFields.id} ASC';
    final result = await db.query(
      Loan.tableName,
      where: '${LoanFields.depositorName} LIKE ?',
      whereArgs: ['%$searchTerm%'],
      orderBy: orderBy,
    );
    return result.map((json) => Loan.fromJson(json)).toList();
  }

  Future<List<Loan>> searchMortgagesByRelativeNameDB(String searchTerm) async {
    final orderBy = '${LoanFields.id} ASC';
    final result = await db.query(
      Loan.tableName,
      where: '${LoanFields.relativeName} LIKE ?',
      whereArgs: ['%$searchTerm%'],
      orderBy: orderBy,
    );
    return result.map((json) => Loan.fromJson(json)).toList();
  }

  Future<int> add(
    Loan? oldLoan,
    String depositorName,
    String phoneNumber,
    String relativeName,
    String address,
    double loanAmount,
    double interestRate,
    int interestType,
    int interestFrequency,
    String additionalDetails,
    int familyRelationId,
    int mortgageMaterialId,
  ) async {
    int id = -1;
    Loan loan = Loan(
      depositorName: depositorName,
      phoneNumber: phoneNumber,
      relativeName: relativeName,
      address: address,
      loanAmount: loanAmount,
      interestType: interestType,
      interestFrequency: interestFrequency,
      additionalDetails: additionalDetails,
      interestRate: interestRate,
      familyRelationId: familyRelationId,
      mortgageMaterialId: mortgageMaterialId,
    );
    if (oldLoan != null) {
      loan = loan.copy(
        id: oldLoan.id,
        dateCreated: oldLoan.dateCreated,
        dateFinished: oldLoan.dateFinished,
      );
      id = await db.update(
        Loan.tableName,
        loan.toJson(),
        where: '${LoanFields.id} = ?',
        whereArgs: [loan.id],
      );
      await updateDBTime();
      if (id > 0) {
        state = AsyncData([
          for (final s in state.value!)
            if (s.id == loan.id) loan else s,
        ]);
      }
    } else {
      id = await db.insert(Loan.tableName, loan.toJson());
      if (id > 0) {
        await updateDBTime();
        loan = loan.copy(id: id);
        if (state.value == null) {
          state = AsyncData([loan]);
        } else {
          state = AsyncData([loan, ...state.value!]);
        }
      }
    }
    return id;
  }

  Future<void> updateLoan(Loan loan) async {
    final id = await db.update(
      Loan.tableName,
      loan.toJson(),
      where: '${LoanFields.id} = ?',
      whereArgs: [loan.id],
    );
    if (id > 0) {
      await updateDBTime();
      state = AsyncData([
        for (final s in state.value!)
          if (s.id == loan.id) loan else s,
      ]);
    }
  }

  Future<void> delete(int id) async {
    if (state.value == null) return;
    final rid = await db.delete(
      Loan.tableName,
      where: '${LoanFields.id} = ?',
      whereArgs: [id],
    );
    if (rid > 0) {
      await updateDBTime();
      state = AsyncData(state.value!.where((loan) => loan.id != id).toList());
    }
  }

  Future<void> bulkDelete(List<int> ids) async {
    if (state.value == null) return;
    final batch = db.batch();
    for (int id in ids) {
      batch.delete(
        Loan.tableName,
        where: '${LoanFields.id} = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(continueOnError: true);
    await updateDBTime();
    state = AsyncData(
      state.value!.where((loan) => !ids.contains(loan.id)).toList(),
    );
  }
}

Future<void> updateDBTime() async {
  FastDB.putDbUpdateTime(DateTime.now().millisecondsSinceEpoch);
  await FastDB.flush();
}
