import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// Portable archive integrity, independent of Drive and live application state.
/// Checksums detect corruption, not authenticity. This format is not encrypted.
class BackupArchive {
  static const databaseName = 'loanx.db';
  static const settingsName = 'fastdb-settings.flatbuffer';
  static const manifestName = 'manifest.json';
  static const maxArchiveBytes = 128 * 1024 * 1024;
  static const maxDatabaseBytes = 120 * 1024 * 1024;
  static const maxSettingsBytes = 4 * 1024 * 1024;
  static const maxManifestBytes = 16 * 1024;
  static const _limits = {
    databaseName: maxDatabaseBytes,
    settingsName: maxSettingsBytes,
    manifestName: maxManifestBytes,
  };

  static List<int> encode({
    required List<int> database,
    required List<int> settings,
    required String appVersion,
    required String deviceId,
    required DateTime createdAt,
  }) {
    _validateSize(database, maxDatabaseBytes);
    _validateSize(settings, maxSettingsBytes);
    if (appVersion.isEmpty || deviceId.isEmpty) {
      throw const FormatException('Backup provenance is required.');
    }
    final entries = {databaseName: database, settingsName: settings};
    final manifest = jsonEncode({
      'format_version': 1,
      'app_version': appVersion,
      'device_id': deviceId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'attachments': 'none_supported',
      'files': {
        for (final entry in entries.entries)
          entry.key: {
            'size': entry.value.length,
            'sha256': sha256.convert(entry.value).toString(),
          },
      },
    });
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.add(ArchiveFile.bytes(entry.key, entry.value));
    }
    archive.add(ArchiveFile.string(manifestName, manifest));
    final result = ZipEncoder().encodeBytes(archive);
    _validateSize(result, maxArchiveBytes);
    return result;
  }

  /// Reads only the explicit file allowlist. ZIP64, split, encrypted and
  /// unsupported compression archives fail closed. Inflation is bounded by
  /// actual output bytes, even if an attacker lies about the declared size.
  static ValidatedBackup decode(List<int> bytes, {bool rawDatabase = false}) {
    _validateSize(bytes, maxArchiveBytes);
    if (rawDatabase) {
      _validateSize(bytes, maxDatabaseBytes);
      return ValidatedBackup(bytes, null, 0);
    }
    final input = Uint8List.fromList(bytes);
    final data = ByteData.sublistView(input);
    int u16(int offset) => data.getUint16(offset, Endian.little);
    int u32(int offset) => data.getUint32(offset, Endian.little);
    try {
      var end = input.length - 22;
      final minimum = (input.length - 65557).clamp(0, input.length);
      while (end >= minimum && u32(end) != 0x06054b50) {
        end--;
      }
      if (end < minimum ||
          end + 22 + u16(end + 20) != input.length ||
          u16(end + 4) != 0 ||
          u16(end + 6) != 0) {
        throw const FormatException('Invalid or split backup archive.');
      }
      final count = u16(end + 10);
      var cursor = u32(end + 16);
      final directoryEnd = cursor + u32(end + 12);
      if (count < 2 ||
          count > 3 ||
          count != u16(end + 8) ||
          directoryEnd != end) {
        throw const FormatException('Invalid backup archive directory.');
      }
      final files = <String, List<int>>{};
      final ranges = <(int, int)>[];
      for (var i = 0; i < count; i++) {
        if (cursor + 46 > directoryEnd || u32(cursor) != 0x02014b50) {
          throw const FormatException('Invalid backup file header.');
        }
        final flags = u16(cursor + 8);
        final method = u16(cursor + 10);
        final crc = u32(cursor + 16);
        final compressed = u32(cursor + 20);
        final size = u32(cursor + 24);
        final nameLength = u16(cursor + 28);
        final next =
            cursor + 46 + nameLength + u16(cursor + 30) + u16(cursor + 32);
        if (next > directoryEnd || u16(cursor + 34) != 0) {
          throw const FormatException('Invalid backup file directory.');
        }
        final nameBytes = input.sublist(cursor + 46, cursor + 46 + nameLength);
        final name = utf8.decode(nameBytes);
        final limit = _limits[name];
        final mode = u32(cursor + 38) >> 16;
        if (limit == null ||
            files.containsKey(name) ||
            size <= 0 ||
            size > limit ||
            flags & 1 != 0 ||
            (method != 0 && method != 8) ||
            (mode & 0xf000 != 0 && mode & 0xf000 != 0x8000)) {
          throw const FormatException(
            'Unsupported, duplicate or oversized backup file.',
          );
        }
        final local = u32(cursor + 42);
        if (local + 30 > u32(end + 16) ||
            u32(local) != 0x04034b50 ||
            u16(local + 6) != flags ||
            u16(local + 8) != method ||
            u16(local + 26) != nameLength) {
          throw const FormatException('Inconsistent backup file header.');
        }
        final localName = input.sublist(local + 30, local + 30 + nameLength);
        if (utf8.decode(localName) != name) {
          throw const FormatException('Inconsistent backup file name.');
        }
        final start = local + 30 + nameLength + u16(local + 28);
        final finish = start + compressed;
        if (finish > u32(end + 16) ||
            ranges.any((r) => local < r.$2 && finish > r.$1)) {
          throw const FormatException('Invalid backup file bounds.');
        }
        ranges.add((local, finish));
        final content = _inflate(input.sublist(start, finish), method, limit);
        if (content.length != size || getCrc32(content) != crc) {
          throw const FormatException('Backup file integrity check failed.');
        }
        files[name] = content;
        cursor = next;
      }
      if (cursor != directoryEnd ||
          !files.containsKey(databaseName) ||
          !files.containsKey(settingsName)) {
        throw const FormatException('Backup is missing required files.');
      }
      var version = 0;
      if (files.containsKey(manifestName)) {
        final manifest = jsonDecode(utf8.decode(files[manifestName]!));
        if (manifest is! Map ||
            manifest['format_version'] != 1 ||
            manifest['app_version'] is! String ||
            (manifest['app_version'] as String).isEmpty ||
            manifest['device_id'] is! String ||
            (manifest['device_id'] as String).isEmpty ||
            manifest['created_at'] is! String ||
            !((DateTime.tryParse(manifest['created_at'])?.isUtc) ?? false) ||
            manifest['attachments'] != 'none_supported' ||
            manifest['files'] is! Map) {
          throw const FormatException(
            'Unsupported or invalid backup manifest.',
          );
        }
        final declared = manifest['files'] as Map;
        if (declared.length != 2) {
          throw const FormatException('Invalid backup manifest entries.');
        }
        for (final name in [databaseName, settingsName]) {
          final entry = declared[name];
          if (entry is! Map ||
              entry['size'] != files[name]!.length ||
              entry['sha256'] != sha256.convert(files[name]!).toString()) {
            throw const FormatException('Backup checksum mismatch.');
          }
        }
        version = 1;
      }
      return ValidatedBackup(
        files[databaseName]!,
        files[settingsName],
        version,
      );
    } on RangeError {
      throw const FormatException('Truncated backup archive.');
    }
  }

  static List<int> _inflate(List<int> input, int method, int limit) {
    if (method == 0) {
      _validateSize(input, limit);
      return input;
    }
    final output = _BoundedSink(limit);
    final decoder = io.ZLibDecoder(raw: true).startChunkedConversion(output);
    for (var i = 0; i < input.length; i += 1024) {
      decoder.add(input.sublist(i, (i + 1024).clamp(0, input.length)));
    }
    decoder.close();
    return output.bytes.takeBytes();
  }

  static Future<List<int>> readBounded(Stream<List<int>> stream) async {
    final sink = _BoundedSink(maxArchiveBytes);
    await for (final chunk in stream) {
      sink.add(chunk);
    }
    return sink.bytes.takeBytes();
  }

  static void _validateSize(List<int> bytes, int maximum) {
    if (bytes.isEmpty || bytes.length > maximum) {
      throw const FormatException(
        'Backup file is empty or exceeds the size limit.',
      );
    }
  }
}

class ValidatedBackup {
  const ValidatedBackup(this.database, this.settings, this.formatVersion);
  final List<int> database;
  final List<int>? settings;
  final int formatVersion;
}

class _BoundedSink implements Sink<List<int>> {
  _BoundedSink(this.limit);
  final int limit;
  final bytes = BytesBuilder(copy: false);
  @override
  void add(List<int> data) {
    if (bytes.length + data.length > limit) {
      throw const FormatException(
        'Backup exceeds the decompressed size limit.',
      );
    }
    bytes.add(data);
  }

  @override
  void close() {}
}
