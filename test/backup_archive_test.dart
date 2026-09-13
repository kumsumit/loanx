import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/db/fastdb.dart';
import 'package:loanx/db/flatdb_generated.dart' as db;
import 'package:loanx/service/backup_archive.dart';

void main() {
  final database = List.generate(512, (index) => index % 256);
  final settings = db.FlatDbObjectBuilder(themeMode: 1).toBytes();
  List<int> encode() => BackupArchive.encode(
    database: database,
    settings: settings,
    appVersion: 'test',
    deviceId: 'test-device',
    createdAt: DateTime.utc(2026, 9, 13),
  );
  List<int> zip(Map<String, List<int>> entries) {
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.add(ArchiveFile.bytes(entry.key, entry.value));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  test('versioned archive verifies all data and metadata', () {
    final result = BackupArchive.decode(encode());
    expect(result.database, database);
    expect(result.settings, settings);
    expect(result.formatVersion, 1);
    FastDB.validateBackupSettings(result.settings!);
  });

  test('legacy ZIP and raw database remain readable', () {
    final result = BackupArchive.decode(
      zip({
        BackupArchive.databaseName: database,
        BackupArchive.settingsName: settings,
      }),
    );
    expect(result.formatVersion, 0);
    expect(result.database, database);
    expect(BackupArchive.decode(database, rawDatabase: true).settings, isNull);
  });

  test('missing, unexpected and traversing paths fail closed', () {
    for (final extra in ['../loanx.db', '/loanx.db', 'unexpected.txt']) {
      expect(
        () => BackupArchive.decode(
          zip({
            BackupArchive.databaseName: database,
            BackupArchive.settingsName: settings,
            extra: [1],
          }),
        ),
        throwsFormatException,
      );
    }
    expect(
      () => BackupArchive.decode(zip({BackupArchive.databaseName: database})),
      throwsFormatException,
    );
  });

  test('changed content cannot pass the manifest checksum', () {
    final archive = ZipDecoder().decodeBytes(encode());
    final entries = {for (final file in archive) file.name: file.content};
    entries[BackupArchive.databaseName] = Uint8List.fromList([1, 2, 3]);
    expect(() => BackupArchive.decode(zip(entries)), throwsFormatException);
  });

  test('future versions and malformed manifests are rejected', () {
    final archive = ZipDecoder().decodeBytes(encode());
    final entries = {for (final file in archive) file.name: file.content};
    final manifest =
        jsonDecode(utf8.decode(entries[BackupArchive.manifestName]!)) as Map;
    manifest['format_version'] = 2;
    entries[BackupArchive.manifestName] = Uint8List.fromList(
      utf8.encode(jsonEncode(manifest)),
    );
    expect(() => BackupArchive.decode(zip(entries)), throwsFormatException);
    entries[BackupArchive.manifestName] = Uint8List.fromList([123]);
    expect(() => BackupArchive.decode(zip(entries)), throwsFormatException);
  });

  test('truncation and CRC corruption fail before restore', () {
    final bytes = Uint8List.fromList(encode());
    expect(
      () => BackupArchive.decode(bytes.sublist(0, bytes.length - 1)),
      throwsFormatException,
    );
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length - 4; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50) {
        data.setUint32(i + 16, 0, Endian.little);
        break;
      }
    }
    expect(() => BackupArchive.decode(bytes), throwsFormatException);
  });

  test('declared small sizes cannot bypass actual decompression limits', () {
    final bytes = Uint8List.fromList(
      zip({
        BackupArchive.databaseName: database,
        BackupArchive.settingsName: List.filled(
          BackupArchive.maxSettingsBytes + 1,
          0,
        ),
      }),
    );
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length - 46; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50 &&
          utf8.decode(
                bytes.sublist(
                  i + 46,
                  i + 46 + data.getUint16(i + 28, Endian.little),
                ),
              ) ==
              BackupArchive.settingsName) {
        data.setUint32(i + 24, 10, Endian.little);
        break;
      }
    }
    expect(() => BackupArchive.decode(bytes), throwsFormatException);
  });

  test('bounded network reader rejects oversized stream', () async {
    final chunk = List.filled(1024 * 1024, 0);
    expect(
      BackupArchive.readBounded(Stream.fromIterable(List.filled(129, chunk))),
      throwsFormatException,
    );
    expect(await BackupArchive.readBounded(Stream.value([1, 2])), [1, 2]);
  });

  test(
    'settings validation preserves live state on corrupt and invalid data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'loanx-backup-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      await FastDB.initForTesting(directory);
      FastDB.putDisplayName('Current owner');
      final original = FastDB.exportBackupSettings();
      for (final invalid in [
        [1, 2],
        db.FlatDbObjectBuilder(scheduledBackUpTimeHour: 99).toBytes(),
        db.FlatDbObjectBuilder(interestRate: double.nan).toBytes(),
      ]) {
        expect(
          () => FastDB.validateBackupSettings(invalid),
          throwsFormatException,
        );
        expect(FastDB.exportBackupSettings(), original);
      }
    },
  );
}
