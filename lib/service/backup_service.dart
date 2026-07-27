import 'dart:io';
// import 'dart:isolate';

import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:loanx/db/fastdb.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/service/database_helper.dart';
import 'package:loanx/widget/snackbar.dart';
// import 'package:loanx/widget/snackbar.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:workmanager/workmanager.dart';

GoogleSignIn _googleSignIn() => GoogleSignIn(
  scopes: [drive.DriveApi.driveAppdataScope],
  clientId: Platform.isIOS
      ? '971184206112-he3jrlalluq0hd1dlv14deau3s3d52ug.apps.googleusercontent.com'
      : null,
);

class BackupService {
  static Future<bool> performBackup() async {
    try {
      final driveApi = await getDriveApi();
      if (driveApi != null) {
        return await createFileOnDrive(driveApi);
      }
      return false;
    } catch (e) {
      FastDB.putDriveAccessToken("");
      await FastDB.flush();
      // Retrying here recursively never gives control back to the UI when
      // Google Drive is unavailable or the authorization has expired.
      return false;
    }
  }

  static Future<bool> createFileOnDrive(drive.DriveApi driveApi) async {
    final driveFile = drive.File();
    driveFile.name = "backup-${DateTime.now().toIso8601String()}.db";
    driveFile.parents = ["appDataFolder"];
    File file = File(join(await getDatabasesPath(), 'loanx.db'));
    debugPrint(file.path);
    if (file.existsSync()) {
      drive.File result = await driveApi.files.create(
        driveFile,
        uploadMedia: drive.Media(file.openRead(), file.lengthSync()),
      );
      debugPrint(result.id);
      debugPrint(result.name);
      debugPrint(result.mimeType);
      if (result.id != null) {
        if (FastDB.getDriveFileId().isNotEmpty) {
          await driveApi.files.delete(FastDB.getDriveFileId());
        }
        FastDB.putDriveFileId(result.id!);
        await FastDB.flush();
        return true;
      }
    }
    return false;
  }

  // static Future<bool> downloadFileToDevice() async {
  //   BackgroundIsolateBinaryMessenger.ensureInitialized();
  //  return Isolate.run<bool>(downloadDB);
  // }

  static Future<bool> downloadFileToDevice({
    GoogleSignInAccount? account,
  }) async {
    bool isDownloaded = false;
    final driveApi = await getDriveApi(account: account);
    File saveFile = File(join(await getDatabasesPath(), 'loanx.db'));
    if (driveApi != null) {
      final fileList = (await driveApi.files.list(
        spaces: 'appDataFolder',
      )).files;
      if (fileList != null &&
          fileList.isNotEmpty &&
          fileList.first.id != null) {
        if (FastDB.getDbUpdateTime() == 0) {
          drive.Media? file =
              (await driveApi.files.get(
                    fileList.first.id!,
                    downloadOptions: drive.DownloadOptions.fullMedia,
                  ))
                  as drive.Media?;
          if (file != null) {
            if (saveFile.existsSync()) {
              File tempFile = File(
                join(await getDatabasesPath(), 'loanx_temp.db'),
              );
              final bytesArray = await file.stream.toList();
              List<int> bytes = [];
              for (var arr in bytesArray) {
                bytes.addAll(arr);
              }
              await tempFile.writeAsBytes(bytes, flush: true);
              final tempDb = await openDatabase(
                tempFile.path,
                readOnly: true,
                singleInstance: true,
                version: 1,
                password: 'yourhgjgujjhjhjhsecure_passwordhfjffffhgf',
              );
              await DatabaseHelper.mergeTables(tempDb);
              await tempDb.close();
              await tempFile.delete();
            } else {
              final bytesArray = await file.stream.toList();
              List<int> bytes = [];
              for (var arr in bytesArray) {
                bytes.addAll(arr);
              }
              await saveFile.writeAsBytes(bytes, flush: true);
            }
            isDownloaded = true;
          }
          if (fileList.length > 1) {
            for (final file in fileList.sublist(1)) {
              if (file.id != null) {
                await driveApi.files.delete(file.id!);
              }
            }
          }
        } else {
          final driveBackupDate = DateTime.tryParse(
            fileList.first.name!
                .replaceAll('backup-', '')
                .replaceAll('.db', ''),
          );
          if (driveBackupDate != null) {
            final fileBackupDate = DateTime.fromMillisecondsSinceEpoch(
              FastDB.getDbUpdateTime(),
            );
            if (fileBackupDate.isBefore(driveBackupDate)) {
              drive.Media? file =
                  (await driveApi.files.get(
                        fileList.first.id!,
                        downloadOptions: drive.DownloadOptions.fullMedia,
                      ))
                      as drive.Media?;
              if (file != null) {
                final bytesArray = await file.stream.toList();
                List<int> bytes = [];
                for (var arr in bytesArray) {
                  bytes.addAll(arr);
                }
                await saveFile.writeAsBytes(bytes, flush: true);
                isDownloaded = true;
              }
              if (fileList.length > 1) {
                for (final file in fileList.sublist(1)) {
                  if (file.id != null) {
                    await driveApi.files.delete(file.id!);
                  }
                }
              }
            }
          }
        }
      }
    }
    return isDownloaded;
  }

