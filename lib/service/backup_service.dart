import 'dart:io';
// import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:loanx/db/fastdb.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/service/database_helper.dart';
// import 'package:loanx/widget/snackbar.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:workmanager/workmanager.dart';

GoogleSignIn _googleSignIn() => GoogleSignIn.instance;

const _iosGoogleClientId =
    '971184206112-he3jrlalluq0hd1dlv14deau3s3d52ug.apps.googleusercontent.com';
const _androidGoogleServerClientId =
    '971184206112-suu0rjqkd51htgg0l1kf0f73h4pn6uc5.apps.googleusercontent.com';

Future<void> initializeGoogleSignIn() => GoogleSignIn.instance.initialize(
  clientId: Platform.isIOS ? _iosGoogleClientId : null,
  serverClientId: Platform.isAndroid ? _androidGoogleServerClientId : null,
);

class BackupService {
  static const _databaseEntryName = 'loanx.db';
  static const _settingsEntryName = 'fastdb-settings.flatbuffer';
  static const _backupExtension = '.loanxbackup';
  static String? _lastError;

  /// A detailed description of the latest Google sign-in or Drive failure.
  static String get lastError =>
      _lastError ?? 'Google Drive did not return a result.';

  static void _recordError(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    final details = error.toString().trim();
    _lastError = '$operation failed.\n$details';
    // Do not log authorization headers or access tokens.
    debugPrint('$_lastError\n$stackTrace');
  }

