import 'dart:convert';
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
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/service/currency_presentation.dart';
import 'package:loanx/model/family_relation.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/model/loan_change.dart';
import 'package:loanx/model/mortgage_material.dart';
import 'package:loanx/model/weight_unit.dart';
import 'package:loanx/service/database_helper.dart';
import 'package:loanx/service/canonical_migration.dart';
import 'package:loanx/service/auth_client.dart';
import 'package:loanx/domain/money.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
part 'provider.g.dart';

final dailyBackUpUpload = 'dailyBackupUpload';
// final dailyBackUpDownload = 'dailyBackupDownload';

final loanChangesProvider = FutureProvider.family<List<LoanChange>, int>((
  ref,
  loanId,
) async {
  final db = await DatabaseHelper.instance.database;
  final owners = await db.query('localOwners');
  if (owners.length != 1) return const [];
  final owned = await db.query(
    Loan.tableName,
    where: 'id = ? AND ownerId = ?',
    whereArgs: [loanId, owners.single['id']],
    limit: 1,
  );
  if (owned.isEmpty) return const [];
  final rows = await db.query(
    LoanChange.tableName,
    where: '${LoanChangeFields.loanId} = ?',
    whereArgs: [loanId],
    orderBy: '${LoanChangeFields.createdAt} DESC',
  );
  return rows.map(LoanChange.fromJson).toList();
});

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
  if (!AppSettings.getSecure()) {
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
  bool build() => AppSettings.getSecure();

  Future<void> toggle() async {
    state = !state;
    AppSettings.putSecure(state);
    await AppSettings.flush();
  }
}

@riverpod
class DriveAccessToken extends _$DriveAccessToken {
  @override
  String build() => AppSettings.getDriveAccessToken();

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
  bool build() => AppSettings.getIsBackUpRegistered();

  Future<void> set(bool isRegistered) async {
    state = isRegistered;
    AppSettings.putIsBackUpRegistered(isRegistered);
    await AppSettings.flush();
  }
}

@riverpod
class DisplayName extends _$DisplayName {
  @override
  String build() => AppSettings.getDisplayName();

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
  String build() => AppSettings.getPhotourl();

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
  String build() => AppSettings.getEmail();

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
    return ThemeMode.values[AppSettings.getThemeMode()];
  }

  Future<void> set() async {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    AppSettings.putThemeMode(state.index);
    await AppSettings.flush();
  }
}

@riverpod
class HoldingPeriod extends _$HoldingPeriod {
  @override
  int build() {
    return AppSettings.getHoldingPeriod();
  }

  void set(int val) {
    state = val;
    AppSettings.putHoldingPeriod(state);
  }
}

@riverpod
class ScheduledBackUpTimeHour extends _$ScheduledBackUpTimeHour {
  @override
  int build() {
    return AppSettings.getScheduledBackUpTimeHour();
  }

  void set(int scheduledBackUpTimeHour) {
    state = scheduledBackUpTimeHour;
    AppSettings.putScheduledBackUpTimeHour(scheduledBackUpTimeHour);
  }
}

@riverpod
class ScheduledBackUpTimeMinute extends _$ScheduledBackUpTimeMinute {
  @override
  int build() {
    return AppSettings.getScheduledBackUpTimeMinute();
  }

  void set(int scheduledBackUpTimeMinute) {
    state = scheduledBackUpTimeMinute;
    AppSettings.putScheduledBackUpTimeMinute(scheduledBackUpTimeMinute);
  }
}

@riverpod
class InterestTypeStatus extends _$InterestTypeStatus {
  @override
  InterestType build() {
    return InterestType.values[AppSettings.getInterestType()];
  }

  void set(InterestType interestType) {
    state = interestType;
    AppSettings.putInterestType(interestType.index);
  }
}

@riverpod
class InterestRate extends _$InterestRate {
  @override
  double build() {
    return AppSettings.getInterestRate();
  }

  void set(double interestRate) {
    state = interestRate;
    AppSettings.putInterestRate(interestRate);
  }
}

@riverpod
class InterestFrequencyStatus extends _$InterestFrequencyStatus {
  @override
  InterestFrequency build() {
    return InterestFrequency.values[AppSettings.getInterestFrequency()];
  }

