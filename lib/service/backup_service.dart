import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:mortgage/db/fastdb.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:workmanager/workmanager.dart';

class BackupService {
  Future<bool> performBackup() async {
    try {
      final driveApi = await getDriveApi();
      if (driveApi != null) {
        return await createFile(driveApi);
      }
      return false;
    } catch (e) {
      FastDB.putDriveAccessToken("");
      await FastDB.flush();
      return await performBackup();
    }
  }

  Future<bool> createFile(drive.DriveApi driveApi) async {
    final driveFile = drive.File();
    driveFile.name = "backup-${DateTime.now().toIso8601String()}.db";
    driveFile.parents = ["appDataFolder"];
    File file = File(join(await getDatabasesPath(), 'mortgage.db'));
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

  Future<bool> downloadFileToDevice() async {
    bool isDownloaded = false;
    final driveApi = await getDriveApi();
    File saveFile = File(join(await getDatabasesPath(), 'mortgage.db'));
    if (driveApi != null) {
      final fileList =
          (await driveApi.files.list(spaces: 'appDataFolder')).files;
      if (fileList != null &&
          fileList.isNotEmpty &&
          fileList.first.id != null) {
        if (FastDB.getDbUpdateTime() == 0) {
          drive.Media? file = (await driveApi.files.get(fileList.first.id!,
                  downloadOptions: drive.DownloadOptions.fullMedia))
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
        } else {
          final driveBackupDate = DateTime.tryParse(fileList.first.name!
              .replaceAll('backup-', '')
              .replaceAll('.db', ''));
          if (driveBackupDate != null) {
            final fileBackupDate =
                DateTime.fromMillisecondsSinceEpoch(FastDB.getDbUpdateTime());
            if (fileBackupDate.isBefore(driveBackupDate)) {
              drive.Media? file = (await driveApi.files.get(fileList.first.id!,
                      downloadOptions: drive.DownloadOptions.fullMedia))
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

  Future<drive.DriveApi?> getDriveApi() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: [drive.DriveApi.driveAppdataScope],
    );
    GoogleSignInAccount? account;
    if (FastDB.getDriveAccessToken().isEmpty) {
      account = await googleSignIn.signIn();
      if (account == null) return null;
      await saveData(account);
    } else if (DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(
        FastDB.getDriveAccessTokenExpires()))) {
      account = await googleSignIn.signInSilently();
      if (account == null) return null;
      await saveData(account);
    }
    if (account != null) {
      final GoogleSignInAuthentication googleSignInAuthentication =
          await account.authentication;
      FastDB.putDriveAccessTokenExpires(DateTime.now().millisecondsSinceEpoch);
      FastDB.putDriveAccessToken(googleSignInAuthentication.accessToken ?? "");
      final headers = await account.authHeaders;
      if (headers["X-Goog-AuthUser"] != null) {
        FastDB.putDriveUser(
            int.tryParse(headers["X-Goog-AuthUser"] ?? "") ?? 0);
      }
      await FastDB.flush();

      final authHeaders = {
        "Authorization": "Bearer ${FastDB.getDriveAccessToken()}",
        "X-Goog-AuthUser": "${FastDB.getDriveUser()}"
      };
      final authenticateClient = GoogleAuthClient(authHeaders);
      return drive.DriveApi(authenticateClient);
    }
    return null;
  }

  Future<void> saveData(GoogleSignInAccount account) async {
    FastDB.putDisplayName(account.displayName ?? "");
    FastDB.putPhotourl(account.photoUrl ?? "");
    FastDB.putEmail(account.email);
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
   await Workmanager().initialize(callbackDispatcher, isInDebugMode:false);
  if(FastDB.getBackupTaskId().isNotEmpty){
   await Workmanager().cancelByUniqueName(FastDB.getBackupTaskId());
  }
  DateTime now = DateTime.now();
  final uniqueID =
      "${DateTime.now().millisecondsSinceEpoch}_dailyBackup_mortgage";
  Workmanager().registerPeriodicTask(
    uniqueID,
    "dailyBackup",
    initialDelay: now.difference(DateTime(
        now.year,
        now.month,
        now.day,
        FastDB.getScheduledBackUpTimeHour(),
        FastDB.getScheduledBackUpTimeMinute())),
    frequency: Duration(hours: 24),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );
  FastDB.putBackupTaskId(uniqueID);
  FastDB.putIsBackUpRegistered(true);
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == "dailyBackup") {
       debugPrint("Task backup started");
     return  await BackupService().performBackup();
    }
    debugPrint("Task backup not found");
    return Future.value(false);
  });
}
