import 'dart:async';
// import 'dart:collection';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:loanx/model/loan.dart';
import 'package:path_provider/path_provider.dart';
import 'durable_file_system.dart';
import 'flatdb_generated.dart' as db;

// import 'dart:isolate';

class FastDbRecoveryException implements Exception {
  const FastDbRecoveryException(this.message);

  final String message;

  @override
  String toString() => 'FastDbRecoveryException: $message';
}

class FastDB {
  static final FastDB _instance = FastDB._internal();
  factory FastDB() => _instance;
  FastDB._internal();
  static late encrypt.Key _key;
  static late encrypt.IV _iv;
  static const _ssKey = 'ss';
  static const _svKey = 'sv';
  static const _keyLength = 32;
  static const _ivLength = 16;
  static const _authenticatedFileMagic = <int>[0x4c, 0x58, 0x46, 0x44, 0x32];
  static const _authenticatedIvLength = 16;

  static late db.FlatDbObjectBuilder flatDbBuilder;

  static late File _file;
  static late File _temporaryFile;
  static late File _backupFile;
  static late File _olderBackupFile;
  static late encrypt.Encrypter _encrypter;
  static late encrypt.Encrypter _authenticatedEncrypter;
  static Future<void> _flushQueue = Future.value();

  static Future<void> init() async {
    final directory = await getApplicationSupportDirectory();
    _initializeFiles(directory);
    const secureStorage = FlutterSecureStorage();
    await _initializeKeys(secureStorage);
    _initializeEncrypters();
    await _loadWithRecovery();
  }

