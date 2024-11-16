import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:mortgage/db/fastdb.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

// void main() {
//   runApp(MyApp());
//   Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
// }

// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     if (task == "dailyBackup") {
//       await BackupService().performBackup();
//     }
//     return Future.value(true);
//   });
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Backup App',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: BackupScreen(),
//     );
//   }
// }

// class BackupScreen extends StatelessWidget {
//   final BackupService _backupService = BackupService();

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Backup to Google Drive'),
//       ),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: () async {
//             await _backupService.performBackup();
//           },
//           child: Text('Backup Now'),
//         ),
//       ),
//     );
//   }
// }

class BackupService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  Future<bool> createAppFolder(drive.DriveApi driveApi) async {
    var folder = drive.File();
    folder.name = "Mortgage";
    folder.parents = ['appDataFolder'];
    folder.mimeType = 'application/vnd.google-apps.folder';
    var folderCreation = await driveApi.files.create(folder);
    debugPrint('Created folder ID: ${folderCreation.id}');
    if (folderCreation.id != null) {
      FastDB.putDriveFolderId(folderCreation.id!);
      await FastDB.flush();
      return true;
    }
    return false;
  }

  Future<bool> performBackup() async {
    try{
    debugPrint('performBackup');
    debugPrint('driveAccessToken: ${FastDB.getDriveAccessToken()}');
    debugPrint('driveIdToken: ${FastDB.getDriveIdToken()}');
    debugPrint('driveUser: ${FastDB.getDriveUser()}');
    debugPrint('driveFolderId: ${FastDB.getDriveFolderId()}');
    debugPrint('driveFileId: ${FastDB.getDriveFileId()}');
    if (FastDB.getDriveAccessToken().isEmpty) {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;
      final GoogleSignInAuthentication googleSignInAuthentication =
          await account.authentication;
      FastDB.putDriveAccessToken(googleSignInAuthentication.accessToken ?? "");
      FastDB.putDriveIdToken(googleSignInAuthentication.idToken ?? "");
      final headers = await account.authHeaders;
      if (headers["X-Goog-AuthUser"] != null) {
        FastDB.putDriveUser(
            int.tryParse(headers["X-Goog-AuthUser"] ?? "") ?? 0);
      }
      await FastDB.flush();
    }
    // final account = await _googleSignIn.signIn();

    final authHeaders = {
      "Authorization": "Bearer ${FastDB.getDriveAccessToken()}",
      "X-Goog-AuthUser": "${FastDB.getDriveUser()}"
    };
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);
    if (FastDB.getDriveFolderId().isEmpty) {
      // final files = (await driveApi.files.list(spaces: 'appDataFolder')).files;
      // if (files == null || files.isEmpty) {
      if (await createAppFolder(driveApi)) {
        return await createFile(driveApi);
      }
      // }
      // for (var file in files) {
      //   if (file.name != 'Mortgage') {
      //     await driveApi.files.delete(file.id!);
      //   }
      // }
      // var response = await driveApi.files.list(
      //   spaces: 'appDataFolder',
      //   q: "name = 'Mortgage' and mimeType = 'application/vnd.google-apps.folder'",
      // );
      // if (response.files != null && response.files!.isNotEmpty) {
      // FastDB.putDriveFolderId(response.files!.first.id!);
      // debugPrint('Drive folder ID: ${FastDB.getDriveFolderId()}');
      // await FastDB.flush();
      // return await createFile(driveApi);
    } else {
      // if( await createAppFolder(driveApi)){
      return await createFile(driveApi);
      // }
    }
    return false;
    }catch(e){
      FastDB.putDriveAccessToken("");
      return await performBackup();
    }
  }

  Future<bool> createFile(drive.DriveApi driveApi) async {
    final driveFile = drive.File();
    driveFile.name = "backup-${DateTime.now().toIso8601String()}.db";
    driveFile.parents = [FastDB.getDriveFolderId()];
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
