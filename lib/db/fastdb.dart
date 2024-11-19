import 'dart:async';
// import 'dart:collection';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:mortgage/model/loan.dart';
import 'package:path_provider/path_provider.dart';
import 'flatdb_generated.dart' as db;
// import 'dart:isolate';

class FastDB {
  static final FastDB _instance = FastDB._internal();
  factory FastDB() => _instance;
  FastDB._internal();
  static late final encrypt.Key _key;
  static late final encrypt.IV _iv;
  static const _ssKey = 'ss';
  static const _svKey = 'sv';
  static const _keyLength = 32;
  static const _ivLength = 16;

  static late final db.FlatDbObjectBuilder flatDbBuilder;

  static late File _file;
  static late encrypt.Encrypter _encrypter;

  static Future<void> init() async {
    const FlutterSecureStorage secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
            encryptedSharedPreferences: true, resetOnError: true));
    await _initializeKeys(secureStorage);
    _encrypter =
        encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
    final directory = await getApplicationSupportDirectory();
    _file = File('${directory.path}/fastDB.bin');
    if (await _file.exists()) {
      await _decryptFile();
    } else {
      await _file.create(recursive: true);
      flatDbBuilder = db.FlatDbObjectBuilder();
    }
  }

  static Future<void> _initializeKeys(
      FlutterSecureStorage secureStorage) async {
    final encryptedSSData = await secureStorage.read(key: _ssKey);
    final encryptedSVData = await secureStorage.read(key: _svKey);
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

  static Future<void> _decryptFile() async {
    try {
      final bytes = Inflate(await _file.readAsBytes()).getBytes();
      if (bytes.isNotEmpty) {
        final decrypted = _encrypter.decryptBytes(
            encrypt.Encrypted(Uint8List.fromList(bytes)),
            iv: _iv);
        db.FlatDb flatDb = db.FlatDb(decrypted);
        flatDbBuilder = db.FlatDbObjectBuilder(
          isTableCreated: flatDb.isTableCreated,
          themeMode: flatDb.themeMode,
          fontSize: flatDb.fontSize,
          appColor: flatDb.appColor,
          holdingPeriod: flatDb.holdingPeriod,
          interestType: flatDb.interestType,
          compoundingFrequency: flatDb.compoundingFrequency,
          scheduledBackUpTimeHour: flatDb.scheduledBackUpTimeHour,
          scheduledBackUpTimeMinute: flatDb.scheduledBackUpTimeMinute,
          driveAccessToken: flatDb.driveAccessToken,
          driveAccessTokenExpires: flatDb.driveAccessTokenExpires,
          driveFileId: flatDb.driveFileId,
          driveUser: flatDb.driveUser,
          isBackUpRegistered: flatDb.isBackUpRegistered,
          dbUpdateTime: flatDb.dbUpdateTime,
        );
      } else {
        flatDbBuilder = db.FlatDbObjectBuilder();
      }
    } catch (e) {
      flatDbBuilder = db.FlatDbObjectBuilder();
      debugPrint(e.toString());
    }
  }

  static double getFontSize() {
    return flatDbBuilder.fontSize ?? 16.0;
  }

  static String getAppColor() {
    return flatDbBuilder.appColor ?? "D4AF37";
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

  static int getInterestType() {
    return flatDbBuilder.interestType ?? InterestType.simple.index;
  }

  static int getCompoundingFrequency() {
    return flatDbBuilder.compoundingFrequency ??
        CompoundingFrequency.yearly.index;
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

  static void putThemeMode(int themeMode) {
    flatDbBuilder.themeMode = themeMode;
  }

  static void putIsTableCreated(bool isTableCreated) {
    flatDbBuilder.isTableCreated = isTableCreated;
  }

  static void putAppColor(String appColor) {
    flatDbBuilder.appColor = appColor;
  }

  static void putFontSize(double fontSize) {
    flatDbBuilder.fontSize = fontSize;
  }

  static void putHoldingPeriod(int holdingPeriod) {
    flatDbBuilder.holdingPeriod = holdingPeriod;
  }

  static void putInterestType(int interestType) {
    flatDbBuilder.interestType = interestType;
  }

  static void putCompoundingFrequency(int compoundingFrequency) {
    flatDbBuilder.compoundingFrequency = compoundingFrequency;
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

  static Future<void> flush() async {
    final originalBytes = flatDbBuilder.toBytes();
    if (originalBytes.isNotEmpty) {
      await _file.writeAsBytes(
          Deflate(_encrypter.encryptBytes(originalBytes, iv: _iv).bytes)
              .getBytes(),
          flush: true);
    }
  }

  static Future<void> clearAll() async {
    if (await _file.exists()) {
      await _file.delete();
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