  static void _initializeEncrypters() {
    _encrypter = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.cbc),
    );
    _authenticatedEncrypter = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.gcm),
    );
  }

  static void _initializeFiles(Directory directory) {
    _file = File('${directory.path}/fastDB.bin');
    _temporaryFile = File('${_file.path}.tmp');
    _backupFile = File('${_file.path}.bak');
    _olderBackupFile = File('${_file.path}.bak2');
  }

  @visibleForTesting
  static Future<void> initForTesting(
    Directory directory, {
    int keyOffset = 0,
  }) async {
    _key = encrypt.Key(
      Uint8List.fromList(List<int>.generate(32, (i) => i + keyOffset)),
    );
    _iv = encrypt.IV(Uint8List.fromList(List<int>.generate(16, (i) => i)));
    _initializeEncrypters();
    _initializeFiles(directory);
    _flushQueue = Future.value();
    await _loadWithRecovery();
  }

  @visibleForTesting
  static Future<void> reloadForTesting() => _loadWithRecovery();

  @visibleForTesting
  static String get primaryFilePathForTesting => _file.path;

  @visibleForTesting
  static String get temporaryFilePathForTesting => _temporaryFile.path;

  @visibleForTesting
  static String get backupFilePathForTesting => _backupFile.path;

  @visibleForTesting
  static String get olderBackupFilePathForTesting => _olderBackupFile.path;

  static Future<void> _initializeKeys(
    FlutterSecureStorage secureStorage,
  ) async {
    final encryptedSSData = await secureStorage.read(key: _ssKey);
    final encryptedSVData = await secureStorage.read(key: _svKey);
    final hasDatabaseFiles = await _hasAnyDatabaseFile();
    if ((encryptedSSData == null || encryptedSVData == null) &&
        hasDatabaseFiles) {
      throw const FastDbRecoveryException(
        'The encryption key is missing, but existing FastDB files are present. '
        'The files were preserved; restore secure storage or a portable backup.',
      );
    }
    if (encryptedSSData == null) {
      _key = encrypt.Key.fromLength(_keyLength);
      await secureStorage.write(key: _ssKey, value: _key.base64);
    } else {
      _key = encrypt.Key.fromBase64(encryptedSSData);
    }
    if (encryptedSVData == null) {
      _iv = encrypt.IV.fromLength(_ivLength);
      await secureStorage.write(key: _svKey, value: _iv.base64);
    } else {
      _iv = encrypt.IV.fromBase64(encryptedSVData);
    }
  }

  static Future<bool> _hasAnyDatabaseFile() async {
    for (final file in [_file, _temporaryFile, _backupFile, _olderBackupFile]) {
      if (await file.exists() && await file.length() > 0) return true;
    }
    return false;
  }

  static Future<void> _loadWithRecovery() async {
    final pending = await _tryLoad(_temporaryFile);
    if (pending != null && await _promoteTemporaryFile()) {
      flatDbBuilder = pending;
      debugPrint('FastDB completed recovery of an interrupted write.');
      return;
    }

    final primary = await _tryLoad(_file);
    if (primary != null) {
      flatDbBuilder = primary;
      if (await _temporaryFile.exists()) await _temporaryFile.delete();
      return;
    }

    final recovered = await _tryLoad(_backupFile);
    if (recovered != null) {
      await _preserveCorruptPrimary();
      await _backupFile.copy(_file.path);
      flatDbBuilder = recovered;
      if (await _temporaryFile.exists()) await _temporaryFile.delete();
      debugPrint('FastDB recovered settings from ${_backupFile.path}');
      return;
    }

    final olderRecovered = await _tryLoad(_olderBackupFile);
    if (olderRecovered != null) {
      await _preserveCorruptPrimary();
      await _olderBackupFile.copy(_file.path);
      flatDbBuilder = olderRecovered;
      if (await _temporaryFile.exists()) await _temporaryFile.delete();
      debugPrint('FastDB recovered settings from ${_olderBackupFile.path}');
      return;
    }

    if (await _hasAnyDatabaseFile()) {
      throw const FastDbRecoveryException(
        'All FastDB recovery files are unreadable. They were preserved for '
        'diagnostics or recovery.',
      );
    }
    await _preserveCorruptPrimary();
    flatDbBuilder = db.FlatDbObjectBuilder();
  }

  static Future<bool> _promoteTemporaryFile() async {
    final primary = await _tryLoad(_file);
    try {
      if (primary != null) {
        await _rotatePrimaryToBackup();
      } else {
        await _preserveCorruptPrimary();
      }
      await _temporaryFile.rename(_file.path);
      await _syncDatabaseDirectory();
      return true;
    } catch (error) {
      debugPrint('Could not promote recovered FastDB write: $error');
      if (!await _file.exists() && await _backupFile.exists()) {
        await _backupFile.copy(_file.path);
      }
      return false;
    }
  }

  static Future<db.FlatDbObjectBuilder?> _tryLoad(File source) async {
    if (!await source.exists()) return null;
    try {
      final encoded = await source.readAsBytes();
      if (encoded.isEmpty) return null;
      return _decode(encoded);
    } catch (error) {
      debugPrint('Could not read FastDB settings from ${source.path}: $error');
      return null;
    }
  }

  static db.FlatDbObjectBuilder _decode(List<int> encoded) {
    if (_hasAuthenticatedHeader(encoded)) {
      final minimumLength =
          _authenticatedFileMagic.length + _authenticatedIvLength + 1;
      if (encoded.length < minimumLength) {
        throw const FormatException('Authenticated FastDB file is truncated.');
      }
      final ivStart = _authenticatedFileMagic.length;
      final encryptedStart = ivStart + _authenticatedIvLength;
      final fileIv = encrypt.IV(
        Uint8List.fromList(encoded.sublist(ivStart, encryptedStart)),
      );
      final compressed = _authenticatedEncrypter.decryptBytes(
        encrypt.Encrypted(Uint8List.fromList(encoded.sublist(encryptedStart))),
        iv: fileIv,
        associatedData: Uint8List.fromList(_authenticatedFileMagic),
      );
      return _builderFromFlatDb(db.FlatDb(Inflate(compressed).getBytes()));
    }

    // Compatibility with settings written before authenticated files were
    // introduced. A successful future flush migrates them automatically.
    final encryptedBytes = Inflate(encoded).getBytes();
    final decrypted = _encrypter.decryptBytes(
      encrypt.Encrypted(Uint8List.fromList(encryptedBytes)),
      iv: _iv,
    );
    return _builderFromFlatDb(db.FlatDb(decrypted));
  }

  static bool _hasAuthenticatedHeader(List<int> encoded) {
    if (encoded.length < _authenticatedFileMagic.length) return false;
    for (var index = 0; index < _authenticatedFileMagic.length; index++) {
      if (encoded[index] != _authenticatedFileMagic[index]) return false;
    }
    return true;
  }

  static List<int> _encodeAuthenticated(List<int> originalBytes) {
    final fileIv = encrypt.IV.fromSecureRandom(_authenticatedIvLength);
    final compressed = Deflate(originalBytes).getBytes();
    final encrypted = _authenticatedEncrypter.encryptBytes(
      compressed,
      iv: fileIv,
      associatedData: Uint8List.fromList(_authenticatedFileMagic),
    );
    return [..._authenticatedFileMagic, ...fileIv.bytes, ...encrypted.bytes];
  }

  static Future<void> _preserveCorruptPrimary() async {
    if (!await _file.exists() || await _file.length() == 0) return;
    final corruptFile = File(
      '${_file.path}.corrupt.${DateTime.now().millisecondsSinceEpoch}',
    );
    try {
      await _file.rename(corruptFile.path);
    } catch (error) {
      debugPrint('Could not preserve corrupt FastDB file: $error');
      await _file.delete();
    }
  }

  static db.FlatDbObjectBuilder _builderFromFlatDb(db.FlatDb flatDb) {
    return db.FlatDbObjectBuilder(
      isTableCreated: flatDb.isTableCreated,
      themeMode: flatDb.themeMode,
      appColor: flatDb.appColor,
      holdingPeriod: flatDb.holdingPeriod,
      interestRate: flatDb.interestRate,
      interestType: flatDb.interestType,
      interestFrequency: flatDb.interestFrequency,
      defaultLockInDays: flatDb.defaultLockInDays,
      defaultEarlyRedemptionCharge: flatDb.defaultEarlyRedemptionCharge,
      defaultTermsAndConditions: flatDb.defaultTermsAndConditions,
      defaultUpiId: flatDb.defaultUpiId,
      scheduledBackUpTimeHour: flatDb.scheduledBackUpTimeHour,
      scheduledBackUpTimeMinute: flatDb.scheduledBackUpTimeMinute,
      driveAccessToken: flatDb.driveAccessToken,
      driveAccessTokenExpires: flatDb.driveAccessTokenExpires,
      driveFileId: flatDb.driveFileId,
      driveUser: flatDb.driveUser,
      isBackUpRegistered: flatDb.isBackUpRegistered,
      dbUpdateTime: flatDb.dbUpdateTime,
      displayName: flatDb.displayName,
      email: flatDb.email,
      photourl: flatDb.photourl,
      backupTaskId: flatDb.backupTaskId,
      secure: flatDb.secure,
      photo: flatDb.photo,
    );
  }

  /// Returns a portable version of the FlatBuffer settings for a backup.
  ///
  /// The on-device file is AES-encrypted with a device-specific key, so it
  /// cannot be restored directly on another device. Drive credentials and
  /// Workmanager IDs are local session state and are not exported.
  static List<int> exportBackupSettings() {
    final settings = db.FlatDbObjectBuilder(
      isTableCreated: flatDbBuilder.isTableCreated,
      themeMode: flatDbBuilder.themeMode,
      appColor: flatDbBuilder.appColor,
      holdingPeriod: flatDbBuilder.holdingPeriod,
      interestRate: flatDbBuilder.interestRate,
      interestType: flatDbBuilder.interestType,
      interestFrequency: flatDbBuilder.interestFrequency,
      defaultLockInDays: flatDbBuilder.defaultLockInDays,
      defaultEarlyRedemptionCharge: flatDbBuilder.defaultEarlyRedemptionCharge,
      defaultTermsAndConditions: flatDbBuilder.defaultTermsAndConditions,
      defaultUpiId: flatDbBuilder.defaultUpiId,
      scheduledBackUpTimeHour: flatDbBuilder.scheduledBackUpTimeHour,
      scheduledBackUpTimeMinute: flatDbBuilder.scheduledBackUpTimeMinute,
      dbUpdateTime: flatDbBuilder.dbUpdateTime,
      secure: flatDbBuilder.secure,
      displayName: flatDbBuilder.displayName,
      email: flatDbBuilder.email,
      photourl: flatDbBuilder.photourl,
      photo: flatDbBuilder.photo,
    );
    return settings.toBytes();
  }

  /// Saves portable backup settings using this device's encryption key.
  static Future<void> restoreBackupSettings(List<int> bytes) async {
    final restored = _builderFromFlatDb(db.FlatDb(bytes));

    // These are established locally before a Drive restore and must not be
    // overwritten with stale credentials or task IDs from another device.
    restored.driveAccessToken = flatDbBuilder.driveAccessToken;
    restored.driveAccessTokenExpires = flatDbBuilder.driveAccessTokenExpires;
    restored.driveFileId = flatDbBuilder.driveFileId;
    restored.driveUser = flatDbBuilder.driveUser;
    restored.isBackUpRegistered = flatDbBuilder.isBackUpRegistered;
    restored.backupTaskId = flatDbBuilder.backupTaskId;
    restored.displayName = flatDbBuilder.displayName;
    restored.email = flatDbBuilder.email;
    restored.photourl = flatDbBuilder.photourl;
    restored.photo = flatDbBuilder.photo;
    flatDbBuilder = restored;
    await flush();
  }

  static String getAppColor() {
    return flatDbBuilder.appColor ?? "fea0d1a0";
  }

  static bool getIsTableCreated() {
    return flatDbBuilder.isTableCreated ?? false;
  }

  static int getThemeMode() {
    return flatDbBuilder.themeMode ?? ThemeMode.system.index;
  }

  static int getHoldingPeriod() {
    return flatDbBuilder.holdingPeriod ?? 5;
  }

  static double getInterestRate() {
    return double.tryParse(flatDbBuilder.interestRate!.toStringAsFixed(2)) ??
        2.5;
  }

  static int getInterestType() {
    return flatDbBuilder.interestType ?? InterestType.compound.index;
  }

  static int getInterestFrequency() {
    return flatDbBuilder.interestFrequency ?? InterestFrequency.monthly.index;
  }

  static int getDefaultLockInDays() {
    return flatDbBuilder.defaultLockInDays ?? 0;
  }

  static double getDefaultEarlyRedemptionCharge() {
    return flatDbBuilder.defaultEarlyRedemptionCharge ?? 0;
  }

  static String getDefaultTermsAndConditions() {
    return flatDbBuilder.defaultTermsAndConditions ?? '';
  }

  static String getDefaultUpiId() {
    return flatDbBuilder.defaultUpiId ?? '';
  }

  static int getScheduledBackUpTimeHour() {
    return flatDbBuilder.scheduledBackUpTimeHour ?? 2;
  }

  static int getScheduledBackUpTimeMinute() {
    return flatDbBuilder.scheduledBackUpTimeMinute ?? 0;
  }

  static String getDriveAccessToken() {
    return flatDbBuilder.driveAccessToken ?? "";
  }

  static int getDriveAccessTokenExpires() {
    return flatDbBuilder.driveAccessTokenExpires ?? 0;
  }

  static String getDriveFileId() {
    return flatDbBuilder.driveFileId ?? "";
  }

  static int getDriveUser() {
    return flatDbBuilder.driveUser ?? 0;
  }

  static bool getIsBackUpRegistered() {
    return flatDbBuilder.isBackUpRegistered ?? false;
  }

  static int getDbUpdateTime() {
    return flatDbBuilder.dbUpdateTime ?? 0;
  }

  static String getDisplayName() {
    return flatDbBuilder.displayName ?? "";
  }

  static String getEmail() {
    return flatDbBuilder.email ?? "";
  }

  static String getPhotourl() {
    return flatDbBuilder.photourl ?? "";
  }

  static String getBackupTaskId() {
    return flatDbBuilder.backupTaskId ?? "";
  }

  static bool getSecure() {
    return flatDbBuilder.secure ?? false;
  }

  static List<int> getPhoto() {
    return flatDbBuilder.photo ?? [];
  }

  static void putThemeMode(int themeMode) {
    flatDbBuilder.themeMode = themeMode;
  }

  static void putIsTableCreated(bool isTableCreated) {
    flatDbBuilder.isTableCreated = isTableCreated;
  }

  static void putAppColor(String appColor) {
    flatDbBuilder.appColor = appColor;
  }

  static void putHoldingPeriod(int holdingPeriod) {
    flatDbBuilder.holdingPeriod = holdingPeriod;
  }

  static void putInterestRate(double interestRate) {
    flatDbBuilder.interestRate = interestRate;
  }

  static void putInterestType(int interestType) {
    flatDbBuilder.interestType = interestType;
  }

  static void putInterestFrequency(int interestFrequency) {
    flatDbBuilder.interestFrequency = interestFrequency;
  }

  static void putDefaultLockInDays(int days) {
    flatDbBuilder.defaultLockInDays = days;
  }

  static void putDefaultEarlyRedemptionCharge(double charge) {
    flatDbBuilder.defaultEarlyRedemptionCharge = charge;
  }

  static void putDefaultTermsAndConditions(String terms) {
    flatDbBuilder.defaultTermsAndConditions = terms;
  }

  static void putDefaultUpiId(String upiId) {
    flatDbBuilder.defaultUpiId = upiId;
  }

  static void putScheduledBackUpTimeHour(int scheduledBackUpTimeHour) {
    flatDbBuilder.scheduledBackUpTimeHour = scheduledBackUpTimeHour;
  }

  static void putScheduledBackUpTimeMinute(int scheduledBackUpTimeMinute) {
    flatDbBuilder.scheduledBackUpTimeMinute = scheduledBackUpTimeMinute;
  }

  static void putDriveAccessToken(String driveAccessToken) {
    flatDbBuilder.driveAccessToken = driveAccessToken;
  }

  static void putDriveAccessTokenExpires(int driveAccessTokenExpires) {
    flatDbBuilder.driveAccessTokenExpires = driveAccessTokenExpires;
  }

  static void putDriveFileId(String driveFileId) {
    flatDbBuilder.driveFileId = driveFileId;
  }

  static void putDriveUser(int driveUser) {
    flatDbBuilder.driveUser = driveUser;
  }

  static void putIsBackUpRegistered(bool isBackUpRegistered) {
    flatDbBuilder.isBackUpRegistered = isBackUpRegistered;
  }

  static void putDbUpdateTime(int dbUpdateTime) {
    flatDbBuilder.dbUpdateTime = dbUpdateTime;
  }

  static void putDisplayName(String displayName) {
    flatDbBuilder.displayName = displayName;
  }

  static void putEmail(String email) {
    flatDbBuilder.email = email;
  }

  static void putPhotourl(String photourl) {
    flatDbBuilder.photourl = photourl;
  }

  static void putBackupTaskId(String backupTaskId) {
    flatDbBuilder.backupTaskId = backupTaskId;
  }

  static Future putSecure(bool secure) async {
    flatDbBuilder.secure = secure;
    await flush();
  }

  static Future putPhoto(List<int> photo) async {
    flatDbBuilder.photo = photo;
    await flush();
  }

  static Future<void> flush() {
    final originalBytes = flatDbBuilder.toBytes();
    if (originalBytes.isEmpty) return Future.value();

    // Capture a complete snapshot now so later in-memory changes cannot alter
    // an already queued write.
    final encoded = _encodeAuthenticated(originalBytes);
    final operation = _flushQueue.then((_) => _writeAtomically(encoded));

    // Keep the queue usable after an individual caller observes a write error.
    _flushQueue = operation.catchError((Object error, StackTrace stackTrace) {
      debugPrint('FastDB write failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    });
    return operation;
  }

  static Future<void> _writeAtomically(List<int> encoded) async {
    if (await _temporaryFile.exists()) await _temporaryFile.delete();
    await _temporaryFile.writeAsBytes(encoded, flush: true);

    // Verify that encryption, compression, and FlatBuffer decoding all work
    // before replacing the last known-good file.
    _decode(await _temporaryFile.readAsBytes());

    await _rotatePrimaryToBackup();

    try {
      await _temporaryFile.rename(_file.path);
      await _syncDatabaseDirectory();
    } catch (_) {
      if (!await _file.exists() && await _backupFile.exists()) {
        await _backupFile.copy(_file.path);
      }
      rethrow;
    }
  }

  static Future<void> _rotatePrimaryToBackup() async {
    // Keep two known-good generations. Copying with flush ensures bak2 is
    // durable before bak is replaced, so a failure during rotation still
    // leaves at least one prior snapshot.
    if (await _backupFile.exists()) {
      final olderTemporary = File('${_olderBackupFile.path}.tmp');
      if (await olderTemporary.exists()) await olderTemporary.delete();
      await olderTemporary.writeAsBytes(
        await _backupFile.readAsBytes(),
        flush: true,
      );
      _decode(await olderTemporary.readAsBytes());
      if (await _olderBackupFile.exists()) await _olderBackupFile.delete();
      await olderTemporary.rename(_olderBackupFile.path);
      await _syncDatabaseDirectory();
    }
    if (await _backupFile.exists()) await _backupFile.delete();
    if (await _file.exists()) await _file.rename(_backupFile.path);
    await _syncDatabaseDirectory();
  }

  static Future<void> _syncDatabaseDirectory() =>
      syncDirectoryMetadata(_file.parent);

  static Future<void> clearAll() async {
    await _flushQueue;
    for (final file in [
      _file,
      _temporaryFile,
      _backupFile,
      _olderBackupFile,
      File('${_olderBackupFile.path}.tmp'),
    ]) {
      if (await file.exists()) await file.delete();
    }
  }
}

// class FileWriter {
//   final String path;
//   final Queue<Function> _writeQueue = Queue<Function>();
//   bool _isWriting = false;

//   FileWriter(this.path);

//   Future<void> write(String content) async {
//     final Completer<void> completer = Completer<void>();

//     _writeQueue.add(() async {
//       final file = File(path);
//       await file.writeAsString(content, mode: FileMode.write);
//       completer.complete();
//     });

//     _processQueue();
//     return completer.future;
//   }

//   Future<String> read() async {
//     final Completer<String> completer = Completer<String>();

//     _writeQueue.add(() async {
//       final file = File(path);
//       final content = await file.readAsString();
//       completer.complete(content);
//     });

//     _processQueue();
//     return completer.future;
//   }

//   void _processQueue() async {
//     if (_isWriting || _writeQueue.isEmpty) return;

//     _isWriting = true;
//     final writeOperation = _writeQueue.removeFirst();
//     await writeOperation();
//     _isWriting = false;

//     _processQueue(); // Check the queue for more operations
//   }
// }

// void main() async {
//   final encryptionReceivePort = ReceivePort();
//   await Isolate.spawn(encryptData, encryptionReceivePort.sendPort);

//   final encryptionSendPort = await encryptionReceivePort.first as SendPort;
//   final encryptionResponsePort = ReceivePort();

//   // Data to encrypt
//   final message = {'data': 'Hello, World!', 'responsePort': encryptionResponsePort.sendPort};
//   encryptionSendPort.send(message);

//   final encryptedData = await encryptionResponsePort.first as String;
//   print('Encrypted Data: $encryptedData');

//   final fileWriter = FileWriter('example_encrypted.txt');
//   await fileWriter.write(encryptedData);

//   print('File write result: File written successfully.');
// }

// void encryptData(SendPort sendPort) {
//   final port = ReceivePort();
//   sendPort.send(port.sendPort);

//   port.listen((message) {
//     final data = message['data'] as String;
//     final responsePort = message['responsePort'] as SendPort;

//     // Encrypt the data (using a simple example here for demonstration)
//     final key = encrypt.Key.fromUtf8('my 32 length key................');
//     final iv = encrypt.IV.fromLength(16);
//     final encrypter = encrypt.Encrypter(encrypt.AES(key));

//     final encrypted = encrypter.encrypt(data, iv: iv);
//     responsePort.send(encrypted.base64);
//   });
// }

// class FileWriter {
//   final String path;
//   final Queue<Function> _writeQueue = Queue<Function>();
//   bool _isWriting = false;

//   FileWriter(this.path);

//   Future<void> write(String content) async {
//     final Completer<void> completer = Completer<void>();

//     _writeQueue.add(() async {
//       final file = File(path);
//       await file.writeAsString(content, mode: FileMode.append);
//       completer.complete();
//     });

//     _processQueue();
//     return completer.future;
//   }

//   void _processQueue() async {
//     if (_isWriting || _writeQueue.isEmpty) return;

//     _isWriting = true;
//     final writeOperation = _writeQueue.removeFirst();
//     await writeOperation();
//     _isWriting = false;

//     _processQueue(); // Check the queue for more operations
//   }
// }
