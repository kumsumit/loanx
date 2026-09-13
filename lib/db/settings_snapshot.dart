import 'dart:convert';
import 'dart:typed_data';

/// Versioned, portable settings payload used by backups.
final class SettingsSnapshot {
  static const currentVersion = 1;
  final Map<String, dynamic> values;

  const SettingsSnapshot(this.values);

  List<int> encode() => Uint8List.fromList(utf8.encode(jsonEncode({
        'formatVersion': currentVersion,
        'values': values,
      })));

  static SettingsSnapshot decode(List<int> bytes) {
    if (bytes.length > 4 * 1024 * 1024 || bytes.isEmpty) {
      throw const FormatException('Invalid settings snapshot size.');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map || decoded['formatVersion'] != currentVersion || decoded['values'] is! Map) {
      throw const FormatException('Unsupported settings snapshot.');
    }
    return SettingsSnapshot(Map<String, dynamic>.from(decoded['values'] as Map));
  }
}
