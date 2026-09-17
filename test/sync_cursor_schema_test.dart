import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/service/database_helper.dart';

void main() {
  test('sync cursor persists with its stable owner primary key', () async {
    final db = await DatabaseHelper.instance.openMemory(
      name: 'sync-cursor-${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(db.close);

    const ownerId = 'owner-1';
    await db.insert('syncCursors', {
      'id': ownerId,
      'ownerId': ownerId,
      'workspaceId': 'workspace-1',
      'lastSequence': 42,
      'updatedAt': DateTime.utc(2026, 9, 17).toIso8601String(),
    });

    final rows = await db.query(
      'syncCursors',
      where: 'ownerId = ? AND workspaceId = ?',
      whereArgs: const [ownerId, 'workspace-1'],
    );
    expect(rows, hasLength(1));
    expect(rows.single['id'], ownerId);
    expect(rows.single['lastSequence'], 42);
  });
}