  void set(InterestFrequency interestFrequency) {
    state = interestFrequency;
    AppSettings.putInterestFrequency(interestFrequency.index);
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

/// Whether the connected Google Drive account has a LoanX backup to restore.
/// Connecting an account alone does not guarantee that a backup exists.
@riverpod
class BackupAvailable extends _$BackupAvailable {
  @override
  bool build() => false;

  void set(bool available) {
    state = available;
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
  String build() => AppSettings.getAppColor();

  Future<void> set() async {
    state = ref.read(pickerColorProvider);
    AppSettings.putAppColor(state);
    await AppSettings.flush();
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
  String build() => AppSettings.getAppColor();

  void set(Color color) {
    // state = color.value.toRadixString(16).substring(2);
    state = color.toHexString();
  }
}

@riverpod
Future<String> appVersion(Ref ref) async {
  final version = await MethodChannel(
    'loanx',
  ).invokeMethod<String>('versionName');
  final versionName = version?.trim();
  if (versionName == null || versionName.isEmpty) return 'Unavailable';

  try {
    final buildNumber = await MethodChannel(
      'loanx',
    ).invokeMethod<int>('versionCode');
    return buildNumber == null ? versionName : '$versionName+$buildNumber';
  } on PlatformException {
    return versionName;
  }
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
class WeightUnitList extends _$WeightUnitList {
  late Database db;

  @override
  Future<List<WeightUnit>> build() async {
    db = ref.watch(dBProvider).value!;
    final result = await db.query(
      WeightUnit.tableName,
      orderBy: WeightUnitFields.name,
    );
    return result.map(WeightUnit.fromJson).toList();
  }

  Future<int> add(String name, String symbol) async {
    final normalizedSymbol = symbol.trim();
    final current = state.value ?? const <WeightUnit>[];
    if (current.any(
      (unit) =>
          unit.name.toLowerCase() == name.trim().toLowerCase() ||
          unit.symbol.toLowerCase() == normalizedSymbol.toLowerCase(),
    )) {
      return -1;
    }
    var unit = WeightUnit(
      name: name.trim(),
      symbol: normalizedSymbol,
      isAddedByUser: 1,
    );
    final id = await db.insert(WeightUnit.tableName, unit.toJson());
    if (id <= 0) return -1;
    unit = unit.copy(id: id);
    await updateDBTime();
    state = AsyncData(
      [...current, unit]..sort((a, b) => a.name.compareTo(b.name)),
    );
    return id;
  }

  Future<void> updateData(WeightUnit unit) async {
    final changed = await db.update(
      WeightUnit.tableName,
      unit.toJson(),
      where: '${WeightUnitFields.id} = ?',
      whereArgs: [unit.id],
    );
    if (changed > 0) {
      await updateDBTime();
      state = AsyncData([
        for (final item in state.value ?? const <WeightUnit>[])
          if (item.id == unit.id) unit else item,
      ]);
    }
  }

  Future<void> delete(int id) async {
    final deleted = await db.delete(
      WeightUnit.tableName,
      where: '${WeightUnitFields.id} = ?',
      whereArgs: [id],
    );
    if (deleted > 0) {
      await updateDBTime();
      state = AsyncData(
        (state.value ?? const <WeightUnit>[])
            .where((unit) => unit.id != id)
            .toList(),
      );
    }
  }
}

@Riverpod(keepAlive: true)
class LoanList extends _$LoanList {
  late Database db;

  Future<String?> _ownerId(DatabaseExecutor executor) async {
    final owners = await executor.query('localOwners');
    if (owners.isEmpty) return null;
    if (owners.length != 1 || owners.single['id'] is! String) {
      throw StateError('A single local owner is required.');
    }
    return owners.single['id'] as String;
  }

  Future<String> _requiredOwnerId(DatabaseExecutor executor) async =>
      await _ownerId(executor) ??
      (throw StateError('Local workspace is unavailable.'));

  void _requireLenderWrite() {
    if (AppSettings.getUsesBorrowerExperience()) {
      throw StateError('Borrower financial records are read-only.');
    }
  }

  @override
  Future<List<Loan>> build() async {
    return await readAllLoans();
  }

  Future<List<Loan>> readAllLoans() async {
    db = ref.watch(dBProvider).value!;
    final owner = await _ownerId(db);
    if (owner == null) return [];
    final orderBy = '${LoanFields.dateCreated} DESC';
    final result = await db.query(
      Loan.tableName,
      where: 'ownerId = ?',
      whereArgs: [owner],
      orderBy: orderBy,
    );
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
    final owner = await _ownerId(db);
    if (owner == null) return [];
    final result = await db.query(
      Loan.tableName,
      where: '${LoanFields.mortgageMaterialId} = ? AND ownerId = ?',
      whereArgs: [mortgageMaterialId, owner],
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
    final owner = await _ownerId(db);
    if (owner == null) return [];
    final orderBy = '${LoanFields.id} ASC';
    final result = await db.query(
      Loan.tableName,
      where: '${LoanFields.depositorName} LIKE ? AND ownerId = ?',
      whereArgs: ['%$searchTerm%', owner],
      orderBy: orderBy,
    );
    return result.map((json) => Loan.fromJson(json)).toList();
  }

  Future<List<Loan>> searchMortgagesByRelativeNameDB(String searchTerm) async {
    final owner = await _ownerId(db);
    if (owner == null) return [];
    final orderBy = '${LoanFields.id} ASC';
    final result = await db.query(
      Loan.tableName,
      where: '${LoanFields.relativeName} LIKE ? AND ownerId = ?',
      whereArgs: ['%$searchTerm%', owner],
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
    double weight,
    String weightUnit,
    double interestRate,
    int interestType,
    int interestFrequency,
    int mortgageTermYears,
    int lockInDays,
    double earlyRedemptionCharge,
    String additionalDetails,
    String termsAndConditions,
    int familyRelationId,
    int mortgageMaterialId, [
    String? currency,
    bool borrowing = false,
  ]) async {
    _requireLenderWrite();
    if (borrowing) {
      throw StateError('Borrowers cannot manually record loan details.');
    }
    // `add` can be called while this notifier is rebuilding (for example just
    // after a restore). Do not rely on the `late` field having been populated
    // by `readAllLoans` first.
    db = await ref.read(dBProvider.future);
    Loan loan = Loan(
      depositorName: depositorName,
      phoneNumber: phoneNumber,
      relativeName: relativeName,
      address: address,
      loanAmount: loanAmount,
      // Existing records retain their original currency. New records use the
      // country selected during verified phone onboarding.
      currency:
          oldLoan?.currency ?? currency ?? CurrencyPresentation.defaultCurrency,
      weight: weight,
      weightUnit: weightUnit,
      interestType: interestType,
      interestFrequency: interestFrequency,
      mortgageTermYears: mortgageTermYears,
      lockInDays: lockInDays,
      earlyRedemptionCharge: earlyRedemptionCharge,
      additionalDetails: additionalDetails,
      termsAndConditions: termsAndConditions,
      interestRate: interestRate,
      familyRelationId: familyRelationId,
      mortgageMaterialId: mortgageMaterialId,
    );
    final id = await db.transaction((transaction) async {
      if (oldLoan != null) {
        final previous = await _readLoan(transaction, oldLoan.id);
        loan = loan.copy(
          id: previous.id,
          dateCreated: previous.dateCreated,
          dateFinished: previous.dateFinished,
          completedBy: previous.completedBy,
          settlementAmount: previous.settlementAmount,
          completionReference: previous.completionReference,
          completionNotes: previous.completionNotes,
          syncState: previous.syncState,
          clientConfirmedAt: previous.clientConfirmedAt,
        );
        final changed = await transaction.update(
          Loan.tableName,
          loan.toJson(),
          where: '${LoanFields.id} = ? AND ownerId = ?',
          whereArgs: [loan.id, await _requiredOwnerId(transaction)],
        );
        if (changed != 1) {
          throw StateError('Loan update did not affect one row.');
        }
        await _recordChange(
          transaction,
          loan.id!,
          _describeChanges(previous, loan),
        );
        return changed;
      }
      var owners = await transaction.query('localOwners');
      if (owners.isEmpty) {
        final now = DateTime.now().toUtc().toIso8601String();
        final ownerId = CanonicalMigration.newId();
        final selfPartyId = CanonicalMigration.newId();
        await transaction.insert('localOwners', {
          'id': ownerId,
          'selfPartyId': selfPartyId,
          'createdAt': now,
        });
        await transaction.insert('parties', {
          'id': selfPartyId,
          'ownerId': ownerId,
          'displayName': 'Local owner',
          'status': 'ACTIVE',
          'createdAt': now,
          'updatedAt': now,
        });
        owners = await transaction.query('localOwners');
      }
      final identity = await CanonicalMigration.identityForNewLoan(
        transaction,
        loan.toJson(),
        ownerId: owners.single['id'] as String,
        borrowing: borrowing,
      );
      final createdId = await transaction.insert(Loan.tableName, {
        ...loan.toJson(),
        ...identity,
      });
      final owner = owners.single;
      final ownerId = owner['id'] as String;
      final remoteLenderPartyId = owner['remotePartyId'] as String?;
      final borrowerPartyId = identity['borrowerPartyId'] as String;
      final loanUid = identity['uid'] as String;
      final borrowerRows = await transaction.query(
        'parties',
        where: 'id = ? AND ownerId = ?',
        whereArgs: [borrowerPartyId, ownerId],
        limit: 1,
      );
      if (borrowerRows.length != 1) {
        throw StateError('Borrower party was not created.');
      }
      // Phone-based loans use the existing invitation/claim flow below the
      // form. Sending both a direct loan mutation and an invitation would let
      // the borrower claim the same UUID through two different paths. Loans
      // without a phone are standalone lender records and sync directly.
      if (remoteLenderPartyId != null &&
          remoteLenderPartyId.isNotEmpty &&
          loan.phoneNumber.trim().isEmpty) {
        final borrower = borrowerRows.single;
        final now = DateTime.now().toUtc().toIso8601String();
        final partyPayload = <String, Object?>{
          'display_name': borrower['displayName'],
          // The legacy loan form does not retain an E.164 country alongside
          // its free-form phone field. Do not send an unvalidated phone to the
          // server; the private local contact remains intact.
          'phone_e164': null,
          'email': borrower['email'],
          'country_code': borrower['countryCode'],
          'status': 'active',
        };
        final scale = CurrencyPresentation.fractionDigits(loan.currency);
        final principal = Money.parse(
          CanonicalMigration.exactTotal([loan.loanAmount]),
          currency: loan.currency,
          scale: scale,
        );
        final loanPayload = <String, Object?>{
          'relationship_id': null,
          'lender_party_id': remoteLenderPartyId,
          'borrower_party_id': borrowerPartyId,
          'principal_minor': int.parse(principal.minorUnits.toString()),
          'currency': loan.currency,
          'currency_scale': scale,
          'loan_date': loan.dateCreated.toUtc().toIso8601String().substring(
            0,
            10,
          ),
          'maturity_date': null,
          'lifecycle': 'active',
          'calculation_contract': 'legacy-v1',
          'status': 'active',
        };
        await transaction.insert('pendingSyncMutations', {
          'id': borrowerPartyId,
          'ownerId': ownerId,
          'operationId': borrowerPartyId,
          'entityType': 'party',
          'entityId': borrowerPartyId,
          'operation': 'create',
          'expectedRevision': 0,
          'payloadJson': jsonEncode(partyPayload),
          'status': 'PENDING',
          'attemptCount': 0,
          'createdAt': now,
          'updatedAt': now,
        });
        await transaction.insert('pendingSyncMutations', {
          'id': loanUid,
          'ownerId': ownerId,
          'operationId': loanUid,
          'entityType': 'loan',
          'entityId': loanUid,
          'operation': 'create',
          'expectedRevision': 0,
          'payloadJson': jsonEncode(loanPayload),
          'status': 'PENDING',
          'attemptCount': 0,
          'createdAt': DateTime.parse(
            now,
          ).add(const Duration(microseconds: 1)).toIso8601String(),
          'updatedAt': now,
        });
      }
      await _recordChange(transaction, createdId, 'Loan record created');
      loan = loan.copy(id: createdId);
      return createdId;
    });
    ref.invalidate(loanChangesProvider(loan.id!));
    state = AsyncData(await readAllLoans());
    await updateDBTime();
    try {
      await AuthClient().flushPendingSyncMutations(database: db);
    } catch (_) {
      // The local transaction is authoritative while offline. The durable
      // mutation queue retries when the session/network becomes available.
    }
    return id;
  }

  Future<void> updateLoan(Loan loan) async {
    _requireLenderWrite();
    db = await ref.read(dBProvider.future);
    try {
      await db.transaction((transaction) async {
        // The UI may have mutated its Loan instance. Read the committed record
        // inside the write transaction so the audit retains the actual before state.
        final previous = await _readLoan(transaction, loan.id);
        // Sync acknowledgements can arrive while an older Loan object is still
        // on screen. Never let that stale object downgrade the durable marker.
        loan = loan.copy(
          syncState: previous.syncState,
          clientConfirmedAt: previous.clientConfirmedAt,
        );
        final changed = await transaction.update(
          Loan.tableName,
          loan.toJson(),
          where: '${LoanFields.id} = ? AND ownerId = ?',
          whereArgs: [loan.id, await _requiredOwnerId(transaction)],
        );
        if (changed != 1) {
          throw StateError('Loan update did not affect one row.');
        }
        await _recordChange(
          transaction,
          loan.id!,
          _describeChanges(previous, loan),
        );
      });
    } catch (_) {
      // A caller can mutate an object in provider state before submitting it.
      // Reload after rollback so failed writes do not remain visible as saved.
      state = AsyncData(await readAllLoans());
      rethrow;
    }
    ref.invalidate(loanChangesProvider(loan.id!));
    state = AsyncData(await readAllLoans());
    await updateDBTime();
  }

  /// Records that the borrower contact was verified with the OTP sent to the
  /// phone number. This is the app's client-confirmed state; it is not inferred
  /// from a successful local write or from server delivery.
  Future<void> markClientConfirmed(int id) async {
    _requireLenderWrite();
    db = await ref.read(dBProvider.future);
    final ownerId = await _requiredOwnerId(db);
    final changed = await db.update(
      Loan.tableName,
      {LoanFields.clientConfirmedAt: DateTime.now().toUtc().toIso8601String()},
      where: '${LoanFields.id} = ? AND ownerId = ?',
      whereArgs: [id, ownerId],
    );
    if (changed != 1) return;
    state = AsyncData(await readAllLoans());
    ref.invalidate(loanChangesProvider(id));
    await updateDBTime();
  }

  /// Records a durable server acknowledgement for a local loan UUID.
  Future<void> markServerSaved(String loanUid) async {
    db = await ref.read(dBProvider.future);
    final ownerId = await _requiredOwnerId(db);
    final changed = await db.update(
      Loan.tableName,
      {LoanFields.syncState: Loan.serverSaved},
      where: 'uid = ? AND ownerId = ?',
      whereArgs: [loanUid, ownerId],
    );
    if (changed != 1) return;
    state = AsyncData(await readAllLoans());
    await updateDBTime();
  }

  Future<Loan> _readLoan(DatabaseExecutor executor, int? id) async {
    if (id == null) throw ArgumentError.notNull('loan.id');
    final owners = await executor.query('localOwners');
    if (owners.length != 1) throw StateError('Local workspace is unavailable.');
    final owner = owners.single;
    final rows = await executor.query(
      Loan.tableName,
      where: '${LoanFields.id} = ? AND ownerId = ?',
      whereArgs: [id, owner['id']],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Loan no longer exists.');
    if (rows.single['lenderPartyId'] != owner['selfPartyId']) {
      throw StateError('Borrower financial records are read-only.');
    }
    return Loan.fromJson(rows.single);
  }

  Future<void> delete(int id) async {
    _requireLenderWrite();
    db = await ref.read(dBProvider.future);
    final rid = await db.transaction((tx) async {
      await _readLoan(tx, id);
      await tx.delete(
        LoanChange.tableName,
        where: '${LoanChangeFields.loanId} = ?',
        whereArgs: [id],
      );
      return tx.delete(
        Loan.tableName,
        where: '${LoanFields.id} = ? AND ownerId = ?',
        whereArgs: [id, await _requiredOwnerId(tx)],
      );
    });
    if (rid > 0) {
      await updateDBTime();
      state = AsyncData(state.value!.where((loan) => loan.id != id).toList());
    }
  }

  Future<void> bulkDelete(List<int> ids) async {
    _requireLenderWrite();
    if (ids.isEmpty) return;
    if (ids.toSet().length != ids.length) {
      throw ArgumentError('Duplicate loan IDs');
    }
    db = await ref.read(dBProvider.future);
    await db.transaction((tx) async {
      final owner = await _requiredOwnerId(tx);
      for (final id in ids) {
        await _readLoan(tx, id);
        await tx.delete(
          LoanChange.tableName,
          where: '${LoanChangeFields.loanId} = ?',
          whereArgs: [id],
        );
        final deleted = await tx.delete(
          Loan.tableName,
          where: '${LoanFields.id} = ? AND ownerId = ?',
          whereArgs: [id, owner],
        );
        if (deleted != 1) throw StateError('Loan deletion failed.');
      }
    });
    await updateDBTime();
    state = AsyncData(
      state.value!.where((loan) => !ids.contains(loan.id)).toList(),
    );
  }

  Future<void> _recordChange(
    DatabaseExecutor executor,
    int loanId,
    String description,
  ) async {
    await executor.insert(
      LoanChange.tableName,
      LoanChange(
        loanId: loanId,
        description: description,
        createdAt: DateTime.now().toUtc(),
      ).toJson(),
    );
  }

  String _describeChanges(Loan before, Loan after) {
    final changes = <String>[];
    void record(String field, String oldValue, String newValue) {
      if (oldValue != newValue) {
        changes.add(
          '$field: ${_displayValue(oldValue)} → ${_displayValue(newValue)}',
        );
      }
    }

    record('Borrower', before.depositorName, after.depositorName);
    record('Phone number', before.phoneNumber, after.phoneNumber);
    record('Relative name', before.relativeName, after.relativeName);
    record('Address', before.address, after.address);
    record(
      'Loan amount',
      before.loanAmount.toStringAsFixed(2),
      after.loanAmount.toStringAsFixed(2),
    );
    record(
      'Mortgage weight',
      '${before.weight.toStringAsFixed(2)} ${before.weightUnit}',
      '${after.weight.toStringAsFixed(2)} ${after.weightUnit}',
    );
    record(
      'Interest rate',
      '${before.interestRate}%',
      '${after.interestRate}%',
    );
    record(
      'Interest type',
      InterestType.values[before.interestType].name,
      InterestType.values[after.interestType].name,
    );
    if (before.interestFrequency != after.interestFrequency) {
      record(
        'Interest frequency',
        InterestFrequency.values[before.interestFrequency].name,
        InterestFrequency.values[after.interestFrequency].name,
      );
    }
    record(
      'Mortgage term',
      '${before.mortgageTermYears} years',
      '${after.mortgageTermYears} years',
    );
    record(
      'Lock-in period',
      '${before.lockInDays} days',
      '${after.lockInDays} days',
    );
    record(
      'Early redemption charge',
      before.earlyRedemptionCharge.toStringAsFixed(2),
      after.earlyRedemptionCharge.toStringAsFixed(2),
    );
    record('Notes', before.additionalDetails, after.additionalDetails);
    record(
      'Terms and conditions',
      before.termsAndConditions,
      after.termsAndConditions,
    );
    if (before.familyRelationId != after.familyRelationId) {
      record(
        'Family relation ID',
        before.familyRelationId.toString(),
        after.familyRelationId.toString(),
      );
    }
    if (before.mortgageMaterialId != after.mortgageMaterialId) {
      record(
        'Mortgage material ID',
        before.mortgageMaterialId.toString(),
        after.mortgageMaterialId.toString(),
      );
    }
    if (before.dateFinished == null && after.dateFinished != null) {
      record('Status', 'Active', 'Completed');
      record('Item received by', before.completedBy, after.completedBy);
      record(
        'Amount received',
        before.settlementAmount?.toStringAsFixed(2) ?? '',
        after.settlementAmount?.toStringAsFixed(2) ?? '',
      );
      record(
        'Reference number',
        before.completionReference,
        after.completionReference,
      );
      record('Settlement notes', before.completionNotes, after.completionNotes);
    }
    if (changes.isEmpty) return 'Loan record updated';
    return 'Updated\n${changes.join('\n')}';
  }

  String _displayValue(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? '(empty)' : normalized;
  }
}

Future<void> updateDBTime() async {
  AppSettings.putDbUpdateTime(DateTime.now().millisecondsSinceEpoch);
  await AppSettings.flush();
}
