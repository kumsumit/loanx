import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/service/database_helper.dart';

void main() {
  test('ToStore schema exposes canonical identity tables', () async {
    final db = await DatabaseHelper.instance.openMemory(name: 'canonical-test');
    addTearDown(db.close);
    await db.insert('localOwners', {
      'id': 'owner-1',
      'selfPartyId': 'party-1',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    await db.insert('parties', {
      'id': 'party-1',
      'ownerId': 'owner-1',
      'displayName': 'Owner',
      'status': 'ACTIVE',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    expect(
      await db.query('parties', where: 'ownerId = ?', whereArgs: ['owner-1']),
      hasLength(1),
    );
  });
}
