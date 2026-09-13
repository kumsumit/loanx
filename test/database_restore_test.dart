import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/service/database_helper.dart';

void main() {
  test('database backup is available through the storage port', () async {
    final db = await DatabaseHelper.instance.openMemory(name: 'backup-test');
    addTearDown(db.close);
    await db.insert('familyRelations', {'name': 'Father', 'isAddedByUser': 0});
    await db.flush();
    expect(await db.query('familyRelations'), hasLength(1));
  });
}