  static Future<drive.DriveApi?> getDriveApi({
    GoogleSignInAccount? account,
  }) async {
    final googleSignIn = _googleSignIn();
    if (account == null && FastDB.getDriveAccessToken().isEmpty) {
      account = await googleSignIn.signIn();
    } else if (account == null &&
        DateTime.now().isAfter(
          DateTime.fromMillisecondsSinceEpoch(
            FastDB.getDriveAccessTokenExpires(),
          ),
        )) {
      account = await googleSignIn.signInSilently();
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
    return null;
  }

  static Future<GoogleSignInAuthentication> saveData(
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
    final GoogleSignInAuthentication googleSignInAuthentication =
        await account.authentication;
    FastDB.putDriveAccessTokenExpires(DateTime.now().millisecondsSinceEpoch);
    FastDB.putDriveAccessToken(googleSignInAuthentication.accessToken ?? "");
    final headers = await account.authHeaders;
    if (headers["X-Goog-AuthUser"] != null) {
      FastDB.putDriveUser(int.tryParse(headers["X-Goog-AuthUser"] ?? "") ?? 0);
    }
    await FastDB.flush();
    return googleSignInAuthentication;
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
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

Future<void> registerBackUp() async {
  if (FastDB.getBackupTaskId().isNotEmpty) {
    await Workmanager().cancelByUniqueName(FastDB.getBackupTaskId());
  }
  DateTime now = DateTime.now();
  final uniqueID = "${DateTime.now().millisecondsSinceEpoch}_dailyBackup_loanx";
  Workmanager().registerPeriodicTask(
    uniqueID,
    dailyBackUpUpload,
    initialDelay: now.difference(
      DateTime(
        now.year,
        now.month,
        now.day,
        FastDB.getScheduledBackUpTimeHour(),
        FastDB.getScheduledBackUpTimeMinute(),
      ),
    ),
    frequency: Duration(hours: 24),
    constraints: Constraints(networkType: NetworkType.connected),
  );
  FastDB.putBackupTaskId(uniqueID);
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == dailyBackUpUpload) {
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
  final googleSignIn = _googleSignIn();
  await googleSignIn.signOut();
  final account = await googleSignIn.signIn();
  if (account == null) return [];
  final googleSignInAuthentication = await BackupService.saveData(account);
  if (context.mounted) {
    showSnackBar(context, " Signed In, Please wait ... \n Download backup now");
  }
  // We already have a freshly-authorized account. Passing it through avoids a
  // second silent Google sign-in immediately after the account chooser closes.
  final status = await BackupService.downloadFileToDevice(
    account: account,
  ).timeout(const Duration(seconds: 60));
  if (status && context.mounted) {
    showSnackBar(context, "Data Downloaded");
  } else if (!status && context.mounted) {
    showErrorSnackBar(context, "Data Download Failed");
  }
  return [googleSignInAuthentication, account];
}

// class Change{
//   final GoogleSignInAuthentication? googleSignInAuthentication;
//   final GoogleSignInAccount? account;
//   Change(this.googleSignInAuthentication,this.account);
// }
