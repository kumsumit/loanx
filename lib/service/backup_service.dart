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

  Future<void> downloadFileToDevice() async {
    final driveApi = await getDriveApi();
    File saveFile = File(join(await getDatabasesPath(), 'mortgage.db'));
    if (driveApi != null) {
      final fileList =
          (await driveApi.files.list(spaces: 'appDataFolder')).files;
      if (fileList != null &&
          fileList.isNotEmpty &&
          fileList.first.id != null) {
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
              final first = await file.stream.first;
              await saveFile.writeAsBytes(first, flush: true);
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

  Future<drive.DriveApi?> getDriveApi() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: [drive.DriveApi.driveAppdataScope],
    );
    GoogleSignInAccount? account;
    if (FastDB.getDriveAccessToken().isEmpty) {
      account = await googleSignIn.signIn();
      if (account == null) return null;
    } else if (DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(
        FastDB.getDriveAccessTokenExpires()))) {
      account = await googleSignIn.signInSilently();
      if (account == null) return null;
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

Future<void> registerBackUp() async{
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  Workmanager().registerPeriodicTask(
    "MortgageBackupTaskgfcgfdfgdfgcscdfs65",
    "dailyBackup",
    initialDelay: Duration(
        hours: FastDB.getScheduledBackUpTimeHour(),
        minutes: FastDB.getScheduledBackUpTimeMinute()),
    frequency: Duration(days: 1),
  );
  FastDB.putIsBackUpRegistered(true);
  await FastDB.flush();
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == "dailyBackup") {
      await BackupService().performBackup();
    }
    return Future.value(true);
  });
}