  static bool isUserCancelledGoogleSignIn(Object error) {
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final message = error.message?.toLowerCase() ?? '';
      if (code.contains('cancel') || message.contains('cancel')) {
        return true;
      }
    }
    final text = error.toString().toLowerCase();
    return text.contains('cancelled') || text.contains('canceled');
  }

  static String userFacingGoogleSignInError(Object error) {
    if (isUserCancelledGoogleSignIn(error)) {
      return 'No Google account was selected. Please choose an account to continue.';
    }
    final fallback = 'Google account connection failed. Please try again.';
    if (kDebugMode) {
      return '$fallback\n${error.toString()}';
    }
    return fallback;
  }

  static Future<bool> performBackup() async {
    _lastError = null;
    try {
      final driveApi = await getDriveApi();
      if (driveApi != null) {
        return await createFileOnDrive(driveApi);
      }
      return false;
    } catch (e, stackTrace) {
      _recordError('Google Drive backup', e, stackTrace);
      FastDB.putDriveAccessToken("");
      await FastDB.flush();
      return false;
    }
  }

  static Future<bool> createFileOnDrive(drive.DriveApi driveApi) async {
    final driveFile = drive.File();
    driveFile.name =
        "backup-${DateTime.now().toIso8601String()}$_backupExtension";
    driveFile.parents = ["appDataFolder"];
    File file = File(join(await getDatabasesPath(), 'loanx.db'));
    debugPrint(file.path);
    if (file.existsSync()) {
      await FastDB.flush();
      // Ensure WAL-backed writes have reached the database file before it is
      // read into the archive.
      final database = await DatabaseHelper.instance.database;
      await database.rawQuery('PRAGMA wal_checkpoint(FULL)');
      final archive = Archive()
        ..add(
          ArchiveFile(
            _databaseEntryName,
            file.lengthSync(),
            await file.readAsBytes(),
          ),
        )
        ..add(
          ArchiveFile.bytes(_settingsEntryName, FastDB.exportBackupSettings()),
        );
      final backupBytes = ZipEncoder().encodeBytes(archive);
      drive.File result = await driveApi.files.create(
        driveFile,
        uploadMedia: drive.Media(Stream.value(backupBytes), backupBytes.length),
      );
      debugPrint(result.id);
      debugPrint(result.name);
      debugPrint(result.mimeType);
      if (result.id != null) {
        if (FastDB.getDriveFileId().isNotEmpty) {
          try {
            await driveApi.files.delete(FastDB.getDriveFileId());
          } catch (e) {
            // The upload has already succeeded. Keep the new backup even if
            // an old, stale file ID can no longer be deleted.
            debugPrint('Could not delete previous Google Drive backup: $e');
          }
        }
        FastDB.putDriveFileId(result.id!);
        await FastDB.flush();
        return true;
      }
    }
    return false;
  }

  /// Checks for a LoanX backup without changing data on this device.
  static Future<bool> hasBackupOnDrive({GoogleSignInAccount? account}) async {
    _lastError = null;
    try {
      final driveApi = await getDriveApi(account: account);
      if (driveApi == null) return false;
      final files = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name contains '$_backupExtension' and trashed = false",
        pageSize: 1,
      );
      return files.files?.any((file) => file.id != null) ?? false;
    } catch (e, stackTrace) {
      _recordError('Google Drive backup check', e, stackTrace);
      return false;
    }
  }

  // static Future<bool> downloadFileToDevice() async {
  //   BackgroundIsolateBinaryMessenger.ensureInitialized();
  //  return Isolate.run<bool>(downloadDB);
  // }

  static Future<bool> downloadFileToDevice({
    GoogleSignInAccount? account,
  }) async {
    _lastError = null;
    try {
      bool isDownloaded = false;
      final driveApi = await getDriveApi(account: account);
      final saveFile = File(join(await getDatabasesPath(), 'loanx.db'));
      if (driveApi != null) {
        final fileList = (await driveApi.files.list(
          spaces: 'appDataFolder',
          q: "name contains '$_backupExtension' and trashed = false",
          orderBy: 'modifiedTime desc',
        )).files;
        if (fileList != null &&
            fileList.isNotEmpty &&
            fileList.first.id != null) {
          final latestBackup = fileList.first;
          final driveBackupDate = _backupDate(latestBackup.name);
          final shouldRestore =
              FastDB.getDbUpdateTime() == 0 ||
              (driveBackupDate != null &&
                  DateTime.fromMillisecondsSinceEpoch(
                    FastDB.getDbUpdateTime(),
                  ).isBefore(driveBackupDate));
          if (shouldRestore) {
            final media =
                (await driveApi.files.get(
                      latestBackup.id!,
                      downloadOptions: drive.DownloadOptions.fullMedia,
                    ))
                    as drive.Media?;
            if (media != null) {
              isDownloaded = await _restoreBackup(
                await _mediaBytes(media),
                latestBackup.name,
                saveFile,
              );
              if (isDownloaded) {
                // Record the applied backup version so tapping restore again
                // does not repeatedly apply the same Drive file.
                FastDB.putDbUpdateTime(
                  (driveBackupDate ?? DateTime.now()).millisecondsSinceEpoch,
                );
                await FastDB.flush();
              }
            }
          } else {
            _lastError = 'This device already has the latest backup.';
          }
          if (isDownloaded && fileList.length > 1) {
            for (final file in fileList.sublist(1)) {
              if (file.id != null) {
                await driveApi.files.delete(file.id!);
              }
            }
          }
        } else {
          _lastError = 'No LoanX backup is available in Google Drive.';
        }
      }
      return isDownloaded;
    } catch (e, stackTrace) {
      _recordError('Google Drive restore', e, stackTrace);
      return false;
    }
  }

  static DateTime? _backupDate(String? fileName) {
    if (fileName == null) return null;
    return DateTime.tryParse(
      fileName
          .replaceFirst('backup-', '')
          .replaceAll(_backupExtension, '')
          .replaceAll('.db', ''),
    );
  }

  static Future<List<int>> _mediaBytes(drive.Media media) async {
    final chunks = await media.stream.toList();
    return [for (final chunk in chunks) ...chunk];
  }

  static Future<bool> _restoreBackup(
    List<int> bytes,
    String? fileName,
    File saveFile,
  ) async {
    if (fileName?.endsWith(_backupExtension) ?? false) {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final databaseFile = archive.find(_databaseEntryName);
      final settingsFile = archive.find(_settingsEntryName);
      if (databaseFile == null || settingsFile == null) {
        throw const FormatException('The backup is missing required files.');
      }
      await _restoreDatabase(databaseFile.content, saveFile);
      await FastDB.restoreBackupSettings(settingsFile.content);
      return true;
    }

    // Backups created by older app versions contained only loanx.db.
    await _restoreDatabase(bytes, saveFile);
    return true;
  }

  static Future<void> _restoreDatabase(
    List<int> databaseBytes,
    File saveFile,
  ) async {
    final tempFile = File(join(dirname(saveFile.path), 'loanx_temp.db'));
    try {
      await tempFile.writeAsBytes(databaseBytes, flush: true);
      final tempDb = await openDatabase(
        tempFile.path,
        readOnly: true,
        singleInstance: true,
        version: 1,
        password: 'yourhgjgujjhjhjhsecure_passwordhfjffffhgf',
      );
      try {
        await DatabaseHelper.restoreTables(tempDb);
      } finally {
        await tempDb.close();
      }
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  static Future<drive.DriveApi?> getDriveApi({
    GoogleSignInAccount? account,
  }) async {
    final googleSignIn = _googleSignIn();
    if (account == null) {
      if (FastDB.getDriveAccessToken().isNotEmpty) {
        // Access tokens are short-lived. Re-obtain one from the account on
        // each Drive operation instead of trusting a persisted expiry time.
        account = await googleSignIn.attemptLightweightAuthentication();
      } else {
        account = await googleSignIn.authenticate(
          scopeHint: [drive.DriveApi.driveAppdataScope],
        );
      }
    }

    if (account != null) {
      await saveData(account);
      final authHeaders = {
        "Authorization": "Bearer ${FastDB.getDriveAccessToken()}",
        "X-Goog-AuthUser": "${FastDB.getDriveUser()}",
      };
      final authenticateClient = GoogleAuthClient(authHeaders);
      return drive.DriveApi(authenticateClient);
    }
    _lastError = FastDB.getDriveAccessToken().isEmpty
        ? 'Google Sign-In was cancelled or did not return an account.'
        : 'Google Sign-In could not restore the saved account. '
              'Check the Android OAuth package name and SHA-1 fingerprint, '
              'then choose the Google account again.';
    debugPrint(_lastError);
    return null;
  }

  static Future<GoogleSignInClientAuthorization> saveData(
    GoogleSignInAccount account,
  ) async {
    FastDB.putDisplayName(account.displayName ?? "");
    FastDB.putPhotourl(account.photoUrl ?? "");
    if (account.photoUrl != null) {
      http.get(Uri.parse(account.photoUrl!)).then((value) {
        if (value.statusCode == 200) {
          final bytes = value.bodyBytes;
          FastDB.putPhoto(bytes);
        }
      });
    }
    FastDB.putEmail(account.email);

    final authorization = await account.authorizationClient.authorizeScopes([
      drive.DriveApi.driveAppdataScope,
    ]);

    // The plugin refreshes its access token through the signed-in account.
    // Do not store a made-up expiry time; it caused every token to appear
    // expired immediately.
    FastDB.putDriveAccessTokenExpires(0);
    FastDB.putDriveAccessToken(authorization.accessToken);

    final headers = await account.authorizationClient.authorizationHeaders([
      drive.DriveApi.driveAppdataScope,
    ], promptIfNecessary: false);
    if (headers?["X-Goog-AuthUser"] != null) {
      FastDB.putDriveUser(int.tryParse(headers!["X-Goog-AuthUser"] ?? "") ?? 0);
    }
    await FastDB.flush();
    return authorization;
  }

  static Future<void> removeData() async {
    FastDB.putDisplayName("");
    FastDB.putPhotourl("");
    FastDB.putEmail("");
    FastDB.putDriveAccessTokenExpires(0);
    FastDB.putDriveAccessToken("");
    FastDB.putDriveUser(0);
    FastDB.putDriveFileId("");
    FastDB.putIsBackUpRegistered(false);
    await Workmanager().cancelByUniqueName(FastDB.getBackupTaskId());
    FastDB.putBackupTaskId("");
    await FastDB.flush();
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _client.send(request..headers.addAll(_headers));
    debugPrint(
      'Google Drive API: ${request.method} ${request.url} '
      '→ ${response.statusCode} ${response.reasonPhrase ?? ''}',
    );
    return response;
  }
}

Future<void> registerBackUp() async {
  if (FastDB.getBackupTaskId().isNotEmpty) {
    await Workmanager().cancelByUniqueName(FastDB.getBackupTaskId());
  }
  final now = DateTime.now();
  var scheduledTime = DateTime(
    now.year,
    now.month,
    now.day,
    FastDB.getScheduledBackUpTimeHour(),
    FastDB.getScheduledBackUpTimeMinute(),
  );
  if (!scheduledTime.isAfter(now)) {
    scheduledTime = scheduledTime.add(const Duration(days: 1));
  }
  final uniqueID = "${DateTime.now().millisecondsSinceEpoch}_dailyBackup_loanx";
  await Workmanager().registerPeriodicTask(
    uniqueID,
    dailyBackUpUpload,
    initialDelay: scheduledTime.difference(now),
    frequency: Duration(hours: 24),
    constraints: Constraints(networkType: NetworkType.connected),
  );
  FastDB.putBackupTaskId(uniqueID);
  await FastDB.flush();
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == dailyBackUpUpload) {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeGoogleSignIn();
      await FastDB.init();
      return await BackupService.performBackup();
    }
    // if(task == dailyBackUpDownload ){
    //   await BackupService.downloadFileToDevice();
    //   showToast("Backup Downloaded");
    // }
    return Future.value(false);
  });
}

Future<void> removeAccount() async {
  final googleSignIn = _googleSignIn();
  await googleSignIn.signOut();
  await BackupService.removeData();
}

Future<List> changeAccount(BuildContext context) async {
  try {
    final googleSignIn = _googleSignIn();
    await googleSignIn.signOut();
    final account = await googleSignIn.authenticate(
      scopeHint: [drive.DriveApi.driveAppdataScope],
    );
    final googleSignInAuthentication = await BackupService.saveData(account);
    return [googleSignInAuthentication, account];
  } catch (e, stackTrace) {
    BackupService._recordError('Google account sign-in', e, stackTrace);
    rethrow;
  }
}

// class Change{
//   final GoogleSignInAuthentication? googleSignInAuthentication;
//   final GoogleSignInAccount? account;
//   Change(this.googleSignInAuthentication,this.account);
// }
